-- T65 all gift and wallet fixtures rolled back. Never paid Staging.
begin;
do $lucky$
declare sender uuid:=gen_random_uuid();receiver uuid:=gen_random_uuid();
 sid uuid:=gen_random_uuid();rid uuid:=gen_random_uuid();
 denied boolean:=false;response jsonb;initial_diamonds bigint;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(sender,sender::text||'@test.invalid',now(),false),
 (receiver,receiver::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,sender);
 insert into public.rooms(id,owner_id,title,is_private)
 values(rid,sender,'T65 no false lucky rewards',false);
 insert into public.room_members(room_id,user_id) values(rid,sender),(rid,receiver);
 update public.wallets set coins=1000 where user_id=sender;
 select diamonds into initial_diamonds from public.wallets where user_id=receiver;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',sender,'session_id',sid,'aal','aal1')::text,true);
 response:=public.phase5_lucky_gift_readiness();
 if response->>'enabled'<>'false'
 or response->>'purchasesAllowed'<>'false'
 or response->>'serverDrawAvailable'<>'false'
 or response->>'code'<>'LUCKY_GIFT_PENDING_RULEBOOK' then
   raise exception 'Backend claims lucky gift odds are approved without proof';end if;
 begin
  perform public.phase3_send_gift(rid,receiver,'g11',1,gen_random_uuid(),300);
 exception when others then
  if SQLERRM like '%LUCKY_GIFT_PENDING_RULEBOOK%' then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'Fixed fake lucky gift result was sold';end if;
 if (select coins from public.wallets where user_id=sender)<>1000
  or (select diamonds from public.wallets where user_id=receiver)<>initial_diamonds
  or exists(select 1 from public.gift_events where sender_id=sender)
  or exists(select 1 from public.financial_operations where actor_id=sender)
  or exists(select 1 from public.wallet_ledger where user_id in(sender,receiver))
  or exists(select 1 from public.diamond_lots where user_id=receiver) then
   raise exception 'Blocked lucky purchase changed money, lots, receipts or ledger';end if;
 response:=public.phase3_send_gift(rid,receiver,'g1',1,gen_random_uuid(),10);
 if response->>'status'<>'completed'
  or (select coins from public.wallets where user_id=sender)<>990
  or (select diamonds from public.wallets where user_id=receiver)<>initial_diamonds+10
  or (select count(*) from public.wallet_ledger
      where transaction_id=(response->>'id')::uuid)<>2
 then raise exception 'Existing safe fixed gift was blocked by lucky safeguard';end if;
 if has_function_privilege('anon','public.phase5_lucky_gift_readiness()','EXECUTE') then
  raise exception 'Anonymous status operation allowed';end if;
end $lucky$;
rollback;
select 'PASS T65: no false lucky payouts, failed gift fully rolls back coins/diamonds/ledger, fixed gift still works' as result;
