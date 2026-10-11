import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011235000_finance_integrity_issue_drilldown.sql',import.meta.url),'utf8');
const ui=readFileSync(new URL('../app/phase5-finance-integrity-ui.js',import.meta.url),'utf8');
test('finance anomaly drilldown cannot be called by anonymous accounts and rechecks Owner scope',()=>{
 assert.match(sql,/phase3\.actor\(\)/);
 assert.match(sql,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(sql,/p_kind not in\('gift','redemption','wallet'\)/);
 assert.match(sql,/p_to-p_from>interval '31 days'/);
 assert.match(sql,/p_limit not between 1 and 25/);
 assert.match(sql,/public\.phase5_finance_integrity_issues/);
 assert.match(sql,/language plpgsql security invoker/);
 assert.match(sql,/from public,anon/);
});
test('drilldown UI safely displays server-only mismatches and cannot mutate balances',()=>{
 assert.match(ui,/phase5_finance_integrity_issues/);
 assert.match(ui,/validAuditType/);
 assert.match(ui,/token!==serial/);
 assert.match(ui,/output\.replaceChildren\(\)/);
 assert.match(ui,/row\.append\(node\('strong'/);
 assert.doesNotMatch(ui,/\b(?:innerHTML|phase3_send_gift|phase4_redeem_diamonds|resetDiamonds|paySalary)\b/);
 assert.match(sql,/isReadOnly',true/);
 assert.match(sql,/canZeroDiamonds',false/);
 assert.doesNotMatch(sql,/\b(?:update|delete)\s+public\.(?:wallets|wallet_ledger|diamond_lots)/i);
});
