'use strict';
/* This protects the Owner's 30-day lean beta prioritization and T48 freeze.
 * Does not claim production readiness or block legitimate security/critical fixes.
 */
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const scope=JSON.parse(fs.readFileSync('docs/beta30-scope.json','utf8'));
const tasks=JSON.parse(fs.readFileSync('docs/50-task-verification.json','utf8'));
const release=JSON.parse(fs.readFileSync('docs/release-readiness.json','utf8'));
const gate=fs.readFileSync('scripts/t48-apk-readiness-gate.cjs','utf8');
const canonical=['T13','T22','T26','T28','T32','T37','T44'];
test('Owner approved minimal beta scope covers 50 tasks but never fabricates completion',()=>{
 assert.equal(scope.project,'TotiChatpro');
 assert.equal(scope.user_visible_brand,'TotiChat');
 assert.equal(scope.budget_usd_now,0);
 assert.equal(scope.beta_duration_days,30);
 assert.equal(scope.statuses_unchanged,true);
 assert.equal(tasks.length,50);
 assert.equal(new Set(tasks.map(t=>t.id)).size,50);
 for(const t of tasks){
  assert(['required_for_beta','minimum_for_beta','paused_after_beta'].includes(t.beta_30d_scope),t.id);
  assert(typeof t.beta_30d_scope_note==='string'&&t.beta_30d_scope_note.length>10,t.id);
  assert(['tested_local','partial','blocked','verified_live'].includes(t.status),t.id);
 }
 assert.deepEqual(tasks.filter(t=>t.beta_30d_scope==='paused_after_beta').map(t=>t.id),canonical);
 assert.equal(tasks.filter(t=>t.status==='verified_live').length,0);
});
test('Manual agency recharge, documented payroll liabilities and scoped admin roles are not deferred',()=>{
 for(const id of ['T05','T12','T14','T16','T18','T20','T21','T24','T25','T29','T30','T33','T34','T35','T36','T38','T39','T40','T41','T42','T49']){
  assert.notEqual(tasks.find(t=>t.id===id).beta_30d_scope,'paused_after_beta',id);
 }
 const decisions=scope.human_approvals;
 for(const key of ['recharge','owner_treasury','host_agencies','host_transfer','monthly_close','support'])
  assert(typeof decisions[key]==='string'&&decisions[key].length>95,key);
 assert.match(decisions.monthly_close,/BEFORE any operational diamond clearing/);
 assert.match(decisions.host_agencies,/never opening recharge agencies/);
});
test('The 80/80 APK+40 verified live gate remains fail-closed after scope freeze',()=>{
 assert.equal(release.engineering_percent,63);
 assert.equal(release.beta_readiness_percent,15);
 assert.equal(release.release_allowed,false);
 assert.equal(scope.release_allowed,false);
 assert.match(gate,/report\.engineering_percent<80/);
 assert.match(gate,/report\.beta_readiness_percent<80/);
 assert.match(gate,/verified.length<40/);
 assert.match(gate,/OWNER_REVIEW!=='APPROVED'/);
});
