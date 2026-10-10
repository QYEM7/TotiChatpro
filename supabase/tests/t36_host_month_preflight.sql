begin;
do $t36$
declare owner uuid:=gen_random_uuid();partner uuid:=gen_random_uuid();
 other uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid();
 partner_session uuid:=gen_random_uuid(); other_session uuid:=gen_random_uuid();
 month_start date:=(date_trunc('month',now() at time zone 'UTC')::date-interval '1 month')::date;
 result jsonb;denied boolean;before_total bigint;after_total bigint;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(owner,owner::text||'@test.invalid',now(),false),
 (partner,partner::text||'@test.invalid',now(),false),
 (other,other::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id)
 values(sid,owner),(partner_session,partner),(other_session,other);
 update phase3.system_authority set owner_id=owner,main_partner_id=partner where singleton;
 select coalesce(sum(amount),0) into before_total from public.diamond_lots;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'session_id',other_session,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_host_month_preflight(month_start);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T36 ordinary user accessed private accrual';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'session_id',sid,'aal','aal1')::text,true);
 perform public.phase3_manage_access(other,'super_admin','{}',false);
 result:=public.phase5_host_month_preflight(month_start);
 if result->>'canZeroDiamonds'<>'false' or result->>'paysSalaries'<>'false' or
 result->>'hasPayrollRates'<>'false' or result->>'isDraftPreflight'<>'true' or
 jsonb_typeof(result->'entries')<>'array' then
  raise exception 'T36 safe nonsettling preview response invalid';end if;
 denied:=false;begin perform public.phase5_host_month_preflight(date_trunc('month',now())::date);
 exception when others then denied:=true;end;
 if not denied then raise exception 'T36 permitted current month to be settled';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'session_id',other_session,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase5_host_month_preflight(month_start);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'T36 ordinary additional Super Admin inherited main partner role';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',partner,'session_id',partner_session,'aal','aal1')::text,true);
 result:=public.phase5_host_month_preflight(month_start,0,5);
 if result->>'isDraftPreflight'<>'true' then raise exception 'T36 designated main partner rejected';end if;
 select coalesce(sum(amount),0) into after_total from public.diamond_lots;
 if after_total<>before_total then raise exception 'T36 preflight unexpectedly mutated diamond ledger';end if;
end $t36$;
rollback;
select 'PASS T36: Owner+main partner only, generic Super Admin denied; closed month, no salaries or zeroing, immutable diamond sums' as result;
