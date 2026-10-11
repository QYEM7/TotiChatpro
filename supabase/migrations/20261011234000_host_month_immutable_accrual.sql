-- TotiChat Staging: immutable HOST diamond accrual evidence for a CLOSED UTC month.
-- No salary, commission, payout, conversion or diamond zeroing. Never invent rates.
-- Snapshot uses verified historical gift_events and lot-issued amounts, never current
-- remaining diamonds as an invented "balance at month close".
create table phase3.host_month_accrual_headers (
  month_start date primary key check(extract(day from month_start)=1),
  captured_by uuid not null references auth.users(id),
  capture_request_id uuid not null,
  captured_at timestamptz not null default now(),
  source_gifts bigint not null check(source_gifts>0),
  total_diamonds numeric(30,0) not null check(total_diamonds>0),
  entries_count bigint not null check(entries_count>0),
  status text not null default 'accrual_evidence'
    check(status='accrual_evidence'),
  unique(captured_by,capture_request_id)
);
create table phase3.host_month_accrual_lines(
  month_start date not null references phase3.host_month_accrual_headers(month_start),
  agency_id uuid not null references public.agencies(id),
  host_id uuid not null references auth.users(id),
  gift_count bigint not null check(gift_count>0),
  earned_diamonds numeric(30,0) not null check(earned_diamonds>0),
  primary key(month_start,agency_id,host_id)
);
create index tc_host_accrual_agency_month
  on phase3.host_month_accrual_lines(agency_id,month_start);
alter table phase3.host_month_accrual_headers enable row level security;
alter table phase3.host_month_accrual_lines enable row level security;
revoke all on phase3.host_month_accrual_headers,
 phase3.host_month_accrual_lines from public,anon,authenticated;

create function phase3.reject_host_accrual_changes()
returns trigger language plpgsql security invoker set search_path='' as $fn$
begin
 raise exception 'Monthly accrual evidence is immutable; only new closed months may be captured'
  using errcode='42501';
end $fn$;
revoke all on function phase3.reject_host_accrual_changes() from public,anon,authenticated;
create trigger tc_host_accrual_header_immutable
  before update or delete on phase3.host_month_accrual_headers
  for each row execute function phase3.reject_host_accrual_changes();
create trigger tc_host_accrual_line_immutable
  before update or delete on phase3.host_month_accrual_lines
  for each row execute function phase3.reject_host_accrual_changes();

create function phase3.host_month_snapshot_capture(p_month date,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 caller uuid:=phase3.actor();start_at timestamptz;end_at timestamptz;
 count_gifts bigint;total numeric;groups_count bigint;
 prior phase3.host_month_accrual_headers%rowtype;
begin
 if not exists(select 1 from phase3.system_authority a where a.singleton
    and (a.owner_id=caller or a.main_partner_id=caller)) then
  raise exception 'Only Owner or designated main partner can capture host month evidence'
   using errcode='42501';
 end if;
 if p_month is null or p_request_id is null
    or extract(day from p_month)<>1 or p_month<date '2025-01-01'
    or p_month>=date_trunc('month',now() at time zone 'UTC')::date then
  raise exception 'A closed UTC month and explicit unique request are required';
 end if;
 -- Prevent concurrent duplicate snapshots of a month across different admins.
 perform pg_advisory_xact_lock(pg_catalog.hashtextextended(
  'totichat:host-accrual:'||p_month::text,0));
 select * into prior from phase3.host_month_accrual_headers where month_start=p_month;
 if found then
  return jsonb_build_object('month',p_month,'captured',true,
   'alreadyCaptured',true,'capturedAt',prior.captured_at,
   'giftCount',prior.source_gifts,'entries',prior.entries_count,
   'totalDiamonds',prior.total_diamonds::text,
   'isAccrualEvidenceOnly',true,'paysSalaries',false,'canZeroDiamonds',false,
   'hasPayrollRates',false);
 end if;
 if exists(select 1 from phase3.host_month_accrual_headers h
     where h.captured_by=caller and h.capture_request_id=p_request_id) then
  raise exception 'Request key reused for another month';
 end if;
 start_at:=(p_month::timestamp at time zone 'UTC');
 end_at:=((p_month+interval '1 month')::timestamp at time zone 'UTC');
 select count(*),coalesce(sum(g.amount),0)::numeric(30,0)
 into count_gifts,total
 from public.gift_events g
 join public.agencies a on a.id=g.agency_id and a.kind='host'
 join public.diamond_lots l on l.gift_event_id=g.id
   and l.user_id=g.recipient_id and l.amount=g.amount
 where g.created_at>=start_at and g.created_at<end_at;
 if count_gifts=0 then
   raise exception 'No verified host gifts exist for this closed month; do not create empty settlement evidence';
 end if;
 select count(*) into groups_count from(
   select g.agency_id,g.recipient_id
   from public.gift_events g
   join public.agencies a on a.id=g.agency_id and a.kind='host'
   join public.diamond_lots l on l.gift_event_id=g.id
     and l.user_id=g.recipient_id and l.amount=g.amount
   where g.created_at>=start_at and g.created_at<end_at
   group by g.agency_id,g.recipient_id
 ) e;
 insert into phase3.host_month_accrual_headers(
   month_start,captured_by,capture_request_id,source_gifts,total_diamonds,entries_count
 ) values(p_month,caller,p_request_id,count_gifts,total,groups_count);
 insert into phase3.host_month_accrual_lines(
   month_start,agency_id,host_id,gift_count,earned_diamonds
 )
 select p_month,g.agency_id,g.recipient_id,count(*),sum(g.amount)
 from public.gift_events g
 join public.agencies a on a.id=g.agency_id and a.kind='host'
 join public.diamond_lots l on l.gift_event_id=g.id
   and l.user_id=g.recipient_id and l.amount=g.amount
 where g.created_at>=start_at and g.created_at<end_at
 group by g.agency_id,g.recipient_id;
 insert into public.security_audit(actor_id,action,details)
 values(caller,'host_accrual_snapshot_captured',
   jsonb_build_object('month',p_month,'gifts',count_gifts,
    'entries',groups_count,'requestId',p_request_id));
 return jsonb_build_object('month',p_month,'captured',true,
  'alreadyCaptured',false,'giftCount',count_gifts,'entries',groups_count,
  'totalDiamonds',total::text,'isAccrualEvidenceOnly',true,
  'paysSalaries',false,'canZeroDiamonds',false,'hasPayrollRates',false);
end $fn$;
revoke all on function phase3.host_month_snapshot_capture(date,uuid) from public,anon;
grant execute on function phase3.host_month_snapshot_capture(date,uuid) to authenticated;

create function phase3.host_month_snapshot_state(
 p_month date,p_offset integer default 0,p_limit integer default 50)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();head phase3.host_month_accrual_headers%rowtype;
 items jsonb;
begin
 if not exists(select 1 from phase3.system_authority a where a.singleton
     and (a.owner_id=caller or a.main_partner_id=caller)) then
  raise exception 'Only Owner or designated main partner can inspect host month evidence'
   using errcode='42501';
 end if;
 if p_month is null or extract(day from p_month)<>1 or p_month<date '2025-01-01'
   or p_month>=date_trunc('month',now() at time zone 'UTC')::date
   or p_offset is null or p_offset not between 0 and 50000
   or p_limit is null or p_limit not between 1 and 100 then
  raise exception 'Invalid closed-month snapshot page';
 end if;
 select * into head from phase3.host_month_accrual_headers where month_start=p_month;
 if not found then
  return jsonb_build_object('month',p_month,'captured',false,'entries',0,
    'items','[]'::jsonb,'isAccrualEvidenceOnly',true,'paysSalaries',false,
    'canZeroDiamonds',false,'hasPayrollRates',false);
 end if;
 select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
  select agency_id,host_id,gift_count,earned_diamonds::text earned_diamonds
  from phase3.host_month_accrual_lines
  where month_start=p_month order by agency_id,host_id
  offset p_offset limit p_limit
 ) v;
 return jsonb_build_object('month',p_month,'captured',true,
  'capturedAt',head.captured_at,'giftCount',head.source_gifts,
  'totalDiamonds',head.total_diamonds::text,'entries',head.entries_count,
  'offset',p_offset,'limit',p_limit,'items',items,
  'isAccrualEvidenceOnly',true,'paysSalaries',false,
  'canZeroDiamonds',false,'hasPayrollRates',false);
end $fn$;
revoke all on function phase3.host_month_snapshot_state(date,integer,integer)
 from public,anon;
grant execute on function phase3.host_month_snapshot_state(date,integer,integer)
 to authenticated;

create function public.phase5_host_month_snapshot_capture(p_month date,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.host_month_snapshot_capture(p_month,p_request_id);
end $fn$;
create function public.phase5_host_month_snapshot_state(
 p_month date,p_offset integer default 0,p_limit integer default 50)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.host_month_snapshot_state(p_month,p_offset,p_limit);
end $fn$;
revoke all on function public.phase5_host_month_snapshot_capture(date,uuid),
 public.phase5_host_month_snapshot_state(date,integer,integer) from public,anon;
grant execute on function public.phase5_host_month_snapshot_capture(date,uuid),
 public.phase5_host_month_snapshot_state(date,integer,integer) to authenticated;
comment on function public.phase5_host_month_snapshot_capture(date,uuid) is
 'Explicit Owner/main-partner capture of immutable verified HISTORICAL host diamond earnings. NOT settlement or month-close reset.';
