-- Runtime PL/pgSQL SQL name disambiguation; no changed data, no payout.
-- Host diamond month conservation, Staging only.
-- Never use current remaining diamonds to REDUCE earned-month payroll liability.
-- Current remaining is a movement check; payroll/commission/zeroing are disabled.
create or replace function phase3.host_month_diamond_conservation(
 p_month date,p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 caller uuid:=phase3.actor();
 t0 timestamptz; t1 timestamptz;
 lot_count bigint:=0;gift_count bigint:=0;group_count bigint:=0;
 total_earned numeric:=0;total_redeemed numeric:=0;total_left numeric:=0;
 lot_discrepancies bigint:=0;wrong_redemption_owner bigint:=0;
 wallet_discrepancies bigint:=0;redemption_discrepancies bigint:=0;
 paged jsonb:='[]'::jsonb; evidence jsonb;
begin
 if not exists(select 1 from phase3.system_authority a where a.singleton
   and (a.owner_id=caller or a.main_partner_id=caller)) then
  raise exception 'Owner or designated main partner only'
    using errcode='42501';
 end if;
 if p_month is null or extract(day from p_month)<>1
   or p_month<date '2025-01-01'
   or p_month>=date_trunc('month',now() at time zone 'UTC')::date then
  raise exception 'A closed UTC month is required';
 end if;
 if p_offset is null or p_offset<0 or p_offset>100000
   or p_limit is null or p_limit<1 or p_limit>50 then
  raise exception 'Pagination out of bounds';
 end if;
 t0:=p_month::timestamp at time zone 'UTC';
 t1:=(p_month+interval '1 month')::timestamp at time zone 'UTC';

 -- This existing independent evidence audit checks frozen agency-by-host
 -- accrual against historical gifts; it has the same protected role gate.
 evidence:=phase3.host_month_evidence_integrity(p_month);

 with facts as (
  select g.id gift_id,g.agency_id,g.recipient_id,
    g.amount::numeric earned,l.id lot_id,l.amount::numeric lot_amount,
    l.remaining::numeric remaining,
    l.user_id lot_owner,l.source_type lot_type,g.diamond_source_type gift_type,
    coalesce(a.used,0)::numeric used,
    coalesce(a.foreign_owner,0)::bigint foreign_owner
  from public.gift_events g
  join public.agencies ag on ag.id=g.agency_id and ag.kind='host'
  left join public.diamond_lots l on l.gift_event_id=g.id
  left join lateral(
   select coalesce(sum(x.amount),0)::numeric used,
     count(*) filter(where r.user_id is distinct from l.user_id)::bigint foreign_owner
   from public.diamond_redemption_allocations x
   join public.diamond_redemptions r on r.id=x.redemption_id
   where x.lot_id=l.id
  ) a on true
  where g.created_at>=t0 and g.created_at<t1
 )
 select count(*),count(lot_id),
  coalesce(sum(earned),0)::numeric,
  coalesce(sum(used),0)::numeric,coalesce(sum(remaining),0)::numeric,
  count(*) filter(where lot_id is null
   or lot_amount is distinct from earned
   or lot_owner is distinct from recipient_id
   or lot_type is distinct from gift_type
   or remaining is null or used+remaining is distinct from lot_amount),
  coalesce(sum(foreign_owner),0)
 into gift_count,lot_count,total_earned,total_redeemed,total_left,
  lot_discrepancies,wrong_redemption_owner
 from facts;

 -- Ensure a redemption has exactly the declared total and source split even
 -- if this month's lots form only a part of a cross-month redemption.
 select count(*) into redemption_discrepancies from (
  select distinct a.redemption_id
  from public.diamond_redemption_allocations a
  join public.diamond_lots l on l.id=a.lot_id
  join public.gift_events g on g.id=l.gift_event_id
  join public.agencies ag on ag.id=g.agency_id and ag.kind='host'
  where g.created_at>=t0 and g.created_at<t1
 ) month_redemptions
 join public.diamond_redemptions r on r.id=month_redemptions.redemption_id
 left join lateral(
  select coalesce(sum(a.amount),0)::numeric total,
   coalesce(sum(a.amount) filter(where l.source_type='FIXED_GIFT'),0)::numeric fixed,
   coalesce(sum(a.amount) filter(where l.source_type='LUCKY_GIFT'),0)::numeric lucky,
   count(*) filter(where l.user_id is distinct from r.user_id) wrong_owner
  from public.diamond_redemption_allocations a
  join public.diamond_lots l on l.id=a.lot_id
  where a.redemption_id=r.id
 ) checks on true
 where r.diamonds_amount is distinct from checks.total
  or r.fixed_diamonds is distinct from checks.fixed
  or r.lucky_diamonds is distinct from checks.lucky
  or checks.wrong_owner>0;

 -- Wallet balance is GLOBAL for each host; include lots from ALL periods.
 -- An individual host can have previous months and non-host gift income.
 select count(*) into wallet_discrepancies from (
  select distinct g.recipient_id as host_id
  from public.gift_events g
  join public.agencies ag on ag.id=g.agency_id and ag.kind='host'
  where g.created_at>=t0 and g.created_at<t1
 ) hosts
 left join public.wallets w on w.user_id=hosts.host_id
 left join lateral(
  select coalesce(sum(remaining),0)::numeric balance
  from public.diamond_lots l where l.user_id=hosts.host_id
 ) all_lots on true
 where w.user_id is null or w.diamonds::numeric is distinct from all_lots.balance;

 with facts as (
  select g.agency_id,g.recipient_id,g.amount::numeric earned,
   coalesce(l.remaining,0)::numeric remaining,
   coalesce((select sum(a.amount) from public.diamond_redemption_allocations a
      where a.lot_id=l.id),0)::numeric redeemed
  from public.gift_events g
  join public.agencies ag on ag.id=g.agency_id and ag.kind='host'
  left join public.diamond_lots l on l.gift_event_id=g.id
  where g.created_at>=t0 and g.created_at<t1
 ), grouped as (
  select agency_id,recipient_id,count(*)::bigint gift_count,
    sum(earned)::numeric earned,
    sum(redeemed)::numeric redeemed_to_date,
    sum(remaining)::numeric remaining_now
  from facts group by agency_id,recipient_id
 )
 select count(*) into group_count from grouped;

 with facts as (
  select g.agency_id,g.recipient_id,g.amount::numeric earned,
   coalesce(l.remaining,0)::numeric remaining,
   coalesce((select sum(a.amount) from public.diamond_redemption_allocations a
     where a.lot_id=l.id),0)::numeric redeemed
  from public.gift_events g
  join public.agencies ag on ag.id=g.agency_id and ag.kind='host'
  left join public.diamond_lots l on l.gift_event_id=g.id
  where g.created_at>=t0 and g.created_at<t1
 ), grouped as (
  select agency_id,recipient_id,count(*)::bigint gift_count,
    sum(earned)::numeric earned,sum(redeemed)::numeric redeemed_to_date,
    sum(remaining)::numeric remaining_now
  from facts group by agency_id,recipient_id
 ), page as (
  select grouped.agency_id,grouped.recipient_id,grouped.gift_count,grouped.earned,
    grouped.redeemed_to_date,grouped.remaining_now
  from grouped order by grouped.agency_id,grouped.recipient_id offset p_offset limit p_limit
 )
 select coalesce(jsonb_agg(jsonb_build_object(
    'agencyId',page.agency_id,'hostId',page.recipient_id,'giftCount',page.gift_count,
    'earnedDiamonds',page.earned::text,'redeemedDiamondsToDate',page.redeemed_to_date::text,
    'unredeemedDiamondsNow',page.remaining_now::text)),'[]'::jsonb)
 into paged from page;

 return jsonb_build_object(
  'month',p_month,'asOf',now(),'isReadOnly',true,
  'scope','Recorded historical host gifts; current lot balances are NOT earnings as of historical month end',
  'giftCount',gift_count,'lotCount',lot_count,'groupCount',group_count,
  'earnedDiamonds',total_earned::text,
  'redeemedDiamondsToDate',total_redeemed::text,
  'unredeemedDiamondsNow',total_left::text,
  'hostLotDiscrepancies',lot_discrepancies,
  'foreignOwnerRedemptionAllocations',wrong_redemption_owner,
  'redemptionConservationDiscrepancies',redemption_discrepancies,
  'hostWalletBalanceDiscrepancies',wallet_discrepancies,
  'hasDiscrepancies',(lot_discrepancies>0 or wrong_redemption_owner>0
    or redemption_discrepancies>0 or wallet_discrepancies>0
    or (evidence->>'hasEvidenceProblems')::boolean),
  'snapshotConsistent',evidence->'snapshotConsistent',
  'snapshotCaptured',evidence->'snapshotCaptured',
  'unassignedGiftEventsForReview',evidence->'unassignedGiftEventsForReview',
  'pageOffset',p_offset,'pageLimit',p_limit,'hosts',paged,
  'canApprovePayroll',false,'hasPayrollRates',false,
  'canPaySalaries',false,'canZeroDiamonds',false,
  'isReadyForFinalClose',false);
end $fn$;
revoke all on function phase3.host_month_diamond_conservation(date,integer,integer)
 from public,anon,authenticated;
grant execute on function phase3.host_month_diamond_conservation(date,integer,integer)
 to authenticated;
create or replace function public.phase7_host_month_diamond_conservation(
 p_month date,p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.host_month_diamond_conservation(p_month,p_offset,p_limit);
end $fn$;
revoke all on function public.phase7_host_month_diamond_conservation(date,integer,integer)
 from public,anon,authenticated;
grant execute on function public.phase7_host_month_diamond_conservation(date,integer,integer)
 to authenticated;
