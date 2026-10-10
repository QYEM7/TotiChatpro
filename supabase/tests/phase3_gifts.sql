-- Real PostgreSQL integration tests. All temporary fixtures are rolled back.
begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); rid uuid:=gen_random_uuid(); key uuid:=gen_random_uuid(); first jsonb; again jsonb; rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,a);
 insert into public.rooms(id,owner_id,title,is_private) values(rid,a,'Transactional test',false);
 insert into public.room_members(room_id,user_id) values(rid,a),(rid,b);
 update public.wallets set coins=100 where user_id=a;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sid,'aal','aal1','role','authenticated')::text,true);
 rejected:=false;begin perform public.phase3_send_gift(rid,b,'g1',1,gen_random_uuid(),1);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Unconfirmed gift price accepted';end if;
 first:=public.phase3_send_gift(rid,b,'g1',1,key,10);
 again:=public.phase3_send_gift(rid,b,'g1',1,key,10);
 if first<>again or (select coins from public.wallets where user_id=a)<>90 or (select diamonds from public.wallets where user_id=b)<>10 then raise exception 'Idempotency or balances failed';end if;
 if (select count(*) from public.wallet_ledger where transaction_id=(first->>'id')::uuid)<>2 then raise exception 'Double entry missing';end if;
 if not exists(select 1 from public.security_audit where operation_id=(first->>'id')::uuid) then raise exception 'Audit missing';end if;
 rejected:=false;begin perform public.phase3_send_gift(rid,b,'g2',1,key,50);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Conflicting payload accepted';end if;
 rejected:=false;begin perform public.phase3_send_gift(rid,b,'g12',1,gen_random_uuid(),12000);exception when others then rejected:=true;end;
 if not rejected or (select coins from public.wallets where user_id=a)<>90 or (select count(*) from public.financial_operations where actor_id=a)<>1 then raise exception 'Insufficient funds rollback failed';end if;
 delete from public.room_members where room_id=rid and user_id=b;
 rejected:=false;begin perform public.phase3_send_gift(rid,b,'g1',1,gen_random_uuid(),10);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Nonmember recipient accepted';end if;
 perform set_config('request.jwt.claims','{}',true);
 rejected:=false;begin perform public.phase3_send_gift(rid,b,'g1',1,gen_random_uuid(),10);exception when insufficient_privilege then rejected:=true;end;
 if not rejected then raise exception 'Anonymous operation accepted';end if;
end $$;
rollback;
select 'PASS: duplicate, conflict, atomic ledger/audit, insufficient funds rollback, nonmember, anonymous; fixtures rolled back' as result;
