-- T06/T42: ephemeral PostgreSQL-only, all fixture writes rolled back.
begin;
do $qa$
declare u uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();
   key_create uuid:=gen_random_uuid();ticket uuid;key_first_reply uuid:=gen_random_uuid();
   i integer;replay jsonb;denied boolean;counter bigint;raw jsonb;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,u);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 replay:=public.phase5_support_action('create',
  '{"category":"technical","subject":"Test private rate limit","message":"Private content must not be copied into retry ledger"}',key_create);
 ticket:=(replay->>'id')::uuid;
 select payload into raw from phase3.support_requests where actor_id=u and request_id=key_create;
 if jsonb_typeof(raw)<>'object'
   or length(raw->>'sha256')<>64
   or raw::text like '%Private content%'
   or raw ? 'data' or raw ? 'message' then
    raise exception 'T06 support retry ledger leaked original ticket text';
 end if;
 if public.phase5_support_action('create',
  '{"category":"technical","subject":"Test private rate limit","message":"Private content must not be copied into retry ledger"}',key_create)<>replay
 then raise exception 'T06 retry did not return same ticket';end if;
 denied:=false;
 begin perform public.phase5_support_action('create',
  '{"category":"general","subject":"Changed retry payload","message":"This payload should be denied"}',key_create);
 exception when others then
  if sqlerrm like '%Idempotency key conflict%' then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'T06 changed retry message accepted';end if;
 for i in 1..19 loop
   perform public.phase5_support_action('reply',
      jsonb_build_object('ticket_id',ticket,'message','Private follow-up #'||i),
      case when i=1 then key_first_reply else gen_random_uuid() end);
 end loop;
 select count(*) into counter from phase3.support_requests where actor_id=u;
 if counter<>20 then raise exception 'T06 expected exactly 20 stored requests, got %',counter;end if;
 denied:=false;
 begin
  perform public.phase5_support_action('reply',
   jsonb_build_object('ticket_id',ticket,'message','Over-limit reply'),
   gen_random_uuid());
 exception when others then
  if sqlerrm like '%Support rate limit exceeded%' then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'T06 21st support mutation bypassed limit';end if;
 replay:=public.phase5_support_action('reply',
   jsonb_build_object('ticket_id',ticket,'message','Private follow-up #1'),key_first_reply);
 if replay->>'id'<>ticket::text then raise exception 'T06 replay past rate limit failed';end if;
 if (select count(*) from phase3.support_messages where ticket_id=ticket)<>20
    or (select count(*) from phase3.support_requests where actor_id=u)<>20 then
   raise exception 'T06 rejected/replayed request created extra messages';
 end if;
 if exists(select 1 from phase3.support_requests where actor_id=u
   and (payload ? 'data' or payload::text like '%Private%')) then
   raise exception 'T06 raw private user content duplicated inside retry ledger';
 end if;
end $qa$;
rollback;
select 'PASS T06/T42: real session, SHA-256 retry ledger redaction, 20/min, 21st denied, same-key replay and rollback' as result;
