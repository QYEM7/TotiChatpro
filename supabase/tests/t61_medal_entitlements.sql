-- T61 medal backend acceptance. All fixture writes rolled back on disposable DB.
begin;
do $medals$
declare own uuid:=gen_random_uuid();customer uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 so uuid:=gen_random_uuid();sc uuid:=gen_random_uuid();sx uuid:=gen_random_uuid();
 register_key uuid:=gen_random_uuid();grant_key uuid:=gen_random_uuid();
 a jsonb;state jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (own,own::text||'@test.invalid',now(),false),
 (customer,customer::text||'@test.invalid',now(),false),
 (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(so,own),(sc,customer),(sx,outsider);
 update phase3.system_authority set owner_id=own,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',customer,'session_id',sc,'aal','aal1')::text,true);
 state:=public.phase5_medal_user(customer);
 if jsonb_array_length(state->'items')<>0 then
  raise exception 'Fresh user received phantom medals';end if;
 denied:=false;
 begin
  perform public.phase5_medal_owner_action('register','genuine_m1',null,
   'Real achievement','Owner approved definition',
   'Unauthorized fake badge registration',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Customer registered fraudulent medal';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',own,'session_id',so,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_medal_owner_action('grant','not_registered',customer,
    null,null,'Must reject unapproved award',gen_random_uuid());
 exception when others then denied:=true;end;
 if not denied then raise exception 'Unregistered medal granted';end if;
 a:=public.phase5_medal_owner_action('register','verified_medal',null,
  'Community Contributor','Manually approved merit without coins',
  'Owner authorized catalogue specification',register_key);
 if a->>'success'<>'true' then raise exception 'Catalog register returned false';end if;
 if public.phase5_medal_owner_action('register','verified_medal',null,
  'Community Contributor','Manually approved merit without coins',
  'Owner authorized catalogue specification',register_key)<>a then
   raise exception 'Catalogue idempotency replay failed';end if;
 denied:=false;
 begin
  perform public.phase5_medal_owner_action('register','verified_medal',null,
   'Different Label','Manually approved merit without coins',
   'Owner authorized catalogue specification',register_key);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Catalog idempotency conflict passed';end if;
 a:=public.phase5_medal_owner_action('grant','verified_medal',customer,
  null,null,'Owner approved earned community medal',grant_key);
 if a->>'success'<>'true' then raise exception 'Owner grant rejected';end if;
 if public.phase5_medal_owner_action('grant','verified_medal',customer,
  null,null,'Owner approved earned community medal',grant_key)<>a then
  raise exception 'Grant idempotency replay failed';end if;
 if (select count(*) from public.medal_entitlements
     where user_id=customer and revoked_at is null)<>1 then
  raise exception 'Grant did not persist as sole active medal';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',outsider,'session_id',sx,'aal','aal1')::text,true);
 state:=public.phase5_medal_user(customer);
 if jsonb_array_length(state->'items')<>1 or
   state->'items'->0->>'display_name'<>'Community Contributor' then
  raise exception 'Real approved medal invisible to profile';end if;
 denied:=false;
 begin
  perform public.phase5_medal_owner_action('revoke','verified_medal',customer,
  null,null,'Unapproved staff revoked approved medal',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Outsider revoked approved medal';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',own,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_medal_owner_action('revoke','verified_medal',customer,
  null,null,'Verified Owner approved medal revocation',gen_random_uuid());
 state:=public.phase5_medal_user(customer);
 if jsonb_array_length(state->'items')<>0 then raise exception 'Revoked badge stayed active';end if;
 if (select count(*) from public.medal_entitlements where user_id=customer)<>1 then
  raise exception 'Revocation erased immutable entitlement record';end if;
 if (select count(*) from public.security_audit
     where actor_id=own and action in('medal_register','medal_grant','medal_revoke'))<>3 then
  raise exception 'Medal audit missing or duplicated by replay';end if;
 if has_table_privilege('authenticated','public.medal_entitlements','SELECT,INSERT,UPDATE,DELETE')
  or has_table_privilege('anon','public.medal_catalog','SELECT')
  or has_function_privilege('anon','public.phase5_medal_owner_action(text,text,uuid,text,text,text,uuid)','EXECUTE')
 then raise exception 'Medal DML or anonymous escalation allowed';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in('phase5_medal_user','phase5_medal_catalog','phase5_medal_owner_action')
  and p.prosecdef) then raise exception 'Exposed SECURITY DEFINER medal RPC';end if;
end $medals$;
rollback;
select 'PASS T61: verified Owner-only badge catalogue, manual grants/revocation, idempotency, audit, zero fake awards and private entitlement RLS' as result;
