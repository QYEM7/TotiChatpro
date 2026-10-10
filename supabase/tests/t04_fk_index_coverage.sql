-- T04/T45: rollback-only validation of FK coverage and table storage permissions.
begin;
do $check$
declare missing int;
begin
 with expected(schema_name,table_name,col_name) as (values
  ('phase3','admin_access','assigned_by'),
  ('phase3','cp_pair_type_conflicts','type_b'),
  ('phase3','cp_type_conflicts','type_b'),
  ('phase3','session_audits','user_id'),
  ('public','recharge_reward_claims','tier_id')
 ),
 checks as (
 select e.*,exists(
    select 1 from pg_namespace ns
    join pg_class tbl on tbl.relnamespace=ns.oid and tbl.relname=e.table_name
    join pg_attribute att on att.attrelid=tbl.oid and att.attname=e.col_name and att.attnum>0
    join pg_index ix on ix.indrelid=tbl.oid and ix.indisvalid and ix.indisready
      and ix.indpred is null and ix.indkey[0]=att.attnum
    where ns.nspname=e.schema_name
 ) as indexed
 from expected e
 )
 select count(*) into missing from checks where not indexed;
 if missing<>0 then raise exception 'T04 missing % covering FK indexes',missing;end if;
 if has_table_privilege('anon','phase3.admin_access','SELECT')
   or has_table_privilege('authenticated','phase3.session_audits','SELECT')
   or has_table_privilege('anon','public.recharge_reward_claims','SELECT') then
    raise exception 'T04 FK migration unexpectedly opened private tables';
 end if;
end $check$;
rollback;
select 'PASS T04: all five reported FK columns indexed; no privilege expansion' as result;
