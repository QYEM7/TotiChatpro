-- Owner/main-partner-only bounded read-only directory for standalone TotiChat Admin Staging.
-- No authentication email disclosure and no user/room moderation writes.
create function phase3.admin_directory(
 p_kind text,p_query text default '',p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security definer set search_path='' as $f$
declare caller uuid:=phase3.actor();q text:=btrim(coalesce(p_query,''));n bigint;items jsonb;
begin
 if not (phase3.is_owner() or exists(select 1 from phase3.system_authority s
      where s.singleton and s.main_partner_id=caller)) then
  raise exception 'Owner or designated main partner required' using errcode='42501';
 end if;
 if p_kind is null or p_kind not in('users','rooms')
  or length(q)>60 or p_offset is null or p_offset not between 0 and 100000
  or p_limit is null or p_limit not between 1 and 50 then
  raise exception 'Invalid directory request';
 end if;
 if p_kind='users' then
  select count(*) into n from public.profiles p
   where q='' or p.display_name ilike '%'||q||'%';
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
   select p.id,p.display_name,p.avatar_url,p.created_at
   from public.profiles p
   where q='' or p.display_name ilike '%'||q||'%'
   order by p.created_at desc,p.id
   offset p_offset limit p_limit
  ) v;
 else
  select count(*) into n from public.rooms r
   where q='' or r.title ilike '%'||q||'%';
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) into items from(
   select r.id,r.title,r.owner_id,r.is_private,r.created_at,
     (select count(*) from public.room_members rm where rm.room_id=r.id) as member_records
   from public.rooms r
   where q='' or r.title ilike '%'||q||'%'
   order by r.created_at desc,r.id
   offset p_offset limit p_limit
  ) v;
 end if;
 return jsonb_build_object('kind',p_kind,'rows',items,'total',n,
  'offset',p_offset,'limit',p_limit,'readOnly',true,'asOf',now());
end $f$;
revoke all on function phase3.admin_directory(text,text,integer,integer) from public,anon;
grant execute on function phase3.admin_directory(text,text,integer,integer) to authenticated;
create function public.phase6_admin_directory(
 p_kind text,p_query text default '',p_offset integer default 0,p_limit integer default 30)
returns jsonb language sql security invoker set search_path='' as $f$
 select phase3.admin_directory(p_kind,p_query,p_offset,p_limit) $f$;
revoke all on function public.phase6_admin_directory(text,text,integer,integer) from public,anon;
grant execute on function public.phase6_admin_directory(text,text,integer,integer) to authenticated;

-- Storage deleting an unused banner needs storage.objects SELECT in addition to DELETE.
create policy tc_admin_banner_owner_list on storage.objects for select to authenticated
using(bucket_id='totichat-admin-banners' and phase3.banner_admin_allowed());
