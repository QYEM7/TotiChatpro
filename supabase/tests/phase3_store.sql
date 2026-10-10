begin;
do $$
declare u uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); k uuid:=gen_random_uuid(); a jsonb; b jsonb; rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,u);
 update public.wallets set coins=1000,silver=1000 where user_id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 rejected:=false;begin perform public.phase3_purchase_store('b1',gen_random_uuid(),1,'gold');exception when others then rejected:=true;end;
 if not rejected then raise exception 'Unconfirmed store price accepted';end if;
 a:=public.phase3_purchase_store('b1',k,800,'gold');b:=public.phase3_purchase_store('b1',k,800,'gold');
 if a<>b or (select coins from public.wallets where user_id=u)<>200 then raise exception 'Purchase idempotency failed';end if;
 perform public.phase3_equip_store('b1',true);
 if not exists(select 1 from public.store_ownership where user_id=u and item_id='b1' and equipped) then raise exception 'Equipment failed';end if;
 perform public.phase3_purchase_store('b2',gen_random_uuid(),300,'silver');
 if (select silver from public.wallets where user_id=u)<>700 then raise exception 'Silver debit failed';end if;
 perform public.phase3_equip_store('b2',true);
 if exists(select 1 from public.store_ownership where user_id=u and item_id='b1' and equipped) then raise exception 'Duplicate category equipment';end if;
 rejected:=false;begin perform public.phase3_purchase_store('b1',gen_random_uuid(),800,'gold');exception when others then rejected:=true;end;
 if not rejected or (select coins from public.wallets where user_id=u)<>200 then raise exception 'Failed purchase rollback failed';end if;
 rejected:=false;begin perform public.phase3_purchase_store('b2',k,300,'silver');exception when others then rejected:=true;end;
 if not rejected then raise exception 'Idempotency conflict accepted';end if;
 rejected:=false;begin perform public.phase3_equip_store('f1',true);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Unowned item equipped';end if;
 if (select count(*) from public.wallet_ledger where user_id=u)<>2 or (select count(*) from public.financial_operations where actor_id=u)<>2 then raise exception 'Ledger count mismatch';end if;
end $$;
rollback;
select 'PASS: gold/silver debit, idempotency/conflict, equipment ownership/category, insufficient funds rollback; fixtures rolled back' as result;
