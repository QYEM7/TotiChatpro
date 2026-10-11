-- TotiChat staging: private OWNER + designated main partner audit drill-down.
-- Diagnoses existing mismatches only; cannot correct, pay, settle, clear or modify balances.
create function phase3.finance_integrity_issues(
 p_kind text,p_from timestamptz default(now()-interval '7 days'),
 p_to timestamptz default now(),p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();items jsonb:='[]'::jsonb;
begin
 if not exists(select 1 from phase3.system_authority a
   where a.singleton and (a.owner_id=caller or a.main_partner_id=caller)) then
  raise exception 'Owner or designated main partner required' using errcode='42501';
 end if;
 if p_kind is null or p_kind not in('gift','redemption','wallet')
  or p_from is null or p_to is null or p_to<=p_from
  or p_to>now()+interval '1 minute'
  or p_to-p_from>interval '31 days'
  or p_from<timestamp with time zone '2025-01-01 00:00:00+00'
  or p_limit is null or p_limit not between 1 and 25
  or p_offset is null or p_offset not between 0 and 50000 then
  raise exception 'Invalid bounded audit request';
 end if;
 if p_kind='gift' then
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
   select g.id as operation_id,g.sender_id,g.recipient_id,g.amount::text expected_amount,
    coalesce(lines.sender_coins,0)::text sender_coins_delta,
    coalesce(lines.recipient_diamonds,0)::text recipient_diamonds_delta,
    lot.amount::text lot_amount,
    op.status operation_status
   from public.gift_events g
   left join public.financial_operations op on op.id=g.id
   left join public.diamond_lots lot on lot.gift_event_id=g.id
   left join lateral(
    select count(*) leg_count,
     coalesce(sum(l.amount_change) filter(where l.user_id=g.sender_id
                                       and l.currency='coins'),0) sender_coins,
     coalesce(sum(l.amount_change) filter(where l.user_id=g.recipient_id
                                       and l.currency='diamonds'),0) recipient_diamonds
    from public.wallet_ledger l where l.transaction_id=g.id
   ) lines on true
   where g.created_at>=p_from and g.created_at<p_to
    and (op.id is null or op.operation<>'gift' or op.status<>'completed'
     or coalesce(lines.leg_count,0)<>2
     or coalesce(lines.sender_coins,0)<>-g.amount
     or coalesce(lines.recipient_diamonds,0)<>g.amount
     or lot.id is null or lot.user_id<>g.recipient_id
     or lot.amount<>g.amount or lot.source_type<>g.diamond_source_type)
   order by g.created_at desc,g.id desc offset p_offset limit p_limit
  ) v;
 elsif p_kind='redemption' then
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
   select r.id operation_id,r.user_id,r.diamonds_amount::text expected_diamonds,
    r.coins_amount::text expected_coins,
    coalesce(lines.diamond_delta,0)::text ledger_diamond_delta,
    coalesce(lines.coin_delta,0)::text ledger_coin_delta,
    coalesce(lots.allocated,0)::text allocated_diamonds,op.status operation_status
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
   where r.created_at>=p_from and r.created_at<p_to
    and (op.id is null or op.operation<>'diamond_redemption' or op.status<>'completed'
     or coalesce(lines.leg_count,0)<>2
     or coalesce(lines.diamond_delta,0)<>-r.diamonds_amount
     or coalesce(lines.coin_delta,0)<>r.coins_amount
     or coalesce(lots.allocated,0)<>r.diamonds_amount)
   order by r.created_at desc,r.id desc offset p_offset limit p_limit
  ) v;
 else
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
   select w.user_id,w.diamonds::text wallet_diamonds,
    coalesce(lot.remaining,0)::text tracked_diamonds
   from public.wallets w
   left join lateral(
    select coalesce(sum(l.remaining),0) remaining
    from public.diamond_lots l where l.user_id=w.user_id
   ) lot on true
   where w.diamonds<>coalesce(lot.remaining,0)
   order by w.user_id offset p_offset limit p_limit
  ) v;
 end if;
 return jsonb_build_object('kind',p_kind,'items',items,
  'offset',p_offset,'limit',p_limit,
  'isReadOnly',true,'hasPayrollRates',false,'canZeroDiamonds',false,
  'requiresManualInvestigation',true);
end $fn$;
revoke all on function phase3.finance_integrity_issues(text,timestamptz,timestamptz,integer,integer)
 from public,anon;
grant execute on function phase3.finance_integrity_issues(text,timestamptz,timestamptz,integer,integer)
 to authenticated;
create function public.phase5_finance_integrity_issues(
 p_kind text,p_from timestamptz default(now()-interval '7 days'),
 p_to timestamptz default now(),p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.finance_integrity_issues(p_kind,p_from,p_to,p_offset,p_limit);
end $fn$;
revoke all on function public.phase5_finance_integrity_issues(text,timestamptz,timestamptz,integer,integer)
 from public,anon;
grant execute on function public.phase5_finance_integrity_issues(text,timestamptz,timestamptz,integer,integer)
 to authenticated;
