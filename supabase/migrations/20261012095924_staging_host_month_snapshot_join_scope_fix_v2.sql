-- Scope the stored snapshot rows to the specific closed month BEFORE full outer joining;
-- otherwise previously captured unrelated months appear as false mismatches.
CREATE OR REPLACE FUNCTION phase3.host_month_evidence_integrity(p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller uuid:=phase3.actor();
  month_from timestamptz; month_to timestamptz;
  all_gifts bigint; verified_gifts bigint; malformed_gifts bigint;
  unassigned bigint; raw_diamonds numeric; verified_diamonds numeric;
  expected_groups bigint; actual_groups bigint; group_mismatches bigint;
  head phase3.host_month_accrual_headers%rowtype;
  line_gifts numeric;line_diamonds numeric;line_count bigint;
  snapshot_ok boolean:=false;
begin
 if not exists(select 1 from phase3.system_authority a where a.singleton
   and (a.owner_id=caller or a.main_partner_id=caller)) then
  raise exception 'Only Owner or designated main partner may audit host month evidence'
  using errcode='42501';
 end if;
 if p_month is null or extract(day from p_month)<>1 or
  p_month<date '2025-01-01' or
  p_month>=date_trunc('month',now() at time zone 'UTC')::date then
  raise exception 'A closed UTC month is required';
 end if;
 month_from:=p_month::timestamp at time zone 'UTC';
 month_to:=(p_month+interval '1 month')::timestamp at time zone 'UTC';

 -- Never infer missing agency attribution from someone's CURRENT agency:
 -- only the gift's recorded historical agency_id is authoritative.
 select count(*) into unassigned from public.gift_events g
 where g.created_at>=month_from and g.created_at<month_to and g.agency_id is null;

 -- Outer-join against the issued lot to detect events excluded by the existing
 -- immutable snapshot's inner join (missing/mismatched lot).
 select count(*),count(*) filter(where l.id is not null and
     l.user_id=g.recipient_id and l.amount=g.amount and
     l.source_type=g.diamond_source_type),
   count(*) filter(where l.id is null or l.user_id is distinct from g.recipient_id
     or l.amount is distinct from g.amount
     or l.source_type is distinct from g.diamond_source_type),
   coalesce(sum(g.amount),0)::numeric,
   coalesce(sum(g.amount) filter(where l.id is not null and
     l.user_id=g.recipient_id and l.amount=g.amount and
     l.source_type=g.diamond_source_type),0)::numeric
 into all_gifts,verified_gifts,malformed_gifts,raw_diamonds,verified_diamonds
 from public.gift_events g
 join public.agencies a on a.id=g.agency_id and a.kind='host'
 left join public.diamond_lots l on l.gift_event_id=g.id
 where g.created_at>=month_from and g.created_at<month_to;

 with current_groups as(
 select g.agency_id,g.recipient_id,count(*)::bigint n,
     sum(g.amount)::numeric diamonds
 from public.gift_events g
 join public.agencies a on a.id=g.agency_id and a.kind='host'
 join public.diamond_lots l on l.gift_event_id=g.id
  and l.user_id=g.recipient_id and l.amount=g.amount
  and l.source_type=g.diamond_source_type
 where g.created_at>=month_from and g.created_at<month_to
 group by g.agency_id,g.recipient_id
 )
 select count(*) into expected_groups from current_groups;

 select * into head from phase3.host_month_accrual_headers
  where month_start=p_month;
 if found then
   select count(*),coalesce(sum(l.gift_count),0)::numeric,
     coalesce(sum(l.earned_diamonds),0)::numeric
   into line_count,line_gifts,line_diamonds
   from phase3.host_month_accrual_lines l where l.month_start=p_month;

   with current_groups as(
    select g.agency_id,g.recipient_id,count(*)::bigint gifts,
      sum(g.amount)::numeric diamonds
    from public.gift_events g
    join public.agencies a on a.id=g.agency_id and a.kind='host'
    join public.diamond_lots l on l.gift_event_id=g.id
      and l.user_id=g.recipient_id and l.amount=g.amount
      and l.source_type=g.diamond_source_type
    where g.created_at>=month_from and g.created_at<month_to
    group by g.agency_id,g.recipient_id
   )
   select count(*) into group_mismatches
   from current_groups cur full outer join (select * from phase3.host_month_accrual_lines where month_start=p_month) saved
    on true
    and saved.agency_id=cur.agency_id and saved.host_id=cur.recipient_id
   where cur.agency_id is null or saved.agency_id is null
    or saved.gift_count is distinct from cur.gifts
    or saved.earned_diamonds is distinct from cur.diamonds;

   snapshot_ok:=
     malformed_gifts=0 and
     head.source_gifts=all_gifts and
     head.total_diamonds=raw_diamonds and
     head.entries_count=expected_groups and
     head.entries_count=line_count and
     line_gifts=all_gifts and line_diamonds=raw_diamonds and
     group_mismatches=0;
 else
   line_count:=0;line_gifts:=0;line_diamonds:=0;group_mismatches:=0;
 end if;
 return jsonb_build_object(
  'month',p_month,'asOf',now(),'isReadOnly',true,
  'usesHistoricalGiftAgency',true,
  'unassignedGiftEventsForReview',unassigned,
  'hostGiftEvents',all_gifts,'verifiedHostGiftEvents',verified_gifts,
  'hostGiftsMissingOrMismatchedLots',malformed_gifts,
  'hostGiftDiamonds',raw_diamonds::text,
  'verifiedHostGiftDiamonds',verified_diamonds::text,
  'actualHostGroups',expected_groups,
  'snapshotCaptured',head.month_start is not null,
  'snapshotCapturedAt',head.captured_at,
  'snapshotGiftEvents',coalesce(head.source_gifts,0),
  'snapshotDiamonds',coalesce(head.total_diamonds,0)::text,
  'snapshotGroups',coalesce(head.entries_count,0),
  'snapshotLineGroups',line_count,
  'snapshotLineGiftEvents',line_gifts::text,
  'snapshotLineDiamonds',line_diamonds::text,
  'snapshotGroupMismatches',group_mismatches,
  'snapshotConsistent',snapshot_ok,
  'hasEvidenceProblems',(malformed_gifts>0 or (head.month_start is not null and not snapshot_ok)),
  'hasVerifiedHistory',all_gifts>0 and malformed_gifts=0,
  'canApprovePayroll',false,'hasPayrollRates',false,
  'canPaySalaries',false,'canZeroDiamonds',false,
  'isAccrualEvidenceOnly',true);
end $function$

