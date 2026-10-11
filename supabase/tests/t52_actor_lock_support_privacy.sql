-- Execute after the actor-serialization hardening migration.
-- No test identities or stored operational records are ever created.
begin;
do $verify$
declare n text; def text;
begin
 foreach n in array array['agency_action','recharge_action','support_action'] loop
  select pg_get_functiondef(p.oid) into def
  from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
  where ns.nspname='phase3' and p.proname=n;
  if def is null or position('pg_advisory_xact_lock' in def)=0
   or position('phase3.actor()' in def)=0 then
   raise exception 'Missing verified actor transaction lock: %',n;
  end if;
 end loop;
 select pg_get_functiondef('phase3.support_action(text,jsonb,uuid)'::regprocedure) into def;
 if position('sha256(convert_to(' in def)=0 or
    position('prev.payload<>jsonb_build_object' in def)=0 then
   raise exception 'Support private retry fingerprint regression';
 end if;
 if has_function_privilege('anon','public.phase5_support_action(text,jsonb,uuid)','EXECUTE')
 or has_function_privilege('anon','public.phase4_recharge_action(text,jsonb,uuid)','EXECUTE')
 or has_function_privilege('anon','public.phase4_agency_action(text,jsonb,uuid)','EXECUTE') then
   raise exception 'Anonymous action privilege detected';
 end if;
end $verify$;
rollback;
select 'PASS: Staging agency/recharge/support actor locks, private retry SHA, anonymous denies' as result;
