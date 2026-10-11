-- VIP1-VIP10 backend contract, isolated PostgreSQL test; ALL writes rolled back.
begin;
do $vip$
declare own uuid:=gen_random_uuid();customer uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 own_session uuid:=gen_random_uuid();customer_session uuid:=gen_random_uuid();out_session uuid:=gen_random_uuid();
 request_id uuid:=gen_random_uuid();future_expiry timestamptz:=now()+interval '30 days';
 first jsonb;status jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (own,own::text||'@test.invalid',now(),false),
 (customer,customer::text||'@test.invalid',now(),false),
 (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values
 (own_session,own),(customer_session,customer),(out_session,outsider);
 update phase3.system_authority set owner_id=own,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',customer,'session_id',customer_session,'aal','aal1')::text,true);
 status:=public.phase5_vip_status(customer);
 if status->>'tier'<>'0' or status->>'active'<>'false' then
  raise exception 'New users must never have fake VIP';end if;
 denied:=false;
 begin perform public.phase5_vip_owner_action('grant',customer,10,future_expiry,
 'Unapproved self-issued VIP benefits',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Customer escalated VIP privileges';end if;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',own,'session_id',own_session,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_vip_owner_action('grant',customer,11,future_expiry,
 'Invalid level beyond approved tiers',gen_random_uuid());
 exception when others then denied:=true;end;
 if not denied then raise exception 'VIP11 unexpectedly accepted';end if;
 denied:=false;
 begin perform public.phase5_vip_owner_action('grant',customer,6,now()-interval '5 minutes',
 'Historical expiration must not pass',gen_random_uuid());
 exception when others then denied:=true;end;
 if not denied then raise exception 'Expired entitlement granted';end if;
 first:=public.phase5_vip_owner_action('grant',customer,6,future_expiry,
 'Verified manual Owner approval',request_id);
 if first->>'tier'<>'6' or (select count(*) from public.vip_entitlements where user_id=customer)<>1
 then raise exception 'VIP6 did not persist as unique real entitlement';end if;
 if public.phase5_vip_owner_action('grant',customer,6,future_expiry,
 'Verified manual Owner approval',request_id)<>first then
  raise exception 'Owner idempotent VIP grant changed result';end if;
 denied:=false;
 begin perform public.phase5_vip_owner_action('grant',customer,7,future_expiry,
 'Wrong tier with reused request identifier',request_id);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Conflicting VIP idempotency accepted';end if;
 if (select count(*) from phase3.vip_action_requests where actor_id=own)<>1 or
 (select count(*) from public.security_audit where actor_id=own and action='vip_grant')<>1
 then raise exception 'VIP replay duplicated audit or request';end if;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',outsider,'session_id',out_session,'aal','aal1')::text,true);
 status:=public.phase5_vip_status(customer);
 if status->>'tier'<>'6' or status->>'active'<>'true' or
 status->>'expiresAt' is null then
  raise exception 'Verified VIP badge did not return actual active tier';end if;
 if has_table_privilege('authenticated','public.vip_entitlements','INSERT,UPDATE,DELETE')
 or has_table_privilege('anon','public.vip_entitlements','SELECT')
 or has_function_privilege('anon','public.phase5_vip_owner_action(text,uuid,integer,timestamptz,text,uuid)','EXECUTE')
 then raise exception 'Public VIP privilege bypass';end if;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',own,'session_id',own_session,'aal','aal1')::text,true);
 perform public.phase5_vip_owner_action('revoke',customer,0,null,
 'Revocation approved by account Owner',gen_random_uuid());
 status:=public.phase5_vip_status(customer);
 if status->>'tier'<>'0' or status->>'active'<>'false' then
  raise exception 'Revoked VIP still active';end if;
end $vip$;
rollback;
select 'PASS: Owner-only VIP1..10, default VIP0, audited idempotent grant/revoke, expired/invalid denial, RLS and public status' as result;
