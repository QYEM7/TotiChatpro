-- T42 extended security/UX acceptance, unlinked disposable PostgreSQL only.
begin;
do $t42p$
declare own uuid:=gen_random_uuid();member uuid:=gen_random_uuid();
       agent uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
       sid_member uuid:=gen_random_uuid();sid_owner uuid:=gen_random_uuid();
       sid_agent uuid:=gen_random_uuid();sid_out uuid:=gen_random_uuid();
       ticket uuid;answer jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
   (own,own::text||'@test.invalid',now(),false),
   (member,member::text||'@test.invalid',now(),false),
   (agent,agent::text||'@test.invalid',now(),false),
   (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values
   (sid_owner,own),(sid_member,member),(sid_agent,agent),(sid_out,outsider);
 update phase3.system_authority set owner_id=own,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',member,'session_id',sid_member,'aal','aal1')::text,true);
 ticket:=(public.phase5_support_action('create',
   '{"category":"general","subject":"Ticket paging integration","message":"Initial historic message"}',
   gen_random_uuid())->>'id')::uuid;
 insert into phase3.support_messages(ticket_id,author_id,body,created_at)
 select ticket,member,'Historical response '||i,now()+make_interval(secs=>i)
 from generate_series(1,65) as i;
 answer:=public.phase5_support_thread_page(ticket,0,30);
 if (answer->>'total')::bigint<>66 or jsonb_array_length(answer->'messages')<>30 or
    (answer->'messages')::text not like '%Historical response 65%' or
    (answer->'messages')::text like '%Initial historic message%' then
   raise exception 'T42 newest messages page is missing or includes oldest records';
 end if;
 answer:=public.phase5_support_thread_page(ticket,60,30);
 if jsonb_array_length(answer->'messages')<>6 or
    (answer->'messages')::text not like '%Initial historic message%' then
   raise exception 'T42 older message page inaccessible';
 end if;
 denied:=false;
 begin perform public.phase5_support_staff_list();
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 ordinary user accessed Owner roster';end if;
 -- An outsider must not be able to access another person's ticket.
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',outsider,'session_id',sid_out,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_support_thread_page(ticket,0,30);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 outsider can page a private ticket';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',own,'session_id',sid_owner,'aal','aal1')::text,true);
 perform public.phase5_support_action('staff_grant',jsonb_build_object('user_id',agent),gen_random_uuid());
 answer:=public.phase5_support_staff_list();
 if answer->>'total'<>'1' or answer->'rows'->0->>'user_id'<>agent::text
    or answer->'rows'->0->>'enabled'<>'true' then
   raise exception 'T42 Owner staff roster missing newly granted staff';
 end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',agent,'session_id',sid_agent,'aal','aal1')::text,true);
 answer:=public.phase5_support_thread_page(ticket,0,30);
 if jsonb_array_length(answer->'messages')<>30 then raise exception 'T42 approved staff cannot page ticket';end if;
 denied:=false;
 begin perform public.phase5_support_staff_list();
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 staff escalated to Owner roster';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',own,'session_id',sid_owner,'aal','aal1')::text,true);
 perform public.phase5_support_action('staff_revoke',jsonb_build_object('user_id',agent),gen_random_uuid());
 answer:=public.phase5_support_staff_list();
 if answer->'rows'->0->>'enabled'<>'false' then raise exception 'T42 revoked staff retained enabled roster flag';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',agent,'session_id',sid_agent,'aal','aal1')::text,true);
 denied:=false;begin perform public.phase5_support_thread_page(ticket,0,30);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 revoked staff retained ticket history access';end if;
 if has_function_privilege('anon','public.phase5_support_staff_list(integer,integer)','EXECUTE') or
    has_function_privilege('anon','public.phase5_support_thread_page(uuid,integer,integer)','EXECUTE') then
   raise exception 'T42 anonymous support listing or paging RPC exposed';
 end if;
end $t42p$;
rollback;
select 'PASS T42 paging: bounded 66 messages, Owner-only roster, revoked staff/outsider denied, rollback' as result;
