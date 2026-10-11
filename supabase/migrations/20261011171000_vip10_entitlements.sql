-- TotiChat real VIP entitlements, tiers 1..10. No fake VIPs, payments or
-- automatic pricing. Owner-only audited grants/revocations; default = no VIP.
create table public.vip_entitlements(
 user_id uuid primary key references auth.users(id) on delete cascade,
 tier smallint not null check(tier between 0 and 10),
 expires_at timestamptz,
 granted_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 constraint tc_vip_inactive_has_no_expiry check(tier<>0 or expires_at is null)
);
create index tc_vip_entitlements_expiry on public.vip_entitlements(expires_at)
 where expires_at is not null and tier>0;
alter table public.vip_entitlements enable row level security;
revoke all on public.vip_entitlements from public,anon,authenticated;

create table phase3.vip_action_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_vip_actor_recent on phase3.vip_action_requests(actor_id,created_at desc);
alter table phase3.vip_action_requests enable row level security;
revoke all on phase3.vip_action_requests from public,anon,authenticated;

create function phase3.vip_action(
 p_action text,p_target uuid,p_tier integer,p_expires_at timestamptz,
 p_reason text,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();note text:=btrim(coalesce(p_reason,''));
 payload jsonb;old phase3.vip_action_requests%rowtype;result jsonb;
begin
 if not phase3.is_owner() then
  raise exception 'Owner approval required for VIP grants'
   using errcode='42501';
 end if;
 if p_request_id is null or p_target is null
  or p_action not in('grant','revoke') or p_action is null
  or char_length(note) not between 10 and 300 then
    raise exception 'Invalid VIP approval';
 end if;
 if not exists(select 1 from auth.users where id=p_target) then
  raise exception 'VIP target not found';
 end if;
 if p_action='grant' then
  if p_tier is null or p_tier not between 1 and 10 or
    (p_expires_at is not null and p_expires_at<=now()) then
    raise exception 'VIP tier 1-10 and future expiration required';
  end if;
  if not exists(select 1 from auth.users where id=p_target
   and deleted_at is null and email_confirmed_at is not null
   and (banned_until is null or banned_until<now())) then
   raise exception 'Cannot grant VIP to an inactive or unverified account'
     using errcode='42501';
  end if;
 else
  if p_tier is distinct from 0 or p_expires_at is not null then
   raise exception 'Revocation must clear VIP and expiry';
  end if;
 end if;
 payload:=jsonb_build_object('action',p_action,'target',p_target,
  'tier',p_tier,'expiresAt',p_expires_at,'reason',note);
 select * into old from phase3.vip_action_requests r
 where r.actor_id=caller and r.request_id=p_request_id;
 if found then
  if old.payload<>payload then
   raise exception 'VIP idempotency key conflict';
  end if;
  return old.result;
 end if;
 if (select count(*) from phase3.vip_action_requests r
  where r.actor_id=caller and r.created_at>now()-interval '1 minute')>=30 then
   raise exception 'VIP action rate limit exceeded';
 end if;
 insert into public.vip_entitlements(user_id,tier,expires_at,granted_by)
 values(p_target,p_tier,p_expires_at,caller)
 on conflict(user_id) do update set
  tier=excluded.tier,expires_at=excluded.expires_at,
  granted_by=excluded.granted_by,updated_at=now();
 result:=jsonb_build_object('userId',p_target,'tier',p_tier,
   'expiresAt',p_expires_at,'action',p_action,'success',true);
 insert into phase3.vip_action_requests(actor_id,request_id,payload,result)
 values(caller,p_request_id,payload,result);
 insert into public.security_audit(actor_id,action,details)
 values(caller,'vip_'||p_action,jsonb_build_object(
  'targetId',p_target,'tier',p_tier,'expiresAt',p_expires_at,
  'requestId',p_request_id));
 return result;
end $fn$;
revoke all on function phase3.vip_action(text,uuid,integer,timestamptz,text,uuid)
 from public,anon;
grant execute on function phase3.vip_action(text,uuid,integer,timestamptz,text,uuid)
 to authenticated;

create function public.phase5_vip_owner_action(
 p_action text,p_target uuid,p_tier integer,p_expires_at timestamptz,
 p_reason text,p_request_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.vip_action(p_action,p_target,p_tier,p_expires_at,p_reason,p_request_id);
end $fn$;
revoke all on function public.phase5_vip_owner_action(text,uuid,integer,timestamptz,text,uuid)
 from public,anon;
grant execute on function public.phase5_vip_owner_action(text,uuid,integer,timestamptz,text,uuid)
 to authenticated;

create function phase3.vip_status(p_target uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor_id uuid:=phase3.actor();current_entitlement public.vip_entitlements%rowtype;
begin
 if p_target is null then raise exception 'User required';end if;
 select * into current_entitlement from public.vip_entitlements where user_id=p_target;
 if not found or current_entitlement.tier=0 or
  (current_entitlement.expires_at is not null and current_entitlement.expires_at<=now()) then
  return jsonb_build_object('userId',p_target,'tier',0,'active',false,'expiresAt',null);
 end if;
 return jsonb_build_object('userId',p_target,'tier',current_entitlement.tier,
  'active',true,'expiresAt',current_entitlement.expires_at);
end $fn$;
revoke all on function phase3.vip_status(uuid) from public,anon;
grant execute on function phase3.vip_status(uuid) to authenticated;

create function public.phase5_vip_status(p_target uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.vip_status(p_target);
end $fn$;
revoke all on function public.phase5_vip_status(uuid) from public,anon;
grant execute on function public.phase5_vip_status(uuid) to authenticated;

comment on table public.vip_entitlements is
 'Owner-audited VIP 1..10 identity entitlement, with expiry at read time. No tier or fake purchase is assigned by default. VIP prices and benefits require separate approved billing and release rules.';
