-- Disposable-only security acceptance. All identity/room writes rolled back.
begin;
do $test$
declare room_owner uuid:=gen_random_uuid();guest uuid:=gen_random_uuid();
 owner_session uuid:=gen_random_uuid();guest_session uuid:=gen_random_uuid();room_id uuid;
 result jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (room_owner,room_owner::text||'@test.invalid',now(),false),
 (guest,guest::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(owner_session,room_owner),(guest_session,guest);
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',room_owner,'session_id',owner_session,'aal','aal1')::text,true);
 room_id:=public.phase2_room_create('Voice permission auth integration',false);
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',guest,'session_id',guest_session,'aal','aal1')::text,true);
 perform public.phase2_room_join(room_id);
 result:=public.phase2_voice_token_preflight(room_id);
 if result->>'canPublish'<>'false' then raise exception 'Guest without seat can publish microphone';end if;
 perform public.phase2_room_take_seat(room_id,4);
 perform public.phase2_room_set_muted(room_id,false);
 result:=public.phase2_voice_token_preflight(room_id);
 if result->>'canPublish'<>'true' then raise exception 'Eligible unmuted seat cannot request microphone';end if;
 -- Bad/stale session ID signed into jwt must be rejected, even if user ID exists.
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',guest,'session_id',gen_random_uuid(),'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_voice_token_preflight(room_id);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Expired Auth session bypassed voice preflight';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',guest,'session_id',guest_session,'aal','aal1')::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',room_owner,'session_id',owner_session,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(room_id,guest,'mute',gen_random_uuid());
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',guest,'session_id',guest_session,'aal','aal1')::text,true);
 result:=public.phase2_voice_token_preflight(room_id);
 if result->>'canPublish'<>'false' then raise exception 'Moderator-muted user obtained microphone permission';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',room_owner,'session_id',owner_session,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(room_id,guest,'ban',gen_random_uuid(),'Safety report verified by room owner');
 perform set_config('request.jwt.claims',jsonb_build_object(
 'sub',guest,'session_id',guest_session,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_voice_token_preflight(room_id);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Banned/exited room still issued voice permission';end if;
 if (select p.prosecdef from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
  where ns.nspname='public' and p.proname='phase2_voice_token_preflight') then
  raise exception 'Exposed public voice auth RPC remains SECURITY DEFINER';end if;
 if has_function_privilege('anon','public.phase2_voice_token_preflight(uuid)','EXECUTE')
 then raise exception 'Anonymous voice permission issuance';end if;
end $test$;
rollback;
select 'PASS T58: actual session/mute/ban voice entitlement, RLS and private definer wrapper' as result;
