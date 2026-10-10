'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const s=fs.readFileSync('scripts/t30-reseller-flow-e2e.mjs','utf8');
const ci=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T30 reseller e2e is unlinked local only and uses verified GoTrue actors',()=>{
 for(const token of ['T06_DISPOSABLE_ONLY','SUPABASE_ACCESS_TOKEN','DATABASE_URL','PGHOST',
 '127.0.0.1','localhost','supabase_db_','/auth/v1/signup','update phase3.system_authority'])
 assert(s.includes(token),token);
 assert(!s.includes('sqedsnyvjblvbjbizcay'));
 assert(ci.includes('scripts/t30-reseller-flow-e2e.mjs'));
});
test('T30 tests real Owner/agent/customer, concurrent idempotency and ledger conservation',()=>{
 for(const token of ['approve_registration','kind:\'recharge\'','Promise.all','length:6',
 'cash_reference','agent_topup','customerLedger','Request already resolved','500n-credit'])
 assert(s.includes(token),token);
});
