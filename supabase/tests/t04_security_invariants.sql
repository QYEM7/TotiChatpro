-- T04: no production writes. Intended only for a fresh, unlinked local Supabase.
begin;
do $audit$
declare total integer; r record;
begin
 select count(*) into total from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','phase3') and c.relkind in ('r','p');
 if total<45 then raise exception 'T04 expected >=45 tables, got %',total;end if;
 for r in select c.oid,n.nspname,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','phase3') and c.relkind in ('r','p') loop
  if not r.relrowsecurity then raise exception 'T04 RLS disabled: %.%',r.nspname,r.relname;end if;
 end loop;
 for r in select p.oid,n.nspname,p.proname,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','phase3') and p.prosecdef loop
  if has_function_privilege('anon',r.oid,'EXECUTE') or has_function_privilege('public',r.oid,'EXECUTE') then
   raise exception 'T04 anonymous privileged RPC: %.%',r.nspname,r.proname;end if;
  if r.proconfig is null or not ('search_path=""'=any(r.proconfig)) then
   raise exception 'T04 SECURITY DEFINER search_path not pinned: %.%',r.nspname,r.proname;end if;
 end loop;
 for r in select c.oid,n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='phase3' and c.relkind in ('r','p') loop
  if has_table_privilege('anon',r.oid,'SELECT') or has_table_privilege('authenticated',r.oid,'SELECT')
  or has_table_privilege('anon',r.oid,'INSERT,UPDATE,DELETE') or has_table_privilege('authenticated',r.oid,'INSERT,UPDATE,DELETE') then
   raise exception 'T04 internal table grants too permissive: %.%',r.nspname,r.relname;end if;
 end loop;
 for r in select c.oid,n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in (
 'wallets','wallet_ledger','financial_operations','gift_events','diamond_lots',
 'diamond_redemptions','diamond_redemption_allocations','recharge_requests',
 'recharge_reward_claims','reward_fulfillment','agencies','agency_members',
 'agency_join_requests','agency_registrations','security_audit','voice_messages') loop
  if has_table_privilege('anon',r.oid,'INSERT,UPDATE,DELETE') or has_table_privilege('authenticated',r.oid,'INSERT,UPDATE,DELETE') then
   raise exception 'T04 direct client write grant: %.%',r.nspname,r.relname;end if;
 end loop;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='wallets'
 and cmd='SELECT' and array_to_string(roles,',') like '%authenticated%' and qual like '%auth.uid%') then
  raise exception 'T04 own-wallet read policy missing';end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='wallet_ledger'
 and cmd='SELECT' and qual like '%auth.uid%') then
  raise exception 'T04 own-ledger read policy missing';end if;
 if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='phase3' and p.proname='manage_access' and p.prosecdef and
 has_function_privilege('authenticated',p.oid,'EXECUTE')) then
  raise exception 'T04 authenticated owner role-management entrypoint missing';end if;
end $audit$;
rollback;
select 'PASS T04: protected tables all have RLS; no privileged anon RPCs; locked function search paths; finance and agency DML denied to clients' as result;
