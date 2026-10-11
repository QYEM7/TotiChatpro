-- Staging follow-up: disambiguate PL/pgSQL actor variable from table column.
CREATE OR REPLACE FUNCTION phase3.banner_action(p_action text, p_id uuid, p_data jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare current_actor uuid:=phase3.actor();
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
 perform pg_advisory_xact_lock(hashtextextended(current_actor::text||p_request_id::text,0));
 select * into prior from phase3.banner_action_requests r
  where r.actor_id=current_actor and r.request_id=p_request_id;
 if found then
  if prior.payload<>fingerprint then raise exception 'Idempotency conflict';end if;
  return prior.result;
 end if;
 if (select count(*) from phase3.banner_action_requests r
   where r.actor_id=current_actor and r.created_at>now()-interval '1 minute')>=30 then
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
 values(current_actor,p_request_id,fingerprint,answer);
 insert into public.security_audit(actor_id,action,details)
 values(current_actor,'admin_banner_'||p_action,jsonb_build_object('bannerId',banner_row.id,
  'requestId',p_request_id));
 return answer;
end $function$
;
