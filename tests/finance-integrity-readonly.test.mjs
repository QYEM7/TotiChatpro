import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const migration=readFileSync(new URL('../supabase/migrations/20261011231000_financial_integrity_preflight.sql',import.meta.url),'utf8');
const ui=readFileSync(new URL('../app/phase5-finance-integrity-ui.js',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('finance integrity SQL is Owner/main-partner only and exposes no recipient ledger rows',()=>{
 assert.match(migration,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(migration,/phase3\.actor\(\)/);
 assert.match(migration,/public\.phase5_finance_integrity_preflight/);
 assert.match(migration,/language plpgsql security invoker/);
 assert.match(migration,/revoke all on function public\.phase5_finance_integrity_preflight[\s\S]+?from public,anon/);
 assert.match(migration,/p_to-p_from>interval '31 days'/);
 assert.match(migration,/walletsNeedingDiamondReconciliation/);
 assert.match(migration,/isReadOnly',true/);
 assert.match(migration,/canZeroDiamonds',false/);
 assert.match(migration,/hasPayrollRates',false/);
});
test('real financial preflight checks paired ledger entries and redemption allocations',()=>{
 assert.match(migration,/op\.operation<>'gift'/);
 assert.match(migration,/coalesce\(lines\.leg_count,0\)<>2/);
 assert.match(migration,/lot\.amount<>g\.amount/);
 assert.match(migration,/op\.operation<>'diamond_redemption'/);
 assert.match(migration,/coalesce\(lots\.allocated,0\)<>r\.diamonds_amount/);
 assert.doesNotMatch(migration,/\b(?:update|delete|truncate)\s+(?:public|phase3)\./i);
});
test('profile UI calls only readonly owner-scoped RPC and never changes approved HTML',()=>{
 assert.match(loader,/phase5-finance-integrity-ui\.js/);
 assert.match(ui,/phase3_admin_session/);
 assert.match(ui,/phase5_finance_integrity_preflight/);
 assert.match(ui,/role\?\.isOwner===true\|\|role\?\.isMainPartner===true/);
 assert.match(ui,/stamp!==epoch/);
 assert.doesNotMatch(ui,/\b(?:phase3_send_gift|phase4_redeem_diamonds|clearDiamonds|resetDiamonds|paySalary)\b/);
 assert(!html.includes('phase5-finance-integrity-ui.js'));
});
