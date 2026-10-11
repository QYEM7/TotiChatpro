-- TotiChat Staging: owner / designated main-partner READ-ONLY finance integrity preflight.
-- No invented commission/host salary rates; no settlement, payment, or diamond reset.
-- Only anonymous aggregated counts are returned; no wallet users or ledger rows leave the DB.
create function phase3.finance_integrity_preflight(
  p_from timestamptz default (now()-interval '7 days'),
  p_to timestamptz default now()
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 caller uuid:=phase3.actor();
 gift_total bigint:=0; gift_broken bigint:=0;
 redemption_total bigint:=0; redemption_broken bigint:=0;
 wallet_total bigint:=0; wallet_untracked bigint:=0;
begin
 if not exists(
   select 1 from phase3.system_authority a where a.singleton
    and (a.owner_id=caller or a.main_partner_id=caller)
 ) then
   raise exception 'Only Owner or designated main partner can review finance integrity'
    using errcode='42501';
 end if;
 if p_from is null or p_to is null or p_to<=p_from
    or p_to>now()+interval '1 minute' or p_to-p_from>interval '31 days'
    or p_from<timestamp with time zone '2025-01-01 00:00:00+00' then
   raise exception 'Valid bounded UTC audit interval required';
 end if;

 -- Every verified gift is an atomic debit (coins) and credit (diamonds).
 -- Also detect gift-event/financial-operation and diamond-lot inconsistencies.
 select count(*),count(*) filter(where
   op.id is null or op.operation<>'gift' or op.status<>'completed'
   or coalesce(lines.leg_count,0)<>2
   or coalesce(lines.sender_coins,0)<>-g.amount
   or coalesce(lines.recipient_diamonds,0)<>g.amount
   or lot.id is null or lot.user_id<>g.recipient_id
   or lot.amount<>g.amount or lot.source_type<>g.diamond_source_type
 ) into gift_total,gift_broken
 from public.gift_events g
 left join public.financial_operations op on op.id=g.id
 left join public.diamond_lots lot on lot.gift_event_id=g.id
 left join lateral(
  select count(*) as leg_count,
   coalesce(sum(l.amount_change) filter(where l.user_id=g.sender_id
                                           and l.currency='coins'),0) sender_coins,
   coalesce(sum(l.amount_change) filter(where l.user_id=g.recipient_id
                                           and l.currency='diamonds'),0) recipient_diamonds
  from public.wallet_ledger l where l.transaction_id=g.id
 ) lines on true
 where g.created_at>=p_from and g.created_at<p_to;

 -- Redemption must have exactly two ledger legs, balanced diamonds/coins
 -- and an allocation total equal to the approved redemption amount.
 select count(*),count(*) filter(where
   op.id is null or op.operation<>'diamond_redemption'
   or op.status<>'completed'
   or coalesce(lines.leg_count,0)<>2
   or coalesce(lines.diamond_delta,0)<>-r.diamonds_amount
   or coalesce(lines.coin_delta,0)<>r.coins_amount
   or coalesce(lots.allocated,0)<>r.diamonds_amount
 ) into redemption_total,redemption_broken
 from public.diamond_redemptions r
 left join public.financial_operations op on op.id=r.id
 left join lateral(
  select count(*) leg_count,
   coalesce(sum(l.amount_change) filter(where l.user_id=r.user_id
                                          and l.currency='diamonds'),0) diamond_delta,
   coalesce(sum(l.amount_change) filter(where l.user_id=r.user_id
                                          and l.currency='coins'),0) coin_delta
  from public.wallet_ledger l where l.transaction_id=r.id
 ) lines on true
 left join lateral(
  select coalesce(sum(a.amount),0) allocated
  from public.diamond_redemption_allocations a where a.redemption_id=r.id
 ) lots on true
 where r.created_at>=p_from and r.created_at<p_to;

 -- A difference requires investigation: never silently assume it is fraud,
 -- invent origin entries, or overwrite a wallet. Newly created wallets start at 0.
 select count(*),count(*) filter(where w.diamonds<>coalesce(x.remaining,0))
 into wallet_total,wallet_untracked
 from public.wallets w
 left join lateral(
   select coalesce(sum(l.remaining),0) remaining
   from public.diamond_lots l where l.user_id=w.user_id
 ) x on true;

 return jsonb_build_object(
  'from',p_from,'to',p_to,'asOf',now(),
  'giftEventsChecked',gift_total,'giftIntegrityIssues',gift_broken,
  'redemptionsChecked',redemption_total,'redemptionIntegrityIssues',redemption_broken,
  'walletsChecked',wallet_total,'walletsNeedingDiamondReconciliation',wallet_untracked,
  'hasDetectedLedgerIssues',gift_broken>0 or redemption_broken>0,
  'requiresManualWalletReview',wallet_untracked>0,
  'isReadOnly',true,'canZeroDiamonds',false,'paysSalaries',false,
  'hasPayrollRates',false,
  'scope','Verified gift/redemption ledger legs, diamond lots, and wallet diamond coverage; not a full financial audit or month-end settlement'
 );
end $fn$;
revoke all on function phase3.finance_integrity_preflight(timestamptz,timestamptz)
 from public,anon,authenticated;
grant execute on function phase3.finance_integrity_preflight(timestamptz,timestamptz)
 to authenticated;

create function public.phase5_finance_integrity_preflight(
  p_from timestamptz default (now()-interval '7 days'),
  p_to timestamptz default now()
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.finance_integrity_preflight(p_from,p_to);
end $fn$;
revoke all on function public.phase5_finance_integrity_preflight(timestamptz,timestamptz)
 from public,anon;
grant execute on function public.phase5_finance_integrity_preflight(timestamptz,timestamptz)
 to authenticated;
comment on function public.phase5_finance_integrity_preflight(timestamptz,timestamptz) is
 'Owner/main-partner only, aggregated read-only finance integrity diagnostics. No wallet mutations, rates, host payroll or monthly close.';
