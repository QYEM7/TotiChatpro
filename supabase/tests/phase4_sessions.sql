begin;
do $$
declare u uuid:=gen_random_uuid();s uuid:=gen_random_uuid();denied boolean;before_count bigint;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(s,u);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',s,'aal','aal1')::text,true);
 select count(*) into before_count from public.security_audit where actor_id=u;
 if public.phase4_verified_session()<>u then raise exception 'Wrong session identity';end if;
 perform public.phase4_verified_session();
 if (select count(*) from public.security_audit where actor_id=u)<>before_count+1 then raise exception 'Session audit duplicated';end if;
 update auth.users set banned_until=now()+interval '1 hour' where id=u;
 denied:=false;begin perform public.phase4_verified_session();exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Banned account accepted';end if;
 update auth.users set banned_until=null,deleted_at=now() where id=u;
 denied:=false;begin perform public.phase4_verified_session();exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Deleted account accepted';end if;
 update auth.users set deleted_at=null where id=u;delete from auth.sessions where id=s;
 denied:=false;begin perform public.phase4_verified_session();exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Revoked session accepted';end if;
end $$;
rollback;
select 'PASS: verified session identity, audit once, ban/delete/revocation enforcement; fixtures rolled back' as result;
