begin;
do $$
declare o uuid:=gen_random_uuid();u uuid:=gen_random_uuid();s uuid:=gen_random_uuid();t uuid:=gen_random_uuid();r jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(o,o::text||'@test.invalid',now(),false),(u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(s,o),(t,u);
 update phase3.system_authority set owner_id=o,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',t,'aal','aal1')::text,true);
 denied:=false;begin perform public.phase4_admin_report(now()-interval '1 day',now()+interval '1 day');exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Unauthorized report access';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',o,'session_id',s,'aal','aal1')::text,true);
 r:=public.phase4_admin_report(now()-interval '1 day',now()+interval '1 day');
 if (r->'summary'->>'users')::bigint<>(select count(*) from auth.users where deleted_at is null) then raise exception 'Report user count';end if;
 if (r->'summary'->>'coins')::numeric<>(select coalesce(sum(coins),0) from public.wallets) then raise exception 'Report coin sum';end if;
 perform public.phase3_manage_access(u,'admin',array['reports.read'],false);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',t,'aal','aal1')::text,true);
 perform public.phase4_admin_report(now()-interval '1 day',now()+interval '1 day','completed',0,10);
 denied:=false;begin perform public.phase4_admin_report(now(),now()-interval '1 day');exception when others then denied:=true;end;if not denied then raise exception 'Reversed range accepted';end if;
 denied:=false;begin perform public.phase4_admin_report(now()-interval '2 years',now());exception when others then denied:=true;end;if not denied then raise exception 'Unbounded report accepted';end if;
 denied:=false;begin perform public.phase3_catalog_list('gift_catalog');exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Reports permission escalated';end if;
end $$;
rollback;
select 'PASS: reports use SQL counts/sums, require explicit permission and bounded filters; fixtures rolled back' as result;
