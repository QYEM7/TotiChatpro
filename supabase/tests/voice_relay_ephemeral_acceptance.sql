-- Integration tests for a disposable GitHub Actions Postgres database.
-- Must NEVER be run against Staging or production.
\set ON_ERROR_STOP on

do $test$
begin
 if has_function_privilege(
   'authenticated',
   'phase3.room_moderation_action(uuid,uuid,text,uuid,text)','EXECUTE'
 ) then raise exception 'AUTHENTICATED_CAN_CALL_PRIVATE_MODERATION';end if;
 if has_function_privilege(
   'authenticated',
   'public.phase2_room_moderate_voice_relay(jsonb,uuid,uuid,text,uuid,text)',
   'EXECUTE'
 ) then raise exception 'AUTHENTICATED_CAN_CALL_RELAY';end if;
 if has_function_privilege(
   'anon',
   'public.phase2_room_moderate_voice_relay(jsonb,uuid,uuid,text,uuid,text)',
   'EXECUTE'
 ) then raise exception 'ANON_CAN_CALL_RELAY';end if;
 if not has_function_privilege(
   'service_role',
   'public.phase2_room_moderate_voice_relay(jsonb,uuid,uuid,text,uuid,text)',
   'EXECUTE'
 ) then raise exception 'SERVICE_ROLE_MISSING_RELAY_PERMISSION';end if;
 if not has_function_privilege(
   'authenticated',
   'public.phase2_room_moderate(uuid,uuid,text,uuid,text)','EXECUTE'
 ) then raise exception 'BENIGN_PUBLIC_RPC_REVOKED';end if;
end $test$;

-- No service-role claims can be accepted from an ordinary authenticated
-- database user. The SQL role and JWT are both restricted by the API.
set role authenticated;
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aal":"aal1"}',
 false);

do $test$
declare
 denied boolean;
 op text;
begin
 foreach op in array array['mute','kick','ban','release_seat'] loop
  denied:=false;
  begin
   perform public.phase2_room_moderate(
    '33333333-3333-4333-8333-333333333333'::uuid,
    '44444444-4444-4444-8444-444444444444'::uuid,
    op,'55555555-5555-4555-8555-555555555555'::uuid
   );
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'DB_ONLY_VOICE_BYPASS_%',op;end if;
 end loop;
 -- Restriction removal remains possible, though the user still has to
 -- explicitly publish their own microphone with a fresh voice token.
 if (
  public.phase2_room_moderate(
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'allow_mic','66666666-6666-4666-8666-666666666666'::uuid
  )->>'success'
 ) is distinct from 'true' then
  raise exception 'BENIGN_PERMISSION_ACTION_BROKEN';
 end if;
 denied:=false;
 begin
  perform phase3.room_moderation_action(
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'mute','77777777-7777-4777-8777-777777777777'::uuid
  );
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'PRIVATE_MODERATION_BYPASS';end if;
 denied:=false;
 begin
  perform public.phase2_room_moderate_voice_relay(
   '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aal":"aal1"}'::jsonb,
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'mute','88888888-8888-4888-8888-888888888888'::uuid
  );
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'USER_CAN_CALL_SERVICE_RELAY';end if;
end $test$;

-- A different authenticated account without room moderator permission
-- cannot perform even a benign permission action.
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"22222222-2222-4222-8222-222222222222","session_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","aal":"aal1"}',
 false);

do $test$
declare denied boolean:=false;
begin
 begin
  perform public.phase2_room_moderate(
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'allow_mic','99999999-9999-4999-8999-999999999999'::uuid
  );
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'NON_MODERATOR_ALLOWED';end if;
end $test$;
reset role;

set role service_role;
select pg_catalog.set_config('request.jwt.claims','{"role":"service_role"}',false);

-- Server role can perform a voice action with validated user/session claims.
do $test$
declare v jsonb;
begin
 v := public.phase2_room_moderate_voice_relay(
   '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","aal":"aal1"}'::jsonb,
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'mute','bbbbbbbb-1111-4111-8111-111111111111'::uuid
 );
 if v->>'success' is distinct from 'true' or
    v->>'action' is distinct from 'mute' then
  raise exception 'TRUSTED_RELAY_ACTION_FAILED';
 end if;
end $test$;

-- Trusted Edge cannot turn a stale/forged session into a valid moderation
-- action even though its DB connection is privileged.
do $test$
declare denied boolean:=false;
begin
 begin
  perform public.phase2_room_moderate_voice_relay(
   '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","aal":"aal1"}'::jsonb,
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'kick','bbbbbbbb-2222-4222-8222-222222222222'::uuid
  );
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'FORGED_SESSION_ACCEPTED';end if;
end $test$;

-- A legitimate session belonging to a non-moderator is still denied.
do $test$
declare denied boolean:=false;
begin
 begin
  perform public.phase2_room_moderate_voice_relay(
   '{"role":"authenticated","sub":"22222222-2222-4222-8222-222222222222","session_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","aal":"aal1"}'::jsonb,
   '33333333-3333-4333-8333-333333333333'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   'kick','bbbbbbbb-3333-4333-8333-333333333333'::uuid
  );
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'NON_MODERATOR_SERVICE_RELAY_BYPASS';end if;
end $test$;
reset role;

do $test$
declare n int;
begin
 select count(*) into n from phase3.moderation_fixture_log;
 if n<>2 then
  raise exception 'UNEXPECTED_COMMITTED_ACTIONS_%',n;
 end if;
end $test$;

select 'PASS: disposable Postgres role grants, voice deny, owner checks and server relay' as result;
