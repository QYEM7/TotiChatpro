import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const read=p=>readFileSync(new URL(p,root),'utf8');
const v1=read('supabase/migrations/20261012095808_staging_host_month_evidence_integrity_v1.sql');
const fix=read('supabase/migrations/20261012095924_staging_host_month_snapshot_join_scope_fix_v2.sql');
const clean=v1.replace(/--[^\n]*/g,'');
test('host-month audit authorizes ONLY protected Owner and designated main partner',()=>{
 assert.match(v1,/phase3\.actor\(\)/);
 assert.match(v1,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(v1,/using errcode='42501'/);
 assert.match(v1,/create or replace function public\.phase6_host_month_evidence_integrity\(p_month date\)/i);
 const wrapper=v1.split(/CREATE OR REPLACE FUNCTION public\.phase6_host_month_evidence_integrity/i)[1]?.split('revoke all on function public.phase6_host_month_evidence_integrity')[0];
 assert(wrapper,'Expected unprivileged wrapper');
 assert.doesNotMatch(wrapper,/\bSECURITY DEFINER\b/i); // PostgreSQL omits its default SECURITY INVOKER keyword
 assert.match(v1,/revoke all on function public\.phase6_host_month_evidence_integrity\(date\) from public,anon,authenticated/);
 assert.match(v1,/grant execute on function public\.phase6_host_month_evidence_integrity\(date\) to authenticated/);
 assert.match(v1,/set search_path to ''/i);
});
test('audit compares historical immutable gift totals with all snapshot lines and flags missing lots',()=>{
 for(const s of [
  'public.gift_events','public.agencies','public.diamond_lots',
  'phase3.host_month_accrual_headers','phase3.host_month_accrual_lines',
  'l.user_id is distinct from g.recipient_id',
  'l.amount is distinct from g.amount',
  'l.source_type is distinct from g.diamond_source_type',
  "'hostGiftsMissingOrMismatchedLots'",
  "'unassignedGiftEventsForReview'",
  "'snapshotGroupMismatches'",
  "'snapshotConsistent'",
  "'canApprovePayroll',false",
  "'canPaySalaries',false",
  "'canZeroDiamonds',false"
 ]) assert(v1.includes(s),'Missing invariant: '+s);
 assert.match(v1,/g\.agency_id is null/);
 assert.doesNotMatch(v1,/sum\(l\.remaining\)/); // do not confuse historical earnings with today's remaining diamonds
});
test('pre-snapshot capture aborts if verified monthly diamond lot evidence is missing',()=>{
 assert.match(v1,/before insert on phase3\.host_month_accrual_headers/);
 assert.match(v1,/phase3\.reject_incomplete_host_month_capture\(\)/);
 assert.match(v1,/if bad_count>0 then/);
 assert.match(v1,/using errcode='23514'/);
 assert.doesNotMatch(clean,/\b(?:update|delete|truncate)\s+(?:public|phase3)\./i);
});
test('historical month comparison avoids unrelated saved lines and cannot settle or zero diamonds',()=>{
 assert.match(fix,/full outer join \(select \* from phase3\.host_month_accrual_lines where month_start=p_month\) saved/);
 assert.match(fix,/and saved\.agency_id=cur\.agency_id and saved\.host_id=cur\.recipient_id/);
 assert.match(fix,/snapshot_ok:=/);
 assert.match(fix,/'isAccrualEvidenceOnly',true/);
 assert.doesNotMatch(fix,/\b(?:update|delete|truncate)\s+(?:public|phase3)\./i);
});

test('every reconstructed pg_get_functiondef block is a standalone terminated SQL statement',()=>{
 for(const [name,script,expected] of [
  ['host_month_evidence_v1',v1,3],
  ['snapshot_join_scope_v2',fix,1]
 ]){
  const endings=[...script.matchAll(/end \$function\$;\s*/gi)];
  assert.equal(endings.length,expected,name+' must delimit each PostgreSQL function body with a semicolon');
  const unterminated=[...script.matchAll(/end \$function\$(?!;)/gi)];
  assert.equal(unterminated.length,0,name+' contains invalid unterminated function definition');
 }
});
