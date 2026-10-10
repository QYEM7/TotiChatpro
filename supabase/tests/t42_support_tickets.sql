begin;
do $t42$
declare o uuid:=gen_random_uuid();staff uuid:=gen_random_uuid();u uuid:=gen_random_uuid();
 so uuid:=gen_random_uuid();ss uuid:=gen_random_uuid();su uuid:=gen_random_uuid();
 ticket jsonb;id uuid;denied boolean;agency_count bigint;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (o,o::text||'@test.invalid',now(),false),
 (staff,staff::text||'@test.invalid',now(),false),
 (u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(so,o),(ss,staff),(su,u);
 update phase3.system_authority set owner_id=o,main_partner_id=null where singleton;
 select count(*) into agency_count from public.agencies;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',su,'aal','aal1')::text,true);
 ticket:=public.phase5_support_create('host_agency_application','QA host agency request',
 'Opening a real QA test host agency through support',
 '{"agency_name":"QA host agency","contact":"QA contact number"}',gen_random_uuid());
 id:=(ticket->>'id')::uuid;
 if ticket->>'status'<>'submitted' then raise exception 'T42 ticket was not created';end if;
 denied:=false;
 begin perform public.phase5_support_queue();
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 ordinary user saw support queue';end if;
 denied:=false;
 begin perform public.phase5_support_review(id,'resolved','Unauthorized review');
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 applicant reviewed own agency request';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_support_assign(staff,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',staff,'session_id',ss,'aal','aal1')::text,true);
 if jsonb_array_length(public.phase5_support_queue())<>1 then raise exception 'T42 support agent queue missing';end if;
 ticket:=public.phase5_support_review(id,'in_review','Checking agency request documents');
 if ticket->>'status'<>'in_review' then raise exception 'T42 staff review failed';end if;
 if (select count(*) from public.agencies)<>agency_count then
 raise exception 'T42 reviewing support created unauthorized agency';end if;
 denied:=false;
 begin perform public.phase5_support_assign(u,true);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 agent granted own agency/role access';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_support_assign(staff,false);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',staff,'session_id',ss,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_support_queue();
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T42 revoked support agent still had queue access';end if;
end $t42$;
rollback;
select 'PASS T42: true support intake and separated staff review; no agency creation or privilege escalation' as result;
