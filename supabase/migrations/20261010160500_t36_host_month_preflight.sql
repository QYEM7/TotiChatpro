-- T36 preflight only: never zero operational diamonds or pay salaries.
-- A prior closed UTC month can be inspected ONLY by Owner or designated main partner.
create function public.phase5_host_month_preflight(
 p_month date,p_offset integer default 0,p_limit integer default 100
) returns jsonb language plpgsql security definer set search_path='' as $function$
declare rights jsonb:=phase3.admin_session();
        report jsonb:='[]'::jsonb;row_count bigint:=0;
        period_end timestamptz;period_start timestamptz;
begin
 if not coalesce((rights->>'canManageHostAgencies')::boolean,false) then
   raise exception 'Owner or designated main partner required'
    using errcode='42501';
 end if;
 if p_month is null or p_month<>date_trunc('month',p_month::timestamp)::date
    or p_month>=date_trunc('month',now() at time zone 'UTC')::date
    or p_month<date '2025-01-01'
    or p_offset is null or p_offset<0 or p_offset>100000
    or p_limit is null or p_limit<1 or p_limit>100 then
  raise exception 'Closed UTC month and bounded pagination required';
 end if;
 period_start:=p_month::timestamp at time zone 'UTC';
 period_end:=(p_month+interval '1 month')::timestamp at time zone 'UTC';
 with accrual as (
  select g.agency_id,l.user_id,
         coalesce(sum(l.amount),0)::bigint as earned_diamonds,
         coalesce(sum(l.remaining),0)::bigint as remaining_diamonds,
         coalesce(sum(l.amount-l.remaining),0)::bigint as converted_or_allocated_diamonds
  from public.diamond_lots l
  join public.gift_events g on g.id=l.gift_event_id
  join public.agencies a on a.id=g.agency_id and a.kind='host'
  where g.created_at>=period_start and g.created_at<period_end
  group by g.agency_id,l.user_id
 ),
 paged as (
  select a.agency_id,a.user_id,a.earned_diamonds,a.remaining_diamonds,
         a.converted_or_allocated_diamonds
  from accrual a order by a.agency_id,a.user_id limit p_limit offset p_offset
 )
 select (select count(*) from accrual),
        coalesce((select jsonb_agg(to_jsonb(x)) from paged x),'[]'::jsonb)
 into row_count,report;
 return jsonb_build_object(
  'month',p_month,'timezone','UTC',
  'totalHostEntries',row_count,'offset',p_offset,'limit',p_limit,
  'entries',report,'isDraftPreflight',true,'hasPayrollRates',false,
  'canZeroDiamonds',false,'paysSalaries',false,
  'note','Accrual evidence only; entitlements, payroll, final ledgers, rate rules and snapshot persistence must be approved before any close/zeroing.'
 );
end $function$;
revoke all on function public.phase5_host_month_preflight(date,integer,integer) from public,anon,authenticated;
grant execute on function public.phase5_host_month_preflight(date,integer,integer) to authenticated;
comment on function public.phase5_host_month_preflight(date,integer,integer) is
 'T36 safe nonmutating historical host diamond accrual preflight. NEVER clears balances or pays wages.';
