-- T06: local-only financial abuse bounds. This NEVER commits fake currency to production.
begin;
do $t06$
declare qa_owner uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();first_key uuid:=gen_random_uuid();
 answer jsonb;repeat_result jsonb;first_data jsonb;new_data jsonb;
 rejected boolean;balance bigint;num integer;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(qa_owner,qa_owner::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sid,qa_owner);
 update phase3.system_authority set owner_id=qa_owner,main_partner_id=null where singleton;
 perform set_config('request.jwt.claims',
 jsonb_build_object('sub',qa_owner,'session_id',sid,'aal','aal1')::text,true);
 first_data:=jsonb_build_object('coins',1,'note','QA simulated and rollback-only cash issuance','cash_reference','T06-CASE-1');
 answer:=public.phase4_recharge_action('issue',first_data,first_key);
 if answer->>'status'<>'completed' then raise exception 'T06 first issuance did not succeed';end if;
 for num in 2..30 loop
   new_data:=jsonb_build_object('coins',1,'note','QA simulated and rollback-only cash issuance',
     'cash_reference','T06-CASE-'||num);
   answer:=public.phase4_recharge_action('issue',new_data,gen_random_uuid());
   if answer->>'status'<>'completed' then raise exception 'T06 first 30 actions should succeed';end if;
 end loop;
 select coins into balance from phase3.treasury_accounts where user_id=qa_owner;
 if balance<>30 then raise exception 'T06 balance expected exactly 30, observed %',balance;end if;
 if (select count(*) from public.financial_operations where actor_id=qa_owner)<>30 then
   raise exception 'T06 must preserve 30 recorded operations';end if;
 rejected:=false;
 begin
   perform public.phase4_recharge_action('issue',
    jsonb_build_object('coins',1,'note','QA simulated and rollback-only cash issuance',
      'cash_reference','T06-CASE-31'),gen_random_uuid());
 exception when others then
   if SQLERRM like '%Rate limit exceeded%' then rejected:=true;else raise;end if;
 end;
 if not rejected then raise exception 'T06 31st new issuance bypassed limit';end if;
 repeat_result:=public.phase4_recharge_action('issue',first_data,first_key);
 if repeat_result->>'status'<>'completed' then raise exception 'T06 idempotent retry rejected';end if;
 if (select coins from phase3.treasury_accounts where user_id=qa_owner)<>30 or
    (select count(*) from public.financial_operations where actor_id=qa_owner)<>30 then
   raise exception 'T06 retry or rate-limit refusal changed money/operations';end if;
end $t06$;
rollback;
select 'PASS T06: 30 per minute allowed, 31st rejected; same idempotency key preserved without inflation; local simulated issuance rolled back' as result;
