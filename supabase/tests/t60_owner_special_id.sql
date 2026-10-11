-- Disposable-only Owner-issued public ID assertions; transaction rolls back.
begin;
do $qa$
declare owner_uuid uuid:=gen_random_uuid();user_uuid uuid:=gen_random_uuid();
 another_uuid uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();
 id_request uuid:=gen_random_uuid();reply jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(owner_uuid,owner_uuid::text||'@test.invalid',now(),false),
 (user_uuid,user_uuid::text||'@test.invalid',now(),false),
 (another_uuid,another_uuid::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id)values(sid,owner_uuid);
 update phase3.system_authority set owner_id=owner_uuid,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_uuid,
  'session_id',sid,'aal','aal1')::text,true);
 if public.phase5_special_id_status(user_uuid)->>'assigned'<>'false'
 then raise exception 'Fake public ID before approval';end if;
 reply:=public.phase5_special_id_grant(user_uuid,'7654321',
  'Owner reviewed identity assignment',id_request);
 if reply->>'publicId'<>'7654321' or reply->>'success'<>'true'
 then raise exception 'Real special ID failed';end if;
 if public.phase5_special_id_grant(user_uuid,'7654321',
  'Owner reviewed identity assignment',id_request)<>reply
 then raise exception 'Same request changed result';end if;
 denied:=false;
 begin perform public.phase5_special_id_grant(another_uuid,'7654321',
  'Owner attempted conflicting public ID',gen_random_uuid());
 exception when unique_violation then denied:=true;end;
 if not denied then raise exception 'Duplicate ID accepted';end if;
 denied:=false;
 begin perform public.phase5_special_id_grant(user_uuid,'7654322',
  'Owner attempted rewriting public ID',gen_random_uuid());
 exception when unique_violation then denied:=true;end;
 if not denied then raise exception 'Immutable ID was changed';end if;
 if (select count(*) from public.security_audit
    where actor_id=owner_uuid and action='special_public_id_grant')<>1 then
   raise exception 'Missing exactly once audit';end if;
 if has_table_privilege('authenticated','public.account_special_ids','INSERT,UPDATE,DELETE')
 or has_function_privilege('anon',
 'public.phase5_special_id_grant(uuid,text,text,uuid)','EXECUTE')
 then raise exception 'Exposed public ID mutation privilege';end if;
end $qa$;
rollback;
select 'PASS T60: unique audited Owner-assigned special ID is immutable with replay safety' as result;
