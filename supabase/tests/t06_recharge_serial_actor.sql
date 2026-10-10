-- T06: local rollback fixture; no production wallets touched.
begin;
do $qa$
declare u uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();
  first_key uuid:=gen_random_uuid();answer jsonb;denied boolean;
  fn text;
begin
 select pg_get_functiondef('public.phase4_recharge_action(text,jsonb,uuid)'::regprocedure)
 into fn;
 if fn not like '%pg_advisory_xact_lock%' or
    position('pg_advisory_xact_lock' in fn)>position('return phase3.recharge_action' in fn)
 then raise exception 'T06 public recharge API lacks pre-action actor lock';end if;
 if has_function_privilege('anon','public.phase4_recharge_action(text,jsonb,uuid)','EXECUTE')
 then raise exception 'T06 recharge RPC became anonymously executable';end if;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(u,u::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,u);
 update phase3.system_authority set owner_id=u,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',u,'session_id',sid,'aal','aal1')::text,true);
 answer:=public.phase4_recharge_action('issue',
   '{"coins":7,"note":"QA cash issuance only on disposable PostgreSQL","cash_reference":"T06-UNIQUE-CASH"}',first_key);
 if answer->>'status'<>'completed' then raise exception 'T06 first issue failed';end if;
 denied:=false;
 begin
   perform public.phase4_recharge_action('issue',
     '{"coins":7,"note":"QA cash issuance only on disposable PostgreSQL","cash_reference":"T06-UNIQUE-CASH"}',gen_random_uuid());
 exception when others then
  if sqlerrm like '%Cash issuance reference already used%' then denied:=true;else raise;end if;
 end;
 if not denied then raise exception 'T06 repeated cash reference minted coins';end if;
 if (select coins from phase3.treasury_accounts where user_id=u)<>7
   or (select issued from phase3.coin_issuance where singleton)<>7
 then raise exception 'T06 repeated issuance changed accounting';end if;
 if public.phase4_recharge_action('issue',
   '{"coins":7,"note":"QA cash issuance only on disposable PostgreSQL","cash_reference":"T06-UNIQUE-CASH"}',first_key)<>answer
 then raise exception 'T06 same-key recharge request was not idempotent';end if;
end $qa$;
rollback;
select 'PASS T06 recharge wrapper: verified actor lock, cash ref unique, balanced issuance and rollback' as result;
