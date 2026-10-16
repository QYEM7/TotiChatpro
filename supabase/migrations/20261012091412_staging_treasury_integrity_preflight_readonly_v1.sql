-- TotiChat Staging: Owner/main-partner-only, READ-ONLY treasury reconciliation.
-- Money movement, payouts, agency cash settlement, salary and monthly diamond reset
-- are intentionally NOT implemented or enabled by this migration.
create function phase3.treasury_integrity_preflight()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  caller uuid:=phase3.actor();
  issued numeric; issuance_net numeric; issue_ledger_orphans bigint;
  treasury_checked bigint; treasury_wrong bigint; treasury_orphans bigint;
  wallet_checked bigint; wallet_wrong bigint;
  minted_checked bigint; minted_wrong bigint;
  transfers_checked bigint; transfers_wrong bigint;
  topups_checked bigint; topups_wrong bigint;
begin
 if not exists(select 1 from phase3.system_authority a where a.singleton
   and (a.owner_id=caller or a.main_partner_id=caller)) then
   raise exception 'Only Owner or designated main partner can inspect treasury integrity'
   using errcode='42501';
 end if;
 select i.issued::numeric into issued from phase3.coin_issuance i where i.singleton;
 if issued is null then raise exception 'Coin issuance control is missing' using errcode='23514';end if;
 select coalesce(sum(l.amount),0)::numeric into issuance_net from phase3.issuance_ledger l;
 select count(*) into issue_ledger_orphans from phase3.issuance_ledger l
 left join public.financial_operations op on op.id=l.operation_id
 where op.id is null or op.operation<>'recharge_action' or op.payload->>'action'<>'issue'
   or op.status<>'completed';
 select count(*),
   count(*) filter(where a.coins::numeric is distinct from coalesce(x.delta,0))
 into treasury_checked,treasury_wrong
 from phase3.treasury_accounts a
 left join lateral(
  select coalesce(sum(l.amount),0)::numeric delta
  from phase3.treasury_ledger l where l.user_id=a.user_id
 ) x on true;
 select count(*) into treasury_orphans
 from phase3.treasury_ledger l
 left join phase3.treasury_accounts a on a.user_id=l.user_id
 where a.user_id is null;
 select count(*),
   count(*) filter(where w.coins::numeric is distinct from coalesce(x.delta,0))
 into wallet_checked,wallet_wrong
 from public.wallets w
 left join lateral(
  select coalesce(sum(l.amount_change),0)::numeric delta from public.wallet_ledger l
  where l.user_id=w.user_id and l.currency='coins'
 ) x on true;
 -- Every newly issued coin needs exactly two balanced independent records:
 -- Owner treasury credit and issuance accounting debit, both tied to the
 -- SAME immutable financial_operation.
 select count(*),count(*) filter(where
   expected.amount is null or coalesce(t.legs,0)<>1
   or t.delta is distinct from expected.amount
   or coalesce(l.legs,0)<>1 or l.delta is distinct from -expected.amount
 ) into minted_checked,minted_wrong
 from public.financial_operations op
 left join lateral(
  select case when (op.result->>'coins') ~ '^[0-9]{1,19}$'
   then (op.result->>'coins')::numeric else null end amount
 ) expected on true
 left join lateral(
  select count(*) legs,coalesce(sum(l.amount),0)::numeric delta
  from phase3.treasury_ledger l where l.operation_id=op.id and l.user_id=op.actor_id
 ) t on true
 left join lateral(
  select count(*) legs,coalesce(sum(l.amount),0)::numeric delta
  from phase3.issuance_ledger l where l.operation_id=op.id
 ) l on true
 where op.operation='recharge_action' and op.status='completed'
 and op.payload->>'action'='issue';
 -- Moving coins to an agent MUST debit exactly once, credit exactly once,
 -- total to zero, and agree with the verified recharge-agency owner.
 select count(*),count(*) filter(where
  expected.amount is null or a.id is null
  or coalesce(t.legs,0)<>2 or t.delta is distinct from 0::numeric
  or t.debit is distinct from -expected.amount
  or t.credit is distinct from expected.amount
 ) into transfers_checked,transfers_wrong
 from public.financial_operations op
 left join lateral(
  select case when (op.result->>'coins') ~ '^[0-9]{1,19}$'
   then (op.result->>'coins')::numeric else null end amount
 ) expected on true
 left join public.agencies a on a.id::text=(op.payload->'data'->>'agency_id')
  and a.kind='recharge'
 left join lateral(
  select count(*) legs,coalesce(sum(l.amount),0)::numeric delta,
   coalesce(sum(l.amount) filter(where l.user_id=op.actor_id),0)::numeric debit,
   coalesce(sum(l.amount) filter(where l.user_id=a.owner_id),0)::numeric credit
  from phase3.treasury_ledger l where l.operation_id=op.id
 ) t on true
 where op.operation='recharge_action' and op.status='completed'
 and op.payload->>'action'='allocate';
 -- Approved customer recharge has one matched agent debit and wallet credit,
 -- including actual recorded reward coins, plus a completed request.
 select count(*),count(*) filter(where
  req.id is null or req.status<>'completed' or expected.amount is null
  or expected.base_coins is distinct from req.coins::numeric
  or coalesce(t.legs,0)<>1 or t.delta is distinct from -expected.amount
  or coalesce(w.legs,0)<>1 or w.delta is distinct from expected.amount
 ) into topups_checked,topups_wrong
 from public.financial_operations op
 left join public.recharge_requests req on req.id::text=(op.result->>'request_id')
 left join lateral(
  select
   case when (op.result->>'coins') ~ '^[0-9]{1,19}$'
    then (op.result->>'coins')::numeric else null end base_coins,
   case when (op.result->>'coins') ~ '^[0-9]{1,19}$'
     and (op.result->>'bonus_coins') ~ '^[0-9]{1,19}$'
    then (op.result->>'coins')::numeric+(op.result->>'bonus_coins')::numeric
    else null end amount
 ) expected on true
 left join lateral(
  select count(*) legs,coalesce(sum(l.amount),0)::numeric delta
  from phase3.treasury_ledger l
  where l.operation_id=op.id and l.user_id=op.actor_id
 ) t on true
 left join lateral(
  select count(*) legs,coalesce(sum(l.amount_change),0)::numeric delta
  from public.wallet_ledger l where l.transaction_id=op.id
    and l.user_id=req.user_id and l.currency='coins'
 ) w on true
 where op.operation='recharge_action' and op.status='completed'
 and op.payload->>'action'='approve';
 return jsonb_build_object(
  'asOf',now(),'isReadOnly',true,'scope','Treasury issuance, user ledger and agent topups; not a complete economy close',
  'issuedCoins',issued::text,'issuanceLedgerNet',issuance_net::text,
  'issuanceControlMismatch',issued+issuance_net<>0,
  'issuanceOrphanRows',issue_ledger_orphans,
  'treasuryAccountsChecked',treasury_checked,'treasuryBalanceMismatches',treasury_wrong,
  'treasuryOrphanLedgerRows',treasury_orphans,
  'userWalletsChecked',wallet_checked,'userCoinBalanceMismatches',wallet_wrong,
  'issuedOperationsChecked',minted_checked,'issuanceOperationMismatches',minted_wrong,
  'agentAllocationsChecked',transfers_checked,'agencyAllocationMismatches',transfers_wrong,
  'agentTopupsChecked',topups_checked,'customerTopupMismatches',topups_wrong,
  'hasDetectedLedgerIssues',(issued+issuance_net<>0 or issue_ledger_orphans>0
   or treasury_wrong>0 or treasury_orphans>0 or wallet_wrong>0
   or minted_wrong>0 or transfers_wrong>0 or topups_wrong>0),
  'isReadyForMoneyMovement',false,
  'paysSalaries',false,'canZeroDiamonds',false,'canIssueCoins',false,
  'hasPayrollRates',false
 );
end $fn$;
revoke all on function phase3.treasury_integrity_preflight() from public,anon,authenticated;
grant execute on function phase3.treasury_integrity_preflight() to authenticated;
create function public.phase6_treasury_integrity_preflight()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.treasury_integrity_preflight();
end $fn$;
revoke all on function public.phase6_treasury_integrity_preflight() from public,anon,authenticated;
grant execute on function public.phase6_treasury_integrity_preflight() to authenticated;
