-- T66: actual committed gift creates recipient-only inbox. ROLLBACK fixtures.
begin;
do $giftinbox$
declare sender uuid:=gen_random_uuid();receiver uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 s uuid:=gen_random_uuid();r uuid:=gen_random_uuid();o uuid:=gen_random_uuid();
 room uuid:=gen_random_uuid();request_id uuid:=gen_random_uuid();
 first jsonb;second jsonb;feed jsonb;total integer;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (sender,sender::text||'@test.invalid',now(),false),
 (receiver,receiver::text||'@test.invalid',now(),false),
 (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(s,sender),(r,receiver),(o,outsider);
 insert into public.rooms(id,owner_id,title,is_private)
 values(room,sender,'T66 verified gift notification',false);
 insert into public.room_members(room_id,user_id) values(room,sender),(room,receiver);
 update public.wallets set coins=100 where user_id=sender;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',sender,'session_id',s,'aal','aal1')::text,true);
 first:=public.phase3_send_gift(room,receiver,'g1',1,request_id,10);
 second:=public.phase3_send_gift(room,receiver,'g1',1,request_id,10);
 if first<>second or first->>'status'<>'completed' then
  raise exception 'Real gift operation not committed and idempotent';end if;
 if (select count(*) from public.user_notifications n
  where n.recipient_id=receiver and n.event_type='gift_received'
    and n.context->>'giftId'='g1'
    and n.context->>'coinsAmount'='10'
    and n.context->>'senderId'=sender::text)<>1 then
  raise exception 'Exactly one recipient inbox receipt should be created';end if;
 if exists(select 1 from public.user_notifications n
   where n.recipient_id=sender and n.event_type='gift_received') then
  raise exception 'Sender got recipient gift event';end if;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',receiver,'session_id',r,'aal','aal1')::text,true);
 feed:=public.phase5_notification_feed(25,null);
 if jsonb_array_length(feed->'items')<>1 or
   feed->>'unreadCount'<>'1' or
   feed->'items'->0->>'event_type'<>'gift_received' then
  raise exception 'Recipient gift notification missing from own real feed';end if;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',outsider,'session_id',o,'aal','aal1')::text,true);
 feed:=public.phase5_notification_feed(25,null);
 if jsonb_array_length(feed->'items')<>0 or feed->>'unreadCount'<>'0' then
  raise exception 'Outsider read another users gift receipt';end if;
 if has_table_privilege('authenticated','public.user_notifications','INSERT,UPDATE,DELETE')
 then raise exception 'User could fabricate gift notification';end if;
end $giftinbox$;
rollback;
select 'PASS T66: one completed fixed gift -> exactly one private RLS inbox receipt, replay safe, no outsiders or fake sender notice' as result;
