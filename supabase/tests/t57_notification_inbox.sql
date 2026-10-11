-- T57: isolated local Postgres contract, every fixture mutation rolled back.
begin;
do $qa$
declare own uuid:=gen_random_uuid();target uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 own_session uuid:=gen_random_uuid();target_session uuid:=gen_random_uuid();
 outsider_session uuid:=gen_random_uuid();room_id uuid;ticket uuid;
 a jsonb;records jsonb;first_notification bigint;result jsonb;denied boolean;
 request_key uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
  (own,own::text||'@test.invalid',now(),false),
  (target,target::text||'@test.invalid',now(),false),
  (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values
  (own_session,own),(target_session,target),(outsider_session,outsider);
 update phase3.system_authority set owner_id=own,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',target,'session_id',target_session,'aal','aal1')::text,true);
 if (public.phase5_notification_feed()->>'unreadCount')<>'0'
 then raise exception 'Empty inbox must not return phantom notifications';end if;
 perform public.phase5_support_action('create',jsonb_build_object(
  'category','technical','subject','Receipt needed for actual support case',
  'message','Private support text MUST remain in message table'),gen_random_uuid());
 select t.id into ticket from public.support_tickets t
  where t.creator_id=target order by t.created_at desc limit 1;
 if ticket is null then raise exception 'Support ticket missing';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',own,'session_id',own_session,'aal','aal1')::text,true);
 room_id:=public.phase2_room_create('Notification QA room',false);
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',target,'session_id',target_session,'aal','aal1')::text,true);
 perform public.phase2_room_join(room_id);
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',own,'session_id',own_session,'aal','aal1')::text,true);
 a:=public.phase5_vip_owner_action('grant',target,7,now()+interval '10 days',
  'Verified Owner approved testing entitlement',request_key);
 if public.phase5_vip_owner_action('grant',target,7,
   (a->>'expiresAt')::timestamptz,'Verified Owner approved testing entitlement',request_key)<>a
 then raise exception 'VIP retry no longer idempotent';end if;
 perform public.phase2_room_moderate(room_id,target,'mute',gen_random_uuid());
 perform public.phase5_support_action('reply',
  jsonb_build_object('ticket_id',ticket,'message','Our verified support response'),
  gen_random_uuid());
 if (select count(*) from public.user_notifications where recipient_id=target)<>3 then
  raise exception 'Expected 3 genuine notifications: VIP, moderation, support';end if;
 if (select count(*) from public.user_notifications where recipient_id=target
  and (context::text like '%Private support text%'
   or context::text like '%verified support response%'))<>0 then
    raise exception 'Ticket plaintext leaked into notification context';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',target,'session_id',target_session,'aal','aal1')::text,true);
 records:=public.phase5_notification_feed(10,null);
 if (records->>'unreadCount')<>'3' or jsonb_array_length(records->'items')<>3
  or (select count(*) from public.user_notifications
   where recipient_id=target and event_type in
   ('vip_granted','room_muted','support_staff_replied'))<>3 then
   raise exception 'Transaction-derived customer inbox incomplete';end if;
 first_notification:=(records->'items'->0->>'id')::bigint;
 result:=public.phase5_notification_mark(array[first_notification],false);
 if (result->>'updated')<>'1' then raise exception 'Specific notification was not acknowledged';end if;
 result:=public.phase5_notification_mark(array[first_notification],false);
 if (result->>'updated')<>'0' then raise exception 'Duplicate read changed state';end if;
 records:=public.phase5_notification_feed(10,first_notification);
 if jsonb_array_length(records->'items')<>2 or records->>'unreadCount'<>'2'
 then raise exception 'Cursor pagination or unread total wrong';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',outsider,'session_id',outsider_session,'aal','aal1')::text,true);
 if (public.phase5_notification_feed()->>'unreadCount')<>'0'
 then raise exception 'Outsider read another account notification';end if;
 if (public.phase5_notification_mark(array[first_notification],false)->>'updated')<>'0'
 then raise exception 'Outsider acknowledged a private notification';end if;
 if has_table_privilege('anon','public.user_notifications','SELECT')
   or has_table_privilege('authenticated','public.user_notifications','INSERT,UPDATE,DELETE')
   or has_function_privilege('anon','public.phase5_notification_mark(bigint[],boolean)','EXECUTE')
 then raise exception 'Client bypass of private inbox ACL';end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
  and schemaname='public' and tablename='user_notifications') then
  raise exception 'Notification RLS realtime source not published';end if;
 perform set_config('request.jwt.claims',jsonb_build_object(
  'sub',target,'session_id',target_session,'aal','aal1')::text,true);
 result:=public.phase5_notification_mark(array[]::bigint[],true);
 if (result->>'updated')<>'2' or
  (public.phase5_notification_feed()->>'unreadCount')<>'0' then
   raise exception 'Mark all left unread entries';end if;
end $qa$;
rollback;
select 'PASS T57: genuine VIP/moderation/support notifications, privacy, cursor, unread and idempotent acknowledgments' as result;
