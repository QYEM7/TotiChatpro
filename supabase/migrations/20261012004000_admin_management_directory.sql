-- TotiChat independent admin — isolated Staging, bounded Owner/main-partner READ-ONLY management pages.
-- Does not change existing owner or partner identities. Does not alter financial data.
create function phase3.admin_management_page(
 p_kind text, p_offset integer default 0, p_limit integer default 30)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor_id uuid:=phase3.actor(); allowed boolean:=false;
 total bigint:=0; rows_out jsonb:='[]'::jsonb;
begin
 allowed:=phase3.is_owner() or exists(
  select 1 from phase3.system_authority s where s.singleton and s.main_partner_id=actor_id);
 if not allowed then raise exception 'Owner or designated main partner only' using errcode='42501';end if;
 if p_kind is null or p_kind not in('staff','host_agencies','recharge_agencies',
    'registrations','agency_transfers','audit') or p_offset is null or p_offset not between 0 and 50000
    or p_limit is null or p_limit not between 1 and 50 then
  raise exception 'Invalid management page';
 end if;
 if p_kind='staff' then
  select count(*) into total from phase3.admin_access;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows_out from(
   select user_id,role,permissions,assigned_by,updated_at
   from phase3.admin_access order by updated_at desc,user_id
   offset p_offset limit p_limit) x;
 elsif p_kind in('host_agencies','recharge_agencies') then
  select count(*) into total from public.agencies a
   where a.kind=case when p_kind='host_agencies' then 'host' else 'recharge' end;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows_out from(
   select a.id,a.name,a.kind,a.owner_id,a.commission_percent::text commission_percent,
    a.is_active,a.created_at,
    (select count(*) from public.agency_members m where m.agency_id=a.id) member_count
   from public.agencies a
   where a.kind=case when p_kind='host_agencies' then 'host' else 'recharge' end
   order by a.created_at desc,a.id offset p_offset limit p_limit) x;
 elsif p_kind='registrations' then
  select count(*) into total from public.agency_registrations;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows_out from(
   select id,applicant_id,kind,name,status,agency_id,created_at,reviewed_at
   from public.agency_registrations order by created_at desc,id
   offset p_offset limit p_limit) x;
 elsif p_kind='agency_transfers' then
  select count(*) into total from public.agency_join_requests;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows_out from(
   select id,user_id,agency_id,old_agency_id,status,reason,created_at,updated_at
   from public.agency_join_requests order by created_at desc,id
   offset p_offset limit p_limit) x;
 else
  select count(*) into total from public.security_audit;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows_out from(
   select id,actor_id,action,operation_id,created_at
   from public.security_audit order by id desc
   offset p_offset limit p_limit) x;
 end if;
 return jsonb_build_object('kind',p_kind,'rows',rows_out,'total',total,
   'offset',p_offset,'limit',p_limit,'readOnly',true,'asOf',now());
end $fn$;
revoke all on function phase3.admin_management_page(text,integer,integer)
 from public,anon;
grant execute on function phase3.admin_management_page(text,integer,integer) to authenticated;

create function public.phase6_admin_management_page(
 p_kind text,p_offset integer default 0,p_limit integer default 30)
returns jsonb language sql security invoker set search_path='' as $fn$
 select phase3.admin_management_page(p_kind,p_offset,p_limit) $fn$;
revoke all on function public.phase6_admin_management_page(text,integer,integer)
 from public,anon;
grant execute on function public.phase6_admin_management_page(text,integer,integer)
 to authenticated;
