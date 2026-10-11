-- TotiChat: manual verified achievements. NO fake medals, wallet debit,
-- points, auto-granting rules or VIP upgrades. Owner approves every catalog
-- badge and every grant/revocation until a separate rulebook is authorized.
create table public.medal_catalog(
 medal_key text primary key check(medal_key~'^[a-z][a-z0-9_-]{2,39}$'),
 display_name text not null check(char_length(btrim(display_name)) between 3 and 60),
 description text not null default '' check(char_length(description)<=180),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.medal_catalog enable row level security;
revoke all on public.medal_catalog from public,anon,authenticated;

create table public.medal_entitlements(
 user_id uuid not null references auth.users(id) on delete cascade,
 medal_key text not null references public.medal_catalog(medal_key),
 granted_at timestamptz not null default now(),
 granted_by uuid not null references auth.users(id),
 revoked_at timestamptz,
 revoked_by uuid references auth.users(id),
 primary key(user_id,medal_key),
 constraint tc_medal_revocation_pair check(
   (revoked_at is null and revoked_by is null) or
   (revoked_at is not null and revoked_by is not null))
);
create index tc_medal_active_user on public.medal_entitlements(user_id,granted_at desc)
 where revoked_at is null;
alter table public.medal_entitlements enable row level security;
revoke all on public.medal_entitlements from public,anon,authenticated;

create table phase3.medal_action_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_medal_action_rate on phase3.medal_action_requests(actor_id,created_at desc);
alter table phase3.medal_action_requests enable row level security;
revoke all on phase3.medal_action_requests from public,anon,authenticated;

create function phase3.medal_owner_action(
 p_action text,p_medal_key text,p_target uuid,p_label text,
 p_description text,p_reason text,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();
 med_key text:=btrim(coalesce(p_medal_key,''));
 reason text:=btrim(coalesce(p_reason,''));
 label_text text:=btrim(coalesce(p_label,''));
 description_text text:=btrim(coalesce(p_description,''));
 payload jsonb;existing phase3.medal_action_requests%rowtype;answer jsonb;
begin
 if not phase3.is_owner() then
  raise exception 'Owner permission required for medal entitlements' using errcode='42501';end if;
 if p_request_id is null or p_action is null or p_action not in('register','grant','revoke')
 or med_key !~ '^[a-z][a-z0-9_-]{2,39}$'
 or char_length(reason) not between 10 and 300 then
  raise exception 'Invalid medal approval request';end if;
 if p_action='register' then
  if p_target is not null or char_length(label_text) not between 3 and 60
  or char_length(description_text)>180 then
   raise exception 'Invalid new medal specification';end if;
 else
  if p_target is null or p_label is not null or p_description is not null then
    raise exception 'Invalid medal recipient payload';end if;
  if not exists(select 1 from public.medal_catalog c where c.medal_key=med_key) then
   raise exception 'Medal must be approved in catalog first';end if;
  if not exists(select 1 from auth.users u where u.id=p_target and u.deleted_at is null
    and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)
    and (u.banned_until is null or u.banned_until<now())) then
    raise exception 'Recipient must be an eligible verified account' using errcode='42501';end if;
 end if;
 payload:=jsonb_build_object('action',p_action,'key',med_key,'target',p_target,
 'label',p_label,'description',p_description,'reason',reason);
 select * into existing from phase3.medal_action_requests r
  where r.actor_id=caller and r.request_id=p_request_id;
 if found then
  if existing.payload<>payload then raise exception 'Medal idempotency conflict';end if;
  return existing.result;
 end if;
 if (select count(*) from phase3.medal_action_requests r where
  r.actor_id=caller and r.created_at>now()-interval '1 minute')>=30 then
  raise exception 'Medal action rate limit exceeded';end if;
 if p_action='register' then
  insert into public.medal_catalog(medal_key,display_name,description,created_by)
  values(med_key,label_text,description_text,caller);
 elsif p_action='grant' then
  insert into public.medal_entitlements(user_id,medal_key,granted_by)
  values(p_target,med_key,caller)
  on conflict(user_id,medal_key) do update set
   revoked_at=null,revoked_by=null,granted_at=now(),granted_by=excluded.granted_by;
 else
  update public.medal_entitlements set revoked_at=now(),revoked_by=caller
   where user_id=p_target and medal_key=med_key and revoked_at is null;
  if not found then raise exception 'Active award missing for revocation';end if;
 end if;
 answer:=jsonb_build_object('success',true,'action',p_action,'medalKey',med_key,
 'userId',p_target);
 insert into phase3.medal_action_requests(actor_id,request_id,payload,result)
 values(caller,p_request_id,payload,answer);
 insert into public.security_audit(actor_id,action,details)
 values(caller,'medal_'||p_action,
   jsonb_build_object('medalKey',med_key,'targetId',p_target,
     'requestId',p_request_id,'reason',reason));
 return answer;
end $fn$;
revoke all on function phase3.medal_owner_action(text,text,uuid,text,text,text,uuid) from public,anon;
grant execute on function phase3.medal_owner_action(text,text,uuid,text,text,text,uuid) to authenticated;

create function phase3.medal_user(p_target uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare viewer uuid:=phase3.actor(); awards jsonb;
begin
 if p_target is null or not exists(select 1 from public.profiles where id=p_target) then
  raise exception 'Recipient profile missing' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.granted_at desc,t.medal_key),'[]'::jsonb)
 into awards from(
  select m.medal_key,m.display_name,m.description,e.granted_at
   from public.medal_entitlements e
   join public.medal_catalog m on m.medal_key=e.medal_key
   where e.user_id=p_target and e.revoked_at is null
   order by e.granted_at desc,m.medal_key
   limit 100
 ) t;
 return jsonb_build_object('userId',p_target,'items',awards);
end $fn$;
revoke all on function phase3.medal_user(uuid) from public,anon;
grant execute on function phase3.medal_user(uuid) to authenticated;

create function phase3.medal_catalog_list()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare viewer uuid:=phase3.actor(); items jsonb;
begin
 select coalesce(jsonb_agg(to_jsonb(t) order by t.medal_key),'[]'::jsonb)
 into items from(select medal_key,display_name,description
  from public.medal_catalog order by medal_key limit 300) t;
 return jsonb_build_object('items',items);
end $fn$;
revoke all on function phase3.medal_catalog_list() from public,anon;
grant execute on function phase3.medal_catalog_list() to authenticated;

create function public.phase5_medal_owner_action(
 p_action text,p_medal_key text,p_target uuid default null,p_label text default null,
 p_description text default null,p_reason text default null,p_request_id uuid default null
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.medal_owner_action(p_action,p_medal_key,p_target,p_label,
   p_description,p_reason,p_request_id);
end $fn$;

create function public.phase5_medal_user(p_target uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.medal_user(p_target);
end $fn$;

create function public.phase5_medal_catalog()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.medal_catalog_list();
end $fn$;
revoke all on function public.phase5_medal_owner_action(text,text,uuid,text,text,text,uuid),
 public.phase5_medal_user(uuid),public.phase5_medal_catalog() from public,anon;
grant execute on function public.phase5_medal_owner_action(text,text,uuid,text,text,text,uuid),
 public.phase5_medal_user(uuid),public.phase5_medal_catalog() to authenticated;
comment on table public.medal_entitlements is
 'Only verified manually approved medals. No automatic level, reward, financial or VIP entitlement.';
