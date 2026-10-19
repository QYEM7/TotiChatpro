-- Adds private-session and real-gift setup to the disposable gift fixture.
-- NEVER execute in Supabase Staging or production.
\set ON_ERROR_STOP on
create function auth.jwt() returns jsonb language sql stable set search_path='' as $fn$
 select coalesce(nullif(pg_catalog.current_setting('request.jwt.claims',true),''),'{}')::jsonb
$fn$;

create function auth.uid() returns uuid language sql stable set search_path='' as $fn$
 select (auth.jwt()->>'sub')::uuid
$fn$;

insert into auth.users(id) values ('55555555-5555-4555-8555-555555555555');
create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id));
insert into auth.sessions(id,user_id) values
 ('11111111-aaaa-4aaa-8aaa-111111111111','11111111-1111-4111-8111-111111111111'),
 ('22222222-bbbb-4bbb-8bbb-222222222222','22222222-2222-4222-8222-222222222222'),
 ('55555555-cccc-4ccc-8ccc-555555555555','55555555-5555-4555-8555-555555555555');

-- The fixture mimics phase3.actor() session checks; full real MFA/session
-- rules in Staging must still be tested independently.
create function phase3.actor() returns uuid language plpgsql
security definer set search_path='' as $fn$
declare u uuid:=auth.uid();
begin
 if coalesce(auth.jwt()->>'role','')<>'authenticated'
    or u is null
    or not exists(
      select 1 from auth.sessions s where s.user_id=u
        and s.id=(auth.jwt()->>'session_id')::uuid
    ) then raise exception 'Verified session required' using errcode='42501';end if;
 return u;
end $fn$;

create table public.room_members(
 room_id uuid not null references public.rooms(id),
 user_id uuid not null references auth.users(id),
 seat_no integer,
 primary key(room_id,user_id)
);

insert into public.rooms(id) values ('44444444-4444-4444-8444-444444444444');
insert into public.room_members(room_id,user_id,seat_no) values
 ('33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',1),
 ('33333333-3333-4333-8333-333333333333',
  '22222222-2222-4222-8222-222222222222',2),
 ('33333333-3333-4333-8333-333333333333',
  '55555555-5555-4555-8555-555555555555',null);

grant usage on schema auth,phase3 to authenticated;
grant execute on function auth.jwt(),auth.uid() to authenticated;

-- Fixture already supplies A-D operation rows. Only one ledger side for B;
-- D is failed. C has both ledger sides. These are synthetic values.
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333','rose',1,100),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333','rose',1,200),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333','rose',7,700),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333','rose',1,100);

insert into public.wallet_ledger(transaction_id,user_id,kind,currency,amount_change) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-100),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',100),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-200),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-700),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',700),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-100),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',100);

insert into public.financial_operations(id,operation,status) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','gift','completed'),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','gift','completed'),
 ('99999999-9999-4999-8999-999999999999','gift','completed');
insert into public.gift_events(
 id,sender_id,recipient_id,room_id,gift_id,quantity,amount
) values
 -- Seat 1 gets 10 coins from seat 2.
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333','rose',1,10),
 -- An unrelated room must not increase seat 2's counter here.
 ('ffffffff-ffff-4fff-8fff-ffffffffffff',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  '44444444-4444-4444-8444-444444444444','rose',1,900),
 -- A listener's historical gifts must not appear under an unoccupied seat.
 ('99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111',
  '55555555-5555-4555-8555-555555555555',
  '33333333-3333-4333-8333-333333333333','rose',1,800);

insert into public.wallet_ledger(transaction_id,user_id,kind,currency,amount_change) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '22222222-2222-4222-8222-222222222222','gift_sent','coins',-10),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '11111111-1111-4111-8111-111111111111','gift_received','diamonds',10),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-900),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff',
  '22222222-2222-4222-8222-222222222222','gift_received','diamonds',900),
 ('99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111','gift_sent','coins',-800),
 ('99999999-9999-4999-8999-999999999999',
  '55555555-5555-4555-8555-555555555555','gift_received','diamonds',800);
