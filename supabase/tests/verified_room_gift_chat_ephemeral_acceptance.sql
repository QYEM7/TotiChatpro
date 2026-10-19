-- Executed ONLY in the disposable PostgreSQL database started by CI.
\set ON_ERROR_STOP on

-- A gift insert can precede ledger inserts inside one transaction.
-- The deferred trigger must see the FINAL settlement before displaying it.
begin;
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values (
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 'rose',7,700
);
insert into public.wallet_ledger(transaction_id,user_id,kind,currency,amount_change)
values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-700),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',700);
commit;

do $test$
declare c integer; txt text;
begin
 select count(*), max(body) into c,txt
 from public.room_messages where event_kind='gift';
 if c<>1 or txt not like '%Sender → Recipient: Rose × 7' then
  raise exception 'SETTLED_GIFT_CHAT_MISSING_OR_INVALID: % %',c,txt;
 end if;
end $test$;

-- Missing ledger evidence suppresses the announcement.
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values (
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 'rose',1,100
);

-- A sender debit without a recipient credit is still unverified.
begin;
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values (
 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 'rose',1,100
);
insert into public.wallet_ledger(transaction_id,user_id,kind,currency,amount_change)
values (
 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
 '11111111-1111-4111-8111-111111111111',
 'gift_sent','coins',-100
);
commit;

-- An operation marked failed never emits a gift notice even with ledger rows.
begin;
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values (
 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 'rose',1,100
);
insert into public.wallet_ledger(transaction_id,user_id,kind,currency,amount_change)
values
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-100),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',100);
commit;

-- An idempotent replay cannot produce an additional chat event.
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values (
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 'rose',7,700
) on conflict(id) do nothing;

-- Normal user-generated chat remains normal chat for legacy compatibility.
insert into public.room_messages(room_id,sender_id,body) values (
 '33333333-3333-4333-8333-333333333333',
 '11111111-1111-4111-8111-111111111111',
 'Ordinary message'
);

do $test$
declare gift_count int; normal_count int; leaked_count int;
begin
 select count(*) into gift_count
 from public.room_messages where event_kind='gift';
 select count(*) into normal_count
 from public.room_messages where event_kind='chat' and gift_event_id is null;
 select count(*) into leaked_count from public.room_messages
 where gift_event_id in (
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
 );
 if gift_count<>1 or normal_count<>1 or leaked_count<>0 then
  raise exception 'UNVERIFIED_OR_DUPLICATED_MESSAGE_%_%_%',
   gift_count,normal_count,leaked_count;
 end if;
 if has_table_privilege('authenticated','public.room_messages','INSERT') then
  raise exception 'AUTHENTICATED_CAN_FAKE_GIFT_CHAT';end if;
 if has_function_privilege(
   'authenticated','phase3.announce_verified_room_gift()','EXECUTE'
 ) then raise exception 'AUTHENTICATED_CAN_CALL_GIFT_TRIGGER';end if;
end $test$;

-- Database constraints do not allow forged gift messages without a real
-- finance event even from accidental server-side scripts.
do $test$
declare denied boolean:=false;
begin
 begin
  insert into public.room_messages(room_id,sender_id,body,event_kind)
  values (
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'forged','gift'
  );
 exception when check_violation then denied:=true;
 end;
 if not denied then raise exception 'GIFT_ORIGIN_CONSTRAINT_BYPASS';end if;
end $test$;

select 'PASS: room gift event verified by both ledgers, one chat per settled gift' as result;
