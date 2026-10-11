-- T64 verified personal gift receipts, real gift-send RPC, all ROLLBACK.
begin;
do $gifts$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();sc uuid:=gen_random_uuid();so uuid:=gen_random_uuid();
 room uuid:=gen_random_uuid();first jsonb;second jsonb;summary jsonb;page jsonb;last_page jsonb;
 denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
  (a,a::text||'@test.invalid',now(),false),
  (b,b::text||'@test.invalid',now(),false),
  (c,c::text||'@test.invalid',now(),false),
  (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sa,a),(sb,b),(sc,c),(so,outsider);
 insert into public.rooms(id,owner_id,title,is_private) values(room,a,'T64 real receipts isolated',false);
 insert into public.room_members(room_id,user_id) values(room,a),(room,b),(room,c);
 update public.wallets set coins=1000 where user_id in(a,c);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 summary:=public.phase5_gift_summary();
 if summary->>'sentCount'<>'0' or summary->>'receivedCount'<>'0'
  or summary->>'sentGiftCoins'<>'0' then
  raise exception 'New user gift history must have zero, not demo receipts';end if;
 perform public.phase3_send_gift(room,b,'g1',1,gen_random_uuid(),10);
 perform public.phase3_send_gift(room,b,'g2',1,gen_random_uuid(),50);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',c,'session_id',sc,'aal','aal1')::text,true);
 perform public.phase3_send_gift(room,b,'g1',1,gen_random_uuid(),10);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 summary:=public.phase5_gift_summary();
 if summary->>'sentCount'<>'2' or summary->>'receivedCount'<>'0'
 or summary->>'sentGiftCoins'<>'60' or summary->>'receivedGiftDiamonds'<>'0' then
  raise exception 'Sender totals are not verified committed events';end if;
 page:=public.phase5_gift_history('sent',1,null,null);
 if jsonb_array_length(page->'items')<>1 or page->>'nextId' is null
  or page->'items'->0->>'counterparty_id'<>b::text
  or page->'items'->0->>'direction'<>'sent' then
  raise exception 'Owner-safe outgoing first gift cursor wrong';end if;
 last_page:=public.phase5_gift_history('sent',1,
   (page->>'nextAt')::timestamptz,(page->>'nextId')::uuid);
 if jsonb_array_length(last_page->'items')<>1
  or last_page->'items'->0->>'id'=page->'items'->0->>'id'
 then raise exception 'Gift receipt keyset paging dropped or duplicated a gift';end if;
 denied:=false;
 begin perform public.phase5_gift_history('received',25,now(),null);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Malformed gift history cursor accepted';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 summary:=public.phase5_gift_summary();
 if summary->>'receivedCount'<>'3' or summary->>'sentCount'<>'0'
  or summary->>'receivedGiftCoins'<>'70'
  or summary->>'receivedGiftDiamonds'<>'70'
 then raise exception 'Recipient committed gift totals/diamonds wrong';end if;
 page:=public.phase5_gift_history('received',25,null,null);
 if jsonb_array_length(page->'items')<>3
  or exists(select 1 from jsonb_array_elements(page->'items') e
    where e->>'recipient_id'<>b::text)
 then raise exception 'Gift receiver history leaked another recipient';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',outsider,'session_id',so,'aal','aal1')::text,true);
 summary:=public.phase5_gift_summary();
 page:=public.phase5_gift_history('all',25,null,null);
 if summary->>'sentCount'<>'0' or summary->>'receivedCount'<>'0'
 or jsonb_array_length(page->'items')<>0
 then raise exception 'Outsider read other accounts private gift receipts';end if;
 if has_function_privilege('anon',
  'public.phase5_gift_history(text,integer,timestamptz,uuid)','EXECUTE')
  or has_function_privilege('anon','public.phase5_gift_summary()','EXECUTE')
 then raise exception 'Anonymous gift history RPC allowed';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in('phase5_gift_history','phase5_gift_summary')
    and p.prosecdef) then raise exception 'Exposed gift history SECURITY DEFINER wrapper';end if;
end $gifts$;
rollback;
select 'PASS T64: actual gift sender/receiver receipts, money-unit counters, diamonds issued, cursor privacy and no fake gifts' as result;
