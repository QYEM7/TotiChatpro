-- Canonical Staging Phase 5 customer support acceptance on disposable Postgres.
-- This intentionally targets public.support_* and SHA-only retry payloads,
-- not the superseded phase3.support_tickets implementation.
begin;
do $check$
declare u uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 sid uuid:=gen_random_uuid(); outsider_sid uuid:=gen_random_uuid();
 req uuid:=gen_random_uuid();ticket uuid; first_answer jsonb;payload jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(u,u::text||'@test.invalid',now(),false),
       (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,u),(outsider_sid,outsider);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 first_answer:=public.phase5_support_action('create',jsonb_build_object(
  'category','technical','subject','Canonical Phase Five','message','Private words in a real ticket'),req);
 ticket:=(first_answer->>'id')::uuid;
 if ticket is null or (select count(*) from public.support_tickets where id=ticket)<>1
  or (select count(*) from public.support_messages where ticket_id=ticket)<>1
 then raise exception 'Canonical ticket did not persist exactly once';end if;
 select r.payload into payload from phase3.support_requests r where actor_id=u and request_id=req;
 if length(payload->>'sha256')<>64 or payload?'data' or payload::text like '%Private words%' then
  raise exception 'Support retry log leaked private message content';end if;
 if public.phase5_support_action('create',jsonb_build_object(
  'category','technical','subject','Canonical Phase Five','message','Private words in a real ticket'),req)<>first_answer
 then raise exception 'Idempotency replay returned a different ticket';end if;
 denied:=false;
 begin perform public.phase5_support_action('create',jsonb_build_object(
 'category','technical','subject','Changed message','message','Must reject changed retry'),req);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Changed retry accepted';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'session_id',outsider_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_support_thread_page(ticket,0,20);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Outsider read private support ticket';end if;
 denied:=false;
 begin perform public.phase5_support_action('staff_grant',
   jsonb_build_object('user_id',outsider),gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Customer escalated support permissions';end if;
end $check$;
rollback;
select 'PASS: canonical Phase 5 support saves real message once, SHA retry ledger, denied outsider and escalation' as result;
