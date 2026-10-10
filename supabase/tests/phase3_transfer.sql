begin;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();k uuid:=gen_random_uuid();x jsonb;y jsonb;rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,a);update public.wallets set coins=100 where user_id=a;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sid,'aal','aal1')::text,true);
 x:=public.phase3_transfer_coins(b,30,k);y:=public.phase3_transfer_coins(b,30,k);
 if x<>y or (select coins from public.wallets where user_id=a)<>70 or (select coins from public.wallets where user_id=b)<>30 then raise exception 'Transfer balances/idempotency';end if;
 rejected:=false;begin perform public.phase3_transfer_coins(b,31,k);exception when others then rejected:=true;end;if not rejected then raise exception 'Conflicting key accepted';end if;
 rejected:=false;begin perform public.phase3_transfer_coins(b,100,gen_random_uuid());exception when others then rejected:=true;end;if not rejected then raise exception 'Overdraft accepted';end if;
 rejected:=false;begin perform public.phase3_transfer_coins(a,1,gen_random_uuid());exception when others then rejected:=true;end;if not rejected then raise exception 'Self transfer accepted';end if;
 if (select sum(coins) from public.wallets where user_id in(a,b))<>100 or (select count(*) from public.financial_operations where actor_id=a)<>1 then raise exception 'Atomic conservation failed';end if;
 delete from auth.sessions where id=sid;
 rejected:=false;begin perform public.phase3_transfer_coins(b,1,gen_random_uuid());exception when insufficient_privilege then rejected:=true;end;if not rejected then raise exception 'Revoked session accepted';end if;
end $$;
rollback;
select 'PASS: transfer conservation, idempotency, conflict, overdraft rollback, self-transfer, revoked session; fixtures rolled back' as result;
