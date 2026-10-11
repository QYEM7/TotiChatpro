-- T62: notifications arise only from real approved medal audit, all rolled back.
begin;
do $medalnotice$
declare own uuid:=gen_random_uuid();receiver uuid:=gen_random_uuid();
 so uuid:=gen_random_uuid();sr uuid:=gen_random_uuid();
 key uuid:=gen_random_uuid();base_count bigint;notice jsonb;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (own,own::text||'@test.invalid',now(),false),
 (receiver,receiver::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(so,own),(sr,receiver);
 update phase3.system_authority set owner_id=own,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',receiver,'session_id',sr,'aal','aal1')::text,true);
 notice:=public.phase5_notification_feed(25,null);
 if (notice->>'unreadCount')<>'0' then
   raise exception 'Customer inbox has fake notifications';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_medal_owner_action('register','audited_medal',null,
  'Verified Contributor','Verified Owner-only award',
  'Approved test catalogue creation only',gen_random_uuid());
 select count(*) into base_count from public.user_notifications where recipient_id=receiver;
 if base_count<>0 then raise exception 'Catalog registration sent phantom notification';end if;
 perform public.phase5_medal_owner_action('grant','audited_medal',receiver,
  null,null,'Approved contributor medal to real user',key);
 perform public.phase5_medal_owner_action('grant','audited_medal',receiver,
  null,null,'Approved contributor medal to real user',key);
 if (select count(*) from public.user_notifications
  where recipient_id=receiver and event_type='medal_granted')<>1 then
  raise exception 'Verified single award should emit exactly 1 notification';end if;
 perform public.phase5_medal_owner_action('revoke','audited_medal',receiver,
  null,null,'Owner authorized removing approved medal',gen_random_uuid());
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',receiver,'session_id',sr,'aal','aal1')::text,true);
 notice:=public.phase5_notification_feed(25,null);
 if notice->>'unreadCount'<>'2' or jsonb_array_length(notice->'items')<>2
 or (select count(*) from public.user_notifications n
    where n.recipient_id=receiver and n.event_type in('medal_granted','medal_revoked')
      and n.context->>'medalKey'='audited_medal')<>2 then
  raise exception 'Verified grant + revoke notifications not published';end if;
 if has_table_privilege('authenticated','public.user_notifications','INSERT,UPDATE,DELETE')
 or has_function_privilege('anon','public.phase5_notification_feed(integer,bigint)','EXECUTE')
 then raise exception 'Notification privacy broken';end if;
end $medalnotice$;
rollback;
select 'PASS T62: only two real audited medal events, inbox owner only, idempotent award, no fake notification' as result;
