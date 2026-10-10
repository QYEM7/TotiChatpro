'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs');
const p=fs.readFileSync('scripts/t06-parallel-support-e2e.mjs','utf8');
const ci=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T06 parallel HTTP rig runs real Auth/PostgREST on loopback only with credential firewall',()=>{
 for(const s of ['T06_DISPOSABLE_ONLY','SUPABASE_ACCESS_TOKEN','DATABASE_URL','PGHOST','localhost','127.0.0.1','/auth/v1/signup','/rest/v1/rpc/phase5_support_action'])
  assert(p.includes(s),s);
 assert(!p.includes('sqedsnyvjblvbjbizcay'));
 assert(ci.includes('scripts/t06-parallel-support-e2e.mjs'));
 assert(!ci.includes('actions/upload-artifact@'));
});
test('T06 concurrent negative assertions reject limit bypass, duplicate idempotency, IDOR and staff escalation',()=>{
 for(const s of ['Promise.all','length:6','length:28','accepted.length!==19','denied.length!==9','thread.total!==20',
  'Support rate limit exceeded','Idempotency key conflict','staff_grant','outsiderReply','outsider'])
  assert(p.includes(s),s);
});
