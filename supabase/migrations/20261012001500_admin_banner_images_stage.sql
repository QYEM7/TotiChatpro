-- TotiChat Admin Dashboard, isolated staging. Static WebP only <=500 KiB.
-- Existing published home banner RLS remains unchanged.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('totichat-admin-banners','totichat-admin-banners',true,512000,array['image/webp']::text[])
on conflict(id) do nothing;

create function phase3.banner_admin_allowed()
returns boolean language plpgsql security definer set search_path='' as $f$
declare actor_id uuid:=phase3.actor();
begin
 return phase3.is_owner() or exists(
  select 1 from phase3.system_authority s
  where s.singleton and s.main_partner_id=actor_id);
end $f$;
revoke all on function phase3.banner_admin_allowed() from public,anon;
grant execute on function phase3.banner_admin_allowed() to authenticated;

create function phase3.banner_image_can_remove(p_path text)
returns boolean language plpgsql security definer set search_path='' as $f$
begin
 return phase3.banner_admin_allowed()
  and p_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'
  and not exists(select 1 from public.home_banners b
   where b.image_url='https://rziaedugbdwefbefcxjt.supabase.co/storage/v1/object/public/totichat-admin-banners/'||p_path);
end $f$;
revoke all on function phase3.banner_image_can_remove(text) from public,anon;
grant execute on function phase3.banner_image_can_remove(text) to authenticated;

create policy tc_admin_banner_upload on storage.objects for insert to authenticated
 with check(bucket_id='totichat-admin-banners'
 and split_part(name,'/',1)=(select auth.uid())::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'
 and phase3.banner_admin_allowed());
create policy tc_admin_banner_cleanup on storage.objects for delete to authenticated
 using(bucket_id='totichat-admin-banners'
 and phase3.banner_image_can_remove(name));

create table phase3.banner_action_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id));
alter table phase3.banner_action_requests enable row level security;
revoke all on phase3.banner_action_requests from public,anon,authenticated;

create function phase3.banner_list(p_offset integer default 0,p_limit integer default 30)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare entries jsonb;total bigint;
begin
 if not phase3.banner_admin_allowed() then raise exception 'Only Owner or designated main partner' using errcode='42501';end if;
 if p_offset is null or p_offset not between 0 and 100000
  or p_limit is null or p_limit not between 1 and 60 then
   raise exception 'Invalid page';end if;
 select count(*) into total from public.home_banners;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into entries from(
  select id,title,image_url,link_kind,link_target,status,sort_order,starts_at,ends_at,created_at
  from public.home_banners order by sort_order,created_at desc,id limit p_limit offset p_offset
 ) t;
 return jsonb_build_object('rows',entries,'total',total);
end $f$;
revoke all on function phase3.banner_list(integer,integer) from public,anon;
grant execute on function phase3.banner_list(integer,integer) to authenticated;

create function phase3.banner_action(p_action text,p_id uuid,p_data jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor_id uuid:=phase3.actor();
 prior phase3.banner_action_requests%rowtype;banner_row public.home_banners%rowtype;
 fingerprint jsonb;answer jsonb;
 v_title text;v_path text;v_url text;v_kind text;v_target text;v_status text;
 v_sort integer;v_start timestamptz;v_end timestamptz;
begin
 if not phase3.banner_admin_allowed() then raise exception 'Admin permission required' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in ('create','update','delete') or
   (p_action='create' and p_id is not null) or (p_action<>'create' and p_id is null) or
   p_data is null or jsonb_typeof(p_data)<>'object' then
   raise exception 'Invalid banner request';end if;
 fingerprint:=jsonb_build_object('action',p_action,'id',p_id,'data',p_data);
 perform pg_advisory_xact_lock(hashtextextended(actor_id::text||p_request_id::text,0));
 select * into prior from phase3.banner_action_requests
  where actor_id=actor_id and request_id=p_request_id;
 if found then
  if prior.payload<>fingerprint then raise exception 'Idempotency conflict';end if;
  return prior.result;
 end if;
 if (select count(*) from phase3.banner_action_requests r
   where r.actor_id=actor_id and r.created_at>now()-interval '1 minute')>=30 then
   raise exception 'Banner operation rate exceeded';end if;
 if p_action='delete' then
  select * into banner_row from public.home_banners where id=p_id for update;
  if not found then raise exception 'Banner not found';end if;
  if banner_row.status='published' then raise exception 'Archive before deletion';end if;
  delete from public.home_banners where id=p_id;
  answer:=jsonb_build_object('id',p_id,'deleted',true);
 else
  v_title:=btrim(coalesce(p_data->>'title',''));
  v_path:=p_data->>'image_path';
  v_kind:=coalesce(p_data->>'link_kind','none');
  v_target:=nullif(btrim(coalesce(p_data->>'link_target','')),'');
  v_status:=coalesce(p_data->>'status','draft');
  if v_title='' or char_length(v_title)>120 then raise exception 'Title length invalid';end if;
  if v_path is null or v_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' then raise exception 'WebP path required';end if;
  if v_kind not in ('none','screen') or v_status not in ('draft','published','archived') then
   raise exception 'Invalid kind/status';end if;
  if v_kind='none' and v_target is not null then raise exception 'Unexpected route';end if;
  if v_kind='screen' and (v_target is null or not (v_target=any(array[
   'home','room','ranks','cp','agencyPreview','agency','storePreview','vip','wallet',
   'me','tour','profilePreview','rechargePreview','discoverPreview']))) then
   raise exception 'Unsupported app route';end if;
  if coalesce(p_data->>'sort_order','') !~ '^[0-9]{1,5}$' then raise exception 'Invalid sort';end if;
  v_sort:=(p_data->>'sort_order')::integer;
  if v_sort>10000 then raise exception 'Sort max 10000';end if;
  begin
   v_start:=nullif(p_data->>'starts_at','')::timestamptz;
   v_end:=nullif(p_data->>'ends_at','')::timestamptz;
  exception when others then raise exception 'Invalid schedule';end;
  if v_start is not null and v_end is not null and v_start>=v_end then raise exception 'Schedule bounds invalid';end if;
  if not exists(select 1 from storage.objects o
    where o.bucket_id='totichat-admin-banners' and o.name=v_path) then
    raise exception 'Upload image before saving banner';end if;
  v_url:='https://rziaedugbdwefbefcxjt.supabase.co/storage/v1/object/public/totichat-admin-banners/'||v_path;
  if p_action='create' then
   insert into public.home_banners(title,image_url,link_kind,link_target,status,sort_order,starts_at,ends_at)
   values(v_title,v_url,v_kind,v_target,v_status,v_sort,v_start,v_end)
   returning * into banner_row;
  else
   update public.home_banners set title=v_title,image_url=v_url,link_kind=v_kind,
    link_target=v_target,status=v_status,sort_order=v_sort,starts_at=v_start,ends_at=v_end,updated_at=now()
   where id=p_id returning * into banner_row;
   if not found then raise exception 'Banner not found';end if;
  end if;
  answer:=jsonb_build_object('id',banner_row.id,'status',banner_row.status,'saved',true);
 end if;
 insert into phase3.banner_action_requests(actor_id,request_id,payload,result)
 values(actor_id,p_request_id,fingerprint,answer);
 insert into public.security_audit(actor_id,action,details)
 values(actor_id,'admin_banner_'||p_action,jsonb_build_object('bannerId',banner_row.id,
  'requestId',p_request_id));
 return answer;
end $f$;
revoke all on function phase3.banner_action(text,uuid,jsonb,uuid) from public,anon;
grant execute on function phase3.banner_action(text,uuid,jsonb,uuid) to authenticated;

create function public.phase6_admin_banner_list(p_offset integer default 0,p_limit integer default 30)
returns jsonb language sql security invoker set search_path='' as $f$
 select phase3.banner_list(p_offset,p_limit) $f$;
create function public.phase6_admin_banner_action(
 p_action text,p_id uuid,p_data jsonb,p_request_id uuid)
returns jsonb language sql security invoker set search_path='' as $f$
 select phase3.banner_action(p_action,p_id,p_data,p_request_id) $f$;
revoke all on function public.phase6_admin_banner_list(integer,integer),
 public.phase6_admin_banner_action(text,uuid,jsonb,uuid) from public,anon;
grant execute on function public.phase6_admin_banner_list(integer,integer),
 public.phase6_admin_banner_action(text,uuid,jsonb,uuid) to authenticated;
