-- TotiChat unique Owner-assigned public identity. Never replaces auth.users.id.
-- No automatic random/public IDs; must be manually approved in the admin tool.
create table public.account_special_ids(
 user_id uuid primary key references auth.users(id) on delete cascade,
 public_id text not null unique check(public_id~'^[1-9][0-9]{3,9}$'),
 granted_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 reason text not null check(char_length(reason) between 10 and 300)
);
alter table public.account_special_ids enable row level security;
revoke all on public.account_special_ids from public,anon,authenticated;

create table phase3.special_id_grant_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 target_id uuid not null references auth.users(id),
 public_id text not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_special_id_action_recent on phase3.special_id_grant_requests(actor_id,created_at desc);
alter table phase3.special_id_grant_requests enable row level security;
revoke all on phase3.special_id_grant_requests from public,anon,authenticated;

create function phase3.special_id_grant(p_target uuid,p_public_id text,
 p_reason text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor_id uuid:=phase3.actor();note text:=btrim(coalesce(p_reason,''));
 old phase3.special_id_grant_requests%rowtype;
 current_code text;result jsonb;
begin
 if not phase3.is_owner() then raise exception 'Owner approval required' using errcode='42501';end if;
 if p_target is null or p_request_id is null or
   p_public_id is null or p_public_id !~ '^[1-9][0-9]{3,9}$' or
   char_length(note) not between 10 and 300 then
   raise exception 'Invalid unique account ID approval';
 end if;
 if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id
   where u.id=p_target and u.deleted_at is null
   and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)
   and (u.banned_until is null or u.banned_until<now())) then
   raise exception 'Verified account required' using errcode='42501';
 end if;
 select * into old from phase3.special_id_grant_requests r
 where r.actor_id=actor_id and r.request_id=p_request_id;
 if found then
  if old.target_id<>p_target or old.public_id<>p_public_id then
   raise exception 'Special ID idempotency conflict';
  end if;
  return old.result;
 end if;
 if (select count(*) from phase3.special_id_grant_requests r
   where r.actor_id=actor_id and r.created_at>now()-interval '1 minute')>=20
 then raise exception 'Special ID rate limit exceeded';end if;
 select public_id into current_code from public.account_special_ids where user_id=p_target;
 if found then
  raise exception 'Public ID already assigned and cannot be changed' using errcode='23505';
 end if;
 if exists(select 1 from public.account_special_ids where public_id=p_public_id) then
  raise exception 'Public ID already reserved' using errcode='23505';
 end if;
 insert into public.account_special_ids(user_id,public_id,granted_by,reason)
 values(p_target,p_public_id,actor_id,note);
 result:=jsonb_build_object('userId',p_target,'publicId',p_public_id,'success',true);
 insert into phase3.special_id_grant_requests(actor_id,request_id,target_id,public_id,result)
 values(actor_id,p_request_id,p_target,p_public_id,result);
 insert into public.security_audit(actor_id,action,details)values(actor_id,'special_public_id_grant',
  jsonb_build_object('targetId',p_target,'publicId',p_public_id,'requestId',p_request_id));
 return result;
end $fn$;
revoke all on function phase3.special_id_grant(uuid,text,text,uuid) from public,anon;
grant execute on function phase3.special_id_grant(uuid,text,text,uuid) to authenticated;

create function phase3.special_id_status(p_target uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();code text;
begin
 if p_target is null or not exists(select 1 from public.profiles where id=p_target) then
  raise exception 'Account unavailable' using errcode='42501';end if;
 select public_id into code from public.account_special_ids where user_id=p_target;
 return jsonb_build_object('userId',p_target,'publicId',code,'assigned',code is not null);
end $fn$;
revoke all on function phase3.special_id_status(uuid) from public,anon;
grant execute on function phase3.special_id_status(uuid) to authenticated;

create function public.phase5_special_id_grant(p_target uuid,p_public_id text,
 p_reason text,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.special_id_grant(p_target,p_public_id,p_reason,p_request_id);
end $fn$;
create function public.phase5_special_id_status(p_target uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.special_id_status(p_target);
end $fn$;
revoke all on function public.phase5_special_id_grant(uuid,text,text,uuid),
 public.phase5_special_id_status(uuid) from public,anon;
grant execute on function public.phase5_special_id_grant(uuid,text,text,uuid),
 public.phase5_special_id_status(uuid) to authenticated;
comment on table public.account_special_ids is
 'One-time verified Owner-assigned 4-10 digit public identity, no automatic generation, never changes internal Auth UUID, never reassigns a committed special ID.';
