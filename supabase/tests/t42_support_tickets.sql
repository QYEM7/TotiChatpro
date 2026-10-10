-- T42: disposable local PostgreSQL test only; rollback all fixture writes.
begin;
do $t42$
declare o uuid:=gen_random_uuid();partner uuid:=gen_random_uuid();
 agent uuid:=gen_random_uuid();u uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 sid uuid;ticket uuid;key uuid:=gen_random_uuid();outcome jsonb;denied boolean;
 old_count bigint;new_count bigint;
begin
 foreach sid in array array[o,partner,agent,u,outsider] loop
   insert into auth.users(id,email,email_confirmed_at,is_anonymous)
   values(sid,sid::text||'@test.invalid',now(),false);
   insert into auth.sessions(id,user_id) values(gen_random_uuid(),sid);
 end loop;
 update phase3.system_authority set owner_id=o,main_partner_id=partner where singleton;
 select id into sid from auth.sessions where user_id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 outcome:=public.phase5_support_action('create',
  '{"category":"host_transfer","subject":"Agency transfer dispute","message":"Please review my transfer request"}',key);
 ticket:=(outcome->>'id')::uuid;
 if public.phase5_support_action('create',
  '{"category":"host_transfer","subject":"Agency transfer dispute","message":"Please review my transfer request"}',key)<>outcome
 then raise exception 'T42 idempotency replay changed result';end if;
 if (select count(*) from phase3.support_tickets where id=ticket)<>1 or
    (select count(*) from phase3.support_messages where ticket_id=ticket)<>1
 then raise exception 'T42 replay duplicated records';end if;
 denied:=false;
 begin perform public.phase5_support_action('create',
   '{"category":"general","subject":"different subject","message":"Different message"}',key);
 exception when others then denied:=true;end;
 if not denied then raise exception 'T42 reused idempotency key accepted changed payload';end if;
 if jsonb_array_length(public.phase5_support_list()->'rows')<>1 then raise exception 'T42 customer list missing ticket';end if;
 denied:=false;
 begin perform public.phase5_support_list('all');
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 ordinary user viewed all tickets';end if;
 select id into sid from auth.sessions where user_id=outsider;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'session_id',sid,'aal','aal1')::text,true);
 if jsonb_array_length(public.phase5_support_list()->'rows')<>0 then raise exception 'T42 other user tickets leaked';end if;
 denied:=false;
 begin perform public.phase5_support_thread(ticket);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 outsider read ticket thread';end if;
 denied:=false;
 begin perform public.phase5_support_action('reply',jsonb_build_object('ticket_id',ticket,'message','unauthorized'),gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 outsider added reply';end if;
 select id into sid from auth.sessions where user_id=agent;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',agent,'session_id',sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_support_action('staff_grant',jsonb_build_object('user_id',agent),gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 staff self-escalated';end if;
 select id into sid from auth.sessions where user_id=o;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',o,'session_id',sid,'aal','aal1')::text,true);
 perform public.phase5_support_action('staff_grant',jsonb_build_object('user_id',agent),gen_random_uuid());
 select id into sid from auth.sessions where user_id=agent;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',agent,'session_id',sid,'aal','aal1')::text,true);
 if (public.phase5_support_list('all')->>'canHandle')<>'true'
 then raise exception 'T42 granted agent cannot read ticket queue';end if;
 perform public.phase5_support_action('reply',jsonb_build_object('ticket_id',ticket,'message','Reviewing the report'),gen_random_uuid());
 if (public.phase5_support_thread(ticket)->'ticket'->>'status')<>'waiting_user'
 then raise exception 'T42 staff response did not update ticket';end if;
 perform public.phase5_support_action('status',jsonb_build_object('ticket_id',ticket,'status','resolved'),gen_random_uuid());
 select id into sid from auth.sessions where user_id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 perform public.phase5_support_action('reply',jsonb_build_object('ticket_id',ticket,'message','Issue is still pending'),gen_random_uuid());
 if (public.phase5_support_thread(ticket)->'ticket'->>'status')<>'open'
 then raise exception 'T42 customer reply did not reopen resolved ticket';end if;
 select id into sid from auth.sessions where user_id=partner;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',partner,'session_id',sid,'aal','aal1')::text,true);
 if (public.phase5_support_list('all')->>'canHandle')<>'true'
 then raise exception 'T42 designated main partner cannot handle support';end if;
 denied:=false;
 begin perform public.phase5_support_action('staff_grant',jsonb_build_object('user_id',outsider),gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 partner inherited Owner staff-grant right';end if;
 perform public.phase5_support_action('status',jsonb_build_object('ticket_id',ticket,'status','closed'),gen_random_uuid());
 select id into sid from auth.sessions where user_id=o;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',o,'session_id',sid,'aal','aal1')::text,true);
 perform public.phase5_support_action('staff_revoke',jsonb_build_object('user_id',agent),gen_random_uuid());
 select id into sid from auth.sessions where user_id=agent;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',agent,'session_id',sid,'aal','aal1')::text,true);
 denied:=false;begin perform public.phase5_support_list('all');
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 revoked agent still has queue access';end if;
 if (select count(*) from public.security_audit where action='support_reply'
 and details->>'id'=ticket::text)<2 then raise exception 'T42 support event audit missing';end if;
 if exists(select 1 from public.security_audit where action like 'support_%'
 and details ? 'message') then raise exception 'T42 private ticket message leaked into public audit';end if;
 if has_table_privilege('authenticated','phase3.support_tickets','SELECT')
 or has_table_privilege('anon','phase3.support_messages','SELECT')
 or has_function_privilege('anon','public.phase5_support_list(text,integer,integer)','EXECUTE')
 then raise exception 'T42 unrestricted table or anonymous RPC access';end if;
end $t42$;
rollback;
select 'PASS T42: real ticket CRUD with RLS boundary, staff delegation, role separation, retry idempotency, audit redaction and rollback' as result;
