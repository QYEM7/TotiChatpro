-- T67: disposable/unlinked local Supabase only. EVERY money/action fixture is rolled back.
-- Verify actual lucky gift transactional flow, no fake awarded cash, 10% Lucky redemption,
-- admin denial and request replay safety. NEVER run against production or Staging.
begin;
do $test$
declare sender uuid:=gen_random_uuid(); recipient uuid:=gen_random_uuid();
 sid uuid:=gen_random_uuid(); recipient_sid uuid:=gen_random_uuid(); rid uuid:=gen_random_uuid(); req uuid:=gen_random_uuid();
 result jsonb; again jsonb; quote jsonb; policy jsonb; awarded record; denied boolean:=false;
 initial_diamonds bigint;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(sender,sender::text||'@test.invalid',now(),false),
 (recipient,recipient::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,sender),(recipient_sid,recipient);
 insert into public.rooms(id,owner_id,title,is_private)
 values(rid,sender,'T67 rollback-only lucky gift test',false);
 insert into public.room_members(room_id,user_id) values(rid,sender),(rid,recipient);
 update public.wallets set coins=9000 where user_id=sender;
 select diamonds into initial_diamonds from public.wallets where user_id=recipient;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',sender,'session_id',sid,'aal','aal1')::text,true);
 -- Explicit isolated local pilot activation. Fresh environments stay disabled by default.
 update phase3.lucky_settings set enabled=true,version=version+1 where singleton;
 policy:=public.phase6_lucky_gift_policy();
 if policy->>'enabled'<>'true' or policy->>'currency'<>'LUCKY_POINTS_NON_REDEEMABLE'
  or (select sum(weight) from phase3.lucky_reward_tiers)<>10000 then
  raise exception 'T67 no valid server-backed odds';end if;
 result:=public.phase3_send_gift(rid,recipient,'g11',1,req,300);
 if result->>'status'<>'completed' or result->>'amount'<>'300'
  or result->'luckyResult' is null or result->'luckyResult'->>'currency'<>'LUCKY_POINTS_NON_REDEEMABLE'
  or (result->'luckyResult'->>'eventId')::uuid is null then
   raise exception 'T67 missing verified settled lucky result: %',result;end if;
 if (select coins from public.wallets where user_id=sender)<>8700
  or (select diamonds from public.wallets where user_id=recipient)<>initial_diamonds+300
  or (select count(*) from public.wallet_ledger where transaction_id=(result->>'id')::uuid)<>2
  or (select count(*) from public.gift_events where id=(result->>'id')::uuid)<>1
  or (select count(*) from public.diamond_lots where gift_event_id=(result->>'id')::uuid and
      source_type='LUCKY_GIFT' and amount=300)<>1 then
  raise exception 'T67 base money and ledger conservation failed';end if;
 select * into awarded from phase3.lucky_awards a where a.gift_event_id=(result->>'id')::uuid;
 if not found or awarded.base_coins<>300 or
  awarded.bonus_points<>300*(awarded.multiplier-1) or
  awarded.event_id::text<>result->'luckyResult'->>'eventId' or
  awarded.sender_id<>sender or awarded.recipient_id<>recipient or awarded.room_id<>rid then
  raise exception 'T67 immutable Lucky-only point award mismatch';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',recipient,'session_id',recipient_sid,'aal','aal1')::text,true);
 quote:=phase3.preview_redemption(300);
 if (quote->>'lucky')::bigint<>300 or (quote->>'fixed')::bigint<>0 or
    (quote->>'coins')::bigint<>30 or quote->>'luckyConversionRate'<>'10_PERCENT' then
  raise exception 'T67 incorrect 10 percent Lucky redemption quote: %',quote;end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',sender,'session_id',sid,'aal','aal1')::text,true);
 again:=public.phase3_send_gift(rid,recipient,'g11',1,req,300);
 if again<>result or (select coins from public.wallets where user_id=sender)<>8700 or
  (select count(*) from public.financial_operations where actor_id=sender and request_id=req)<>1 or
  (select count(*) from phase3.lucky_awards where sender_id=sender)<>1 then
   raise exception 'T67 repeated gift request was double-charged or redrawn';end if;
 if (select jsonb_array_length(public.phase6_lucky_gift_history(25)))<1 then
   raise exception 'T67 sender cannot read their real Lucky history';end if;
 begin
  perform public.phase6_lucky_gift_configure(true,'[{"rewardTier":"spark","label":"نجمة","weight":10000,"multiplier":1,"maxDailyWins":null}]'::jsonb,gen_random_uuid());
 exception when insufficient_privilege then denied:=true;
 when others then if sqlstate='42501' then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'T67 unapproved user configured owner-only Lucky odds';end if;
 if has_function_privilege('anon','phase3.draw_verified_lucky_award()','EXECUTE') or
    has_function_privilege('authenticated','phase3.draw_verified_lucky_award()','EXECUTE') then
  raise exception 'T67 internal draw callable directly';end if;
end $test$;
rollback;
select 'PASS T67: real locally rolled-back Lucky transfer, server draw, 10% redemption, idempotency and admin denial' as result;
