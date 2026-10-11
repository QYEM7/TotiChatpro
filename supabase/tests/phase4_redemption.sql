begin;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();room uuid:=gen_random_uuid();key uuid:=gen_random_uuid();quote jsonb;result jsonb;repeat_result jsonb;rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sa,a),(sb,b);
 insert into public.rooms(id,owner_id,title) values(room,a,'Redemption SQL test');
 insert into public.room_members(room_id,user_id) values(room,a),(room,b);
 update public.wallets set coins=1000 where user_id=a;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 perform public.phase3_send_gift(room,b,'g1',1,gen_random_uuid(),10);
 -- T65 onward: historic lucky-lot redemption must remain testable while
 -- NEW lucky purchases are forbidden. Only this isolated transaction
 -- temporarily suspends the new-purchase guard for a legacy fixture.
 -- BEGIN/ROLLBACK restores the trigger even if an assertion fails.
 if exists(select 1 from pg_trigger where tgrelid='public.gift_events'::regclass
   and tgname='tc_reject_unapproved_lucky_gifts') then
   execute 'alter table public.gift_events disable trigger tc_reject_unapproved_lucky_gifts';
   perform public.phase3_send_gift(room,b,'g11',1,gen_random_uuid(),300);
   execute 'alter table public.gift_events enable trigger tc_reject_unapproved_lucky_gifts';
 else
   perform public.phase3_send_gift(room,b,'g11',1,gen_random_uuid(),300);
 end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 quote:=public.phase4_preview_redemption(15);
 if quote->>'fixed'<>'10' or quote->>'lucky'<>'5' or quote->>'coins'<>'4' then raise exception 'Source-specific quote failed';end if;
 rejected:=false;begin perform public.phase4_redeem_diamonds(15,5,gen_random_uuid());exception when others then rejected:=true;end;if not rejected then raise exception 'Changed quote accepted';end if;
 result:=public.phase4_redeem_diamonds(15,4,key);repeat_result:=public.phase4_redeem_diamonds(15,4,key);
 if result<>repeat_result or (select diamonds from public.wallets where user_id=b)<>295 or (select coins from public.wallets where user_id=b)<>4 then raise exception 'Redemption balances or idempotency';end if;
 if (select sum(amount) from public.diamond_redemption_allocations where redemption_id=(result->>'id')::uuid)<>15 or (select sum(remaining) from public.diamond_lots where user_id=b)<>295 then raise exception 'Diamond source conservation';end if;
 if (select count(*) from public.wallet_ledger where transaction_id=(result->>'id')::uuid)<>2 then raise exception 'Redemption ledger missing';end if;
 rejected:=false;begin perform public.phase4_redeem_diamonds(16,4,key);exception when others then rejected:=true;end;if not rejected then raise exception 'Conflicting redemption key accepted';end if;
 update public.wallets set diamonds=diamonds+100 where user_id=b;
 rejected:=false;begin perform public.phase4_redeem_diamonds(300,90,gen_random_uuid());exception when others then rejected:=true;end;
 if not rejected or (select diamonds from public.wallets where user_id=b)<>395 then raise exception 'Untracked diamonds redeemed';end if;
 rejected:=false;begin perform public.phase4_preview_redemption(3);exception when others then rejected:=true;end;if not rejected then raise exception 'Zero-value redemption accepted';end if;
end $$;
rollback;
select 'PASS: actual gift-issued lots, 30% per source, quote confirmation, allocations/conservation, ledger, idempotency/conflict, untracked refusal; fixtures rolled back' as result;
