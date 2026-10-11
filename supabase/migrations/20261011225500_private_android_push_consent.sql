-- T66: private FCM registration ledger; consent is explicit, default OFF.
-- Server does NOT send notifications. Never store FCM service credentials here.
-- App version/build and third-party delivery remain disabled by Owner policy.
create table phase3.push_preferences(
  user_id uuid primary key references auth.users(id) on delete cascade,
  push_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table phase3.push_preferences enable row level security;
revoke all on phase3.push_preferences from public,anon,authenticated;

create table phase3.push_devices(
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null,
  platform text not null default 'android' check(platform='android'),
  provider text not null default 'fcm' check(provider='fcm'),
  token_value text not null check(
    char_length(token_value) between 32 and 4096 and
    token_value ~ '^[A-Za-z0-9_.:-]+$'
  ),
  token_digest bytea not null check(octet_length(token_digest)=32),
  registered_at timestamptz not null default now(),
  refreshed_at timestamptz not null default now(),
  primary key(user_id,device_id),
  unique(token_digest)
);
create index tc_push_devices_recent on phase3.push_devices(user_id,refreshed_at desc);
alter table phase3.push_devices enable row level security;
revoke all on phase3.push_devices from public,anon,authenticated;

create function phase3.push_opt_in(p_enabled boolean)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();
begin
 if p_enabled is null then raise exception 'Explicit push consent required';end if;
 insert into phase3.push_preferences(user_id,push_enabled)
 values(me,p_enabled)
 on conflict(user_id) do update set push_enabled=excluded.push_enabled,updated_at=now();
 if not p_enabled then
  -- A user opting out instantly removes all destination tokens; no silent
  -- push dispatch from stale devices on that account.
  delete from phase3.push_devices where user_id=me;
 end if;
 return jsonb_build_object('userId',me,'pushEnabled',p_enabled,
  'deliveryConfigured',false,'message','FCM delivery is not deployed');
end $fn$;
revoke all on function phase3.push_opt_in(boolean) from public,anon;
grant execute on function phase3.push_opt_in(boolean) to authenticated;

create function phase3.push_device_action(p_action text,p_device_id uuid,
 p_token text default null)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();is_opted boolean;token_hash bytea;
begin
 if p_action is null or p_action not in('register','unregister') or
    p_device_id is null then raise exception 'Invalid device operation';end if;
 if p_action='unregister' then
  if p_token is not null then raise exception 'Unregister must not send token';end if;
  delete from phase3.push_devices where user_id=me and device_id=p_device_id;
  return jsonb_build_object('userId',me,'deviceId',p_device_id,'registered',false);
 end if;
 select push_enabled into is_opted from phase3.push_preferences
   where user_id=me for update;
 if coalesce(is_opted,false) is distinct from true then
  raise exception 'Push is not enabled by the account holder' using errcode='42501';
 end if;
 if p_token is null or char_length(p_token) not between 32 and 4096 or
   p_token !~ '^[A-Za-z0-9_.:-]+$' then
  raise exception 'Invalid FCM registration token';
 end if;
 if not exists(select 1 from phase3.push_devices
   where user_id=me and device_id=p_device_id)
   and (select count(*) from phase3.push_devices where user_id=me)>=5
 then raise exception 'Maximum 5 registered devices';end if;
 token_hash:=sha256(convert_to(p_token,'UTF8'));
 -- Token possession represents one FCM installation. Re-binding atomically
 -- severs the old account's destination, preventing old-account push leaks
 -- when a shared phone signs in to a different verified account.
 perform pg_advisory_xact_lock(pg_catalog.hashtextextended(encode(token_hash,'hex'),0));
 delete from phase3.push_devices where token_digest=token_hash and user_id<>me;
 insert into phase3.push_devices(user_id,device_id,token_value,token_digest)
 values(me,p_device_id,p_token,token_hash)
 on conflict(user_id,device_id) do update
 set token_value=excluded.token_value,token_digest=excluded.token_digest,
 refreshed_at=now();
 return jsonb_build_object('userId',me,'deviceId',p_device_id,
  'registered',true,'deliveryConfigured',false);
end $fn$;
revoke all on function phase3.push_device_action(text,uuid,text) from public,anon;
grant execute on function phase3.push_device_action(text,uuid,text) to authenticated;

create function phase3.push_status()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();enabled boolean;devices jsonb;
begin
 select p.push_enabled into enabled from phase3.push_preferences p
 where p.user_id=me;
 select coalesce(jsonb_agg(to_jsonb(a) order by a.refreshed_at desc),'[]'::jsonb)
 into devices from (
  select device_id,platform,provider,registered_at,refreshed_at
  from phase3.push_devices where user_id=me
  order by refreshed_at desc,device_id limit 5
 ) a;
 return jsonb_build_object('userId',me,'pushEnabled',coalesce(enabled,false),
  'deliveryConfigured',false,'devices',devices);
end $fn$;
revoke all on function phase3.push_status() from public,anon;
grant execute on function phase3.push_status() to authenticated;

-- Public Data API exposes ONLY invoker wrappers. No token plaintext or hash
-- is returned. All internal tables remain private to the server.
create function public.phase5_push_opt_in(p_enabled boolean)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.push_opt_in(p_enabled);end $fn$;
create function public.phase5_push_device_action(
 p_action text,p_device_id uuid,p_token text default null)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();
 return phase3.push_device_action(p_action,p_device_id,p_token);end $fn$;
create function public.phase5_push_status()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.push_status();end $fn$;
revoke all on function public.phase5_push_opt_in(boolean),
 public.phase5_push_device_action(text,uuid,text),
 public.phase5_push_status() from public,anon;
grant execute on function public.phase5_push_opt_in(boolean),
 public.phase5_push_device_action(text,uuid,text),
 public.phase5_push_status() to authenticated;
comment on table phase3.push_devices is
 'Private Android FCM registration tokens: requires verified session and explicit opt-in. No client SELECT and no push sender deployed.';
