import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const migration=readFileSync(new URL('../supabase/migrations/20261012091412_staging_treasury_integrity_preflight_readonly_v1.sql',import.meta.url),'utf8');
const noComments=migration.replace(/--[^\n]*/g,'');
test('privileged private finance reconciliation is read-only and limited to Owner/main partner',()=>{
 assert.match(migration,/create function phase3\.treasury_integrity_preflight\(\)/);
 assert.match(migration,/phase3\.actor\(\)/);
 assert.match(migration,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(migration,/using errcode='42501'/);
 assert.match(migration,/language plpgsql security definer set search_path=''/);
 assert.match(migration,/returns jsonb/);
 assert.match(migration,/create function public\.phase6_treasury_integrity_preflight\(\)/);
 assert.match(migration,/language plpgsql security invoker set search_path=''/);
 assert.match(migration,/revoke all on function public\.phase6_treasury_integrity_preflight\(\) from public,anon,authenticated/);
 assert.match(migration,/grant execute on function public\.phase6_treasury_integrity_preflight\(\) to authenticated/);
 assert.doesNotMatch(noComments,/\b(?:insert|update|delete|truncate|alter)\s+(?:public|phase3)\./i);
});
test('issued coins reconcile with issuance control and immutable audit legs',()=>{
 for(const pattern of [
 /phase3\.coin_issuance/,
 /phase3\.issuance_ledger/,
 /issued\+issuance_net<>0/,
 /phase3\.treasury_accounts/,
 /phase3\.treasury_ledger/,
 /coalesce\(t\.legs,0\)<>1/,
 /coalesce\(l\.legs,0\)<>1/,
 /l\.operation_id=op\.id/,
 /l\.user_id=op\.actor_id/
 ])assert.match(migration,pattern);
 assert.match(migration,/issuanceControlMismatch/);
 assert.match(migration,/issuanceOperationMismatches/);
 assert.match(migration,/issuanceOrphanRows/);
});
test('agent allocations and real approved topups require matching balanced ledgers',()=>{
 for(const pattern of [
 /op\.payload->>'action'='allocate'/,
 /a\.kind='recharge'/,
 /coalesce\(t\.legs,0\)<>2/,
 /t\.delta is distinct from 0::numeric/,
 /t\.debit is distinct from -expected\.amount/,
 /t\.credit is distinct from expected\.amount/,
 /op\.payload->>'action'='approve'/,
 /public\.recharge_requests/,
 /req\.status<>'completed'/,
 /expected\.base_coins is distinct from req\.coins::numeric/,
 /coalesce\(w\.legs,0\)<>1/,
 /w\.delta is distinct from expected\.amount/
 ])assert.match(migration,pattern);
 assert.match(migration,/hasDetectedLedgerIssues/);
});
test('does not claim financial close, monetary readiness or salary payments without proof',()=>{
 assert.match(migration,/'isReadOnly',true/);
 assert.match(migration,/'isReadyForMoneyMovement',false/);
 assert.match(migration,/'paysSalaries',false/);
 assert.match(migration,/'canZeroDiamonds',false/);
 assert.match(migration,/'canIssueCoins',false/);
 assert.match(migration,/'hasPayrollRates',false/);
 assert.doesNotMatch(noComments,/pg_sleep|pg_advisory|security\s+label|set_config/i);
});
