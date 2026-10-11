-- Disposable-only T66 consent acceptance. No real credentials or push delivery.
begin;
do $test$
declare
 qa_user uuid:=gen_random_uuid();
 qa_session uuid:=gen_random_uuid();
 qa_device uuid:=gen_random_uuid();
 response jsonb;
 rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(qa_user,qa_user::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(qa_session,qa_user);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',qa_user,'session_id',qa_session,'aal','aal1')::text,true);

 response:=public.phase5_push_status();
 if response->>'pushEnabled'<>'false' or
    jsonb_array_length(response->'devices')<>0 then
  raise exception 'Notifications must default to off';end if;

 rejected:=false;
 begin
  perform public.phase5_push_device_action('register',qa_device,repeat('Z',64));
 exception when insufficient_privilege then rejected:=true;end;
 if not rejected then raise exception 'Device registration without consent';end if;

 perform public.phase5_push_opt_in(true);
 response:=public.phase5_push_device_action('register',qa_device,repeat('Z',64));
 if response->>'registered'<>'true' or
    response::text like '%ZZZZZZ%' then
  raise exception 'Registration failed or returned sensitive device data';end if;

 response:=public.phase5_push_status();
 if jsonb_array_length(response->'devices')<>1
    or response::text like '%ZZZZZZ%' then
  raise exception 'Device status is wrong or exposed device data';end if;

 perform public.phase5_push_opt_in(false);
 response:=public.phase5_push_status();
 if response->>'pushEnabled'<>'false' or
   jsonb_array_length(response->'devices')<>0 then
  raise exception 'Opt-out left a notification destination';end if;

 if has_table_privilege('authenticated','phase3.push_devices','SELECT,INSERT,UPDATE,DELETE')
 or has_function_privilege('anon','public.phase5_push_status()','EXECUTE') then
  raise exception 'Private device data could be accessed directly';end if;
end $test$;
rollback;
select 'PASS T66: private account push opt-in, default off, device consent, no plaintext in responses, opt-out deletion' result;
