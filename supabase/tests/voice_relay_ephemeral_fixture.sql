-- Only for the disposable Postgres service launched by GitHub Actions.
-- Synthetic fixture data; NEVER run against any Supabase project.
\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create schema phase3;

create function auth.jwt() returns jsonb
language sql stable set search_path='' as $fn$
  select coalesce(nullif(pg_catalog.current_setting('request.jwt.claims',true),''),'{}')::jsonb
$fn$;

create function auth.uid() returns uuid
language sql stable set search_path='' as $fn$
  select (auth.jwt()->>'sub')::uuid
$fn$;

create table phase3.verified_sessions(
 user_id uuid not null,
 session_id uuid not null,
 primary key(user_id,session_id)
);
insert into phase3.verified_sessions(user_id,session_id) values
 ('11111111-1111-4111-8111-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('22222222-2222-4222-8222-222222222222',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

-- Mimics the real actor's verified session check and role boundaries.
create function phase3.actor() returns uuid
language plpgsql security definer set search_path='' as $fn$
declare
  u uuid := auth.uid();
  sid uuid;
begin
  if u is null or coalesce(auth.jwt()->>'session_id','') = '' then
    raise exception 'Verified actor missing' using errcode='42501';
  end if;
  sid := (auth.jwt()->>'session_id')::uuid;
  if not exists(
    select 1 from phase3.verified_sessions s
    where s.user_id=u and s.session_id=sid
  ) then
    raise exception 'Session expired' using errcode='42501';
  end if;
  if coalesce(auth.jwt()->>'aal','') not in ('aal1','aal2') then
    raise exception 'Invalid assurance level' using errcode='42501';
  end if;
  return u;
end $fn$;

create table phase3.moderation_fixture_log(
 id bigint generated always as identity primary key,
 actor_id uuid not null,
 action text not null,
 request_id uuid not null
);

create function phase3.room_moderation_action(
 p_room_id uuid, p_target uuid, p_action text,
 p_request_id uuid, p_reason text default null
) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare actor_id uuid:=phase3.actor();
begin
  -- Synthetic room has exactly one owner. Real Staging checks moderator/owner
  -- hierarchy and idempotency in the already-deployed phase3 function.
  if actor_id <> '11111111-1111-4111-8111-111111111111'::uuid then
    raise exception 'Room moderator permission required' using errcode='42501';
  end if;
  if p_room_id <> '33333333-3333-4333-8333-333333333333'::uuid
     or p_target <> '44444444-4444-4444-8444-444444444444'::uuid then
    raise exception 'Room or target not authorized' using errcode='42501';
  end if;
  insert into phase3.moderation_fixture_log(actor_id,action,request_id)
  values(actor_id,p_action,p_request_id);
  return pg_catalog.jsonb_build_object(
    'success',true,'roomId',p_room_id,'targetId',p_target,'action',p_action
  );
end $fn$;

-- Prior DB-only endpoint, replaced by the candidate migration.
create function public.phase2_room_moderate(
 p_room_id uuid,p_target uuid,p_action text,
 p_request_id uuid,p_reason text default null
) returns jsonb
language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.room_moderation_action(
   p_room_id,p_target,p_action,p_request_id,p_reason
 );
end $fn$;

grant usage on schema auth,phase3 to authenticated,service_role;
grant execute on function auth.jwt(),auth.uid() to authenticated,service_role;
grant execute on function phase3.actor() to authenticated,service_role;
grant execute on function phase3.room_moderation_action(
 uuid,uuid,text,uuid,text
) to authenticated;
grant execute on function public.phase2_room_moderate(
 uuid,uuid,text,uuid,text
) to authenticated;
