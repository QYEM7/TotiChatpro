-- Staging, auditable read-only host month preflight.
-- No salary rates, diamond reset, or money movement assumed.
create index if not exists tc_gifts_host_month on public.gift_events(agency_id,created_at,recipient_id) where agency_id is not null;
create function phase3.host_month_preflight(p_month date,p_offset integer default 0,p_limit integer default 50)
returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=phase3.actor(); permission jsonb:=phase3.admin_session();
 start_month timestamptz;end_month timestamptz;total bigint;records jsonb;
begin
 if not (coalesce((permission->>'isOwner')::boolean,false) or
  coalesce((permission->>'isMainPartner')::boolean,false)) then
  raise exception 'Host agency monthly reports require Owner or designated main partner'
   using errcode='42501';
 end if;
 if p_month is null or extract(day from p_month)<>1 or
  p_month>=date_trunc('month',now() at time zone 'UTC')::date or
  p_month<date '2025-01-01' or p_offset not between 0 and 50000 or
  p_limit not between 1 and 100 then raise exception 'Select a closed UTC month';end if;
 start_month:=(p_month::timestamp at time zone 'UTC');
 end_month:=((p_month+interval '1 month')::timestamp at time zone 'UTC');
 with aggregates as (
  select e.agency_id,e.recipient_id user_id,
  sum(l.amount)::bigint earned_diamonds,
  sum(l.remaining)::bigint remaining_diamonds,
  sum(l.amount-l.remaining)::bigint converted_or_allocated_diamonds
  from public.gift_events e join public.diamond_lots l on l.gift_event_id=e.id
  join public.agencies a on a.id=e.agency_id and a.kind='host'
  where e.created_at>=start_month and e.created_at<end_month
  group by e.agency_id,e.recipient_id
 )
 select count(*) into total from aggregates;
 with aggregates as (
  select e.agency_id,e.recipient_id user_id,
  sum(l.amount)::bigint earned_diamonds,
  sum(l.remaining)::bigint remaining_diamonds,
  sum(l.amount-l.remaining)::bigint converted_or_allocated_diamonds
  from public.gift_events e join public.diamond_lots l on l.gift_event_id=e.id
  join public.agencies a on a.id=e.agency_id and a.kind='host'
  where e.created_at>=start_month and e.created_at<end_month
  group by e.agency_id,e.recipient_id
 )
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into records
 from (select * from aggregates order by agency_id,user_id offset p_offset limit p_limit) q;
 return jsonb_build_object(
  'month',p_month,'isDraftPreflight',true,
  'canZeroDiamonds',false,'paysSalaries',false,'hasPayrollRates',false,
  'remainingValuesAreCurrent',true,'asOf',now(),
  'totalHostEntries',total,'entries',records);
end $$;
revoke all on function phase3.host_month_preflight(date,integer,integer) from public,anon;
grant execute on function phase3.host_month_preflight(date,integer,integer) to authenticated;
create function public.phase5_host_month_preflight(p_month date,p_offset integer default 0,p_limit integer default 50)
returns jsonb language sql security invoker set search_path='' as $$
 select phase3.host_month_preflight(p_month,p_offset,p_limit) $$;
revoke all on function public.phase5_host_month_preflight(date,integer,integer) from public,anon;
grant execute on function public.phase5_host_month_preflight(date,integer,integer) to authenticated;
