create table phase3.system_authority (
 singleton boolean primary key default true check(singleton),owner_email text not null,
 owner_id uuid unique references auth.users(id),main_partner_id uuid unique references auth.users(id)
);
insert into phase3.system_authority(owner_email) values('xxjjh20@gmail.com');
create table phase3.admin_access (
 user_id uuid primary key references auth.users(id),role text not null check(role in('admin','super_admin','db')),
 permissions text[] not null default '{}' check(permissions<@array['catalog.manage','reports.read','users.manage','host_agency.open']::text[]),
 assigned_by uuid not null references auth.users(id),updated_at timestamptz not null default now()
);
create table phase3.admin_requests (
 actor_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_id,request_id)
);
revoke all on phase3.system_authority,phase3.admin_access,phase3.admin_requests from public,anon,authenticated;
create function phase3.is_owner() returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); authority phase3.system_authority%rowtype;
begin
 select * into authority from phase3.system_authority where singleton for update;
 if authority.owner_id is not null then return authority.owner_id=u;end if;
 if exists(select 1 from auth.users where id=u and lower(email)=authority.owner_email and email_confirmed_at is not null) then
  update phase3.system_authority set owner_id=u where singleton;return true;
 end if;return false;
end $$;
create function phase3.admin_session() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); own boolean:=phase3.is_owner(); access phase3.admin_access%rowtype; partner boolean;
begin
 select * into access from phase3.admin_access where user_id=u;
 select main_partner_id=u into partner from phase3.system_authority where singleton;
 return jsonb_build_object('isOwner',own,'isMainPartner',coalesce(partner,false),'role',case when own then 'owner' else coalesce(access.role,'user') end,'permissions',coalesce(to_jsonb(access.permissions),'[]'::jsonb),
 'canManageCatalogs',own or coalesce(partner,false) or coalesce('catalog.manage'=any(access.permissions),false),
 'canManageHostAgencies',own or coalesce(partner,false),'canManageRechargeAgencies',own);
end $$;
create function phase3.manage_access(p_user_id uuid,p_role text,p_permissions text[],p_main_partner boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();
begin
 if not phase3.is_owner() then raise exception 'Owner only' using errcode='42501';end if;
 if p_user_id is null or p_user_id=u or p_role is null or p_role not in('admin','super_admin','db') or p_permissions is null or not(p_permissions<@array['catalog.manage','reports.read','users.manage','host_agency.open']::text[]) or p_main_partner is null or (p_main_partner and p_role<>'super_admin') then raise exception 'Invalid role assignment';end if;
 if not exists(select 1 from auth.users where id=p_user_id and email_confirmed_at is not null and (banned_until is null or banned_until<now())) then raise exception 'Verified user required';end if;
 if exists(select 1 from phase3.system_authority where main_partner_id=p_user_id) and p_role<>'super_admin' then raise exception 'Remove main partner designation before changing role';end if;
 insert into phase3.admin_access(user_id,role,permissions,assigned_by) values(p_user_id,p_role,p_permissions,u)
 on conflict(user_id) do update set role=excluded.role,permissions=excluded.permissions,assigned_by=u,updated_at=now();
 if p_main_partner then update phase3.system_authority set main_partner_id=p_user_id where singleton;end if;
 insert into public.security_audit(actor_id,action,details) values(u,'role_assignment',jsonb_build_object('user',p_user_id,'role',p_role,'permissions',p_permissions,'main_partner',p_main_partner));
end $$;
create function phase3.require_catalog_admin() returns void language plpgsql security definer set search_path='' as $$
begin if not (phase3.admin_session()->>'canManageCatalogs')::boolean then raise exception 'Catalog permission required' using errcode='42501';end if;end $$;
create function phase3.catalog_list(p_table text,p_offset integer default 0,p_limit integer default 100) returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb;total bigint;
begin
 perform phase3.require_catalog_admin();
 if p_table is null or p_table not in('gift_categories','gift_catalog','store_catalog','cp_types','recharge_packages','recharge_reward_tiers') or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid catalog query';end if;
 execute format('select coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) from (select * from public.%I order by id limit $1 offset $2) r',p_table) into rows using p_limit,p_offset;
 execute format('select count(*) from public.%I',p_table) into total;
 return jsonb_build_object('rows',rows,'total',total,'offset',p_offset,'limit',p_limit);
end $$;
create function phase3.catalog_write(p_table text,p_action text,p_id text,p_record jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); body jsonb; prior phase3.admin_requests%rowtype; column_name text; columns_sql text:=''; values_sql text:=''; updates_sql text:=''; answer jsonb;
begin
 perform phase3.require_catalog_admin();
 if p_table is null or p_table not in('gift_categories','gift_catalog','store_catalog','cp_types','recharge_packages','recharge_reward_tiers') or p_action is null or p_action not in('create','update','delete') or p_request_id is null then raise exception 'Invalid catalog operation';end if;
 if p_action<>'create' and (p_id is null or char_length(p_id)>100) then raise exception 'Record ID required';end if;
 if p_action<>'delete' and (p_record is null or jsonb_typeof(p_record)<>'object' or octet_length(p_record::text)>20000 or p_record='{}'::jsonb) then raise exception 'A nonempty record object is required';end if;
 body:=jsonb_build_object('table',p_table,'action',p_action,'id',p_id,'record',p_record);
 select * into prior from phase3.admin_requests where actor_id=u and request_id=p_request_id;
 if found then if prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from phase3.admin_requests where actor_id=u and created_at>now()-interval '1 minute')>=60 then raise exception 'Rate limit exceeded';end if;
 if p_action<>'delete' then
  for column_name in select jsonb_object_keys(p_record) loop
   if column_name in('created_at','updated_at') or (p_action='update' and column_name='id') or not exists(select 1 from information_schema.columns where table_schema='public' and table_name=p_table and information_schema.columns.column_name=column_name) then raise exception 'Unknown or immutable column: %',column_name;end if;
   columns_sql:=columns_sql||case when columns_sql='' then '' else ',' end||format('%I',column_name);
   values_sql:=values_sql||case when values_sql='' then '' else ',' end||format('v.%I',column_name);
   updates_sql:=updates_sql||case when updates_sql='' then '' else ',' end||format('%I=v.%I',column_name,column_name);
  end loop;
 end if;
 if p_action='create' then execute format('insert into public.%I as target (%s) select %s from jsonb_populate_record(null::public.%I,$1) v returning to_jsonb(target)',p_table,columns_sql,values_sql,p_table) into answer using p_record;
 elsif p_action='update' then execute format('update public.%I as target set %s from jsonb_populate_record(null::public.%I,$1) v where target.id::text=$2 returning to_jsonb(target)',p_table,updates_sql,p_table) into answer using p_record,p_id;
 else execute format('delete from public.%I as target where id::text=$1 returning to_jsonb(target)',p_table) into answer using p_id;end if;
 if answer is null then raise exception 'Record not found';end if;
 insert into phase3.admin_requests(actor_id,request_id,payload,result) values(u,p_request_id,body,answer);
 insert into public.security_audit(actor_id,action,details) values(u,'catalog_'||p_action,jsonb_build_object('table',p_table,'id',answer->>'id','request',p_request_id,'record',answer));
 return answer;
end $$;
revoke all on function phase3.is_owner(),phase3.admin_session(),phase3.manage_access(uuid,text,text[],boolean),phase3.require_catalog_admin(),phase3.catalog_list(text,integer,integer),phase3.catalog_write(text,text,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function phase3.admin_session(),phase3.manage_access(uuid,text,text[],boolean),phase3.catalog_list(text,integer,integer),phase3.catalog_write(text,text,text,jsonb,uuid) to authenticated;
create function public.phase3_admin_session() returns jsonb language sql security invoker set search_path='' as $$select phase3.admin_session()$$;
create function public.phase3_manage_access(p_user_id uuid,p_role text,p_permissions text[],p_main_partner boolean default false) returns void language sql security invoker set search_path='' as $$select phase3.manage_access(p_user_id,p_role,p_permissions,p_main_partner)$$;
create function public.phase3_catalog_list(p_table text,p_offset integer default 0,p_limit integer default 100) returns jsonb language sql security invoker set search_path='' as $$select phase3.catalog_list(p_table,p_offset,p_limit)$$;
create function public.phase3_catalog_write(p_table text,p_action text,p_id text,p_record jsonb,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.catalog_write(p_table,p_action,p_id,p_record,p_request_id)$$;
revoke all on function public.phase3_admin_session(),public.phase3_manage_access(uuid,text,text[],boolean),public.phase3_catalog_list(text,integer,integer),public.phase3_catalog_write(text,text,text,jsonb,uuid) from public,anon;
grant execute on function public.phase3_admin_session(),public.phase3_manage_access(uuid,text,text[],boolean),public.phase3_catalog_list(text,integer,integer),public.phase3_catalog_write(text,text,text,jsonb,uuid) to authenticated;
