-- Validate member-only read access and ledger-backed seat totals.
-- ONLY run inside disposable CI PostgreSQL.
\set ON_ERROR_STOP on
do $test$
begin
 if not has_function_privilege('authenticated',
   'public.phase2_room_seat_gift_totals(uuid)','EXECUTE')
 then raise exception 'MEMBER_RPC_MISSING_EXEC';end if;
 if has_function_privilege('anon',
   'public.phase2_room_seat_gift_totals(uuid)','EXECUTE')
 then raise exception 'ANON_CAN_READ_SEAT_TOTALS';end if;
end $test$;

set role authenticated;
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"11111111-aaaa-4aaa-8aaa-111111111111"}',false);

do $test$
declare c int; actual bigint; first_seat bigint;
begin
 select count(*) into c from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 );
 if c<>2 then raise exception 'ACTIVE_SEAT_ROW_COUNT: %',c;end if;
 select total_coins into actual from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 ) where user_id='22222222-2222-4222-8222-222222222222'::uuid;
 if actual<>800 then raise exception 'UNVERIFIED_OR_OTHER_ROOM_AMOUNT: %',actual;end if;
 select total_coins into first_seat from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 ) where user_id='11111111-1111-4111-8111-111111111111'::uuid;
 if first_seat<>10 then raise exception 'FIRST_SEAT_GIFT_VALUE: %',first_seat;end if;
end $test$;

-- A room member cannot extract any other room's financial data.
do $test$
declare blocked boolean:=false;
begin
 begin
  perform * from public.phase2_room_seat_gift_totals(
   '44444444-4444-4444-8444-444444444444'::uuid
  );
 exception when insufficient_privilege then blocked:=true;
 end;
 if not blocked then raise exception 'CROSS_ROOM_MEMBER_ACCESS';end if;
end $test$;

-- Unknown or stale sessions are denied by actor() before member lookup.
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"aaaaaaaa-1111-4111-8111-111111111111"}',false);
do $test$
declare blocked boolean:=false;
begin
 begin
  perform * from public.phase2_room_seat_gift_totals(
   '33333333-3333-4333-8333-333333333333'::uuid
  );
 exception when insufficient_privilege then blocked:=true;
 end;
 if not blocked then raise exception 'STALE_SESSION_BYPASS';end if;
end $test$;

-- Another joined listener cannot request a room where they are not member.
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"55555555-5555-4555-8555-555555555555","session_id":"55555555-cccc-4ccc-8ccc-555555555555"}',false);
do $test$
declare c int;
begin
 select count(*) into c from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 );
 if c<>2 then raise exception 'LISTENER_SEAT_LEAK';end if;
end $test$;
reset role;

-- When the current seat occupant changes, their gift total replaces the
-- previous member's; it is not tied to the seat number and not fabricated.
update public.room_members set seat_no=null
 where room_id='33333333-3333-4333-8333-333333333333'
   and user_id='22222222-2222-4222-8222-222222222222';
update public.room_members set seat_no=2
 where room_id='33333333-3333-4333-8333-333333333333'
   and user_id='55555555-5555-4555-8555-555555555555';

set role authenticated;
select pg_catalog.set_config('request.jwt.claims',
 '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","session_id":"11111111-aaaa-4aaa-8aaa-111111111111"}',false);
do $test$
declare c int; new_value bigint;
begin
 select count(*) into c from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 );
 select total_coins into new_value from public.phase2_room_seat_gift_totals(
  '33333333-3333-4333-8333-333333333333'::uuid
 ) where user_id='55555555-5555-4555-8555-555555555555'::uuid;
 if c<>2 or new_value<>800 then
  raise exception 'SEAT_REASSIGNMENT_MISMATCH: % %',c,new_value;
 end if;
end $test$;
reset role;
select 'PASS: verified in-room seat totals, permission denial and seat reassignment' as result;
