'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs');
const s=fs.readFileSync('scripts/t06-parallel-finance-e2e.mjs','utf8');
const wf=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T06 finance parallel test rejects remote Supabase/credentials and uses local ephemeral owner',()=>{
 for(const item of ['T06_DISPOSABLE_ONLY','DATABASE_URL','PGHOST','PGPASSWORD','127.0.0.1',
  'localhost',"^supabase_db_",'/auth/v1/signup','update phase3.system_authority'])
 assert(s.includes(item),item);
 assert(!s.includes('sqedsnyvjblvbjbizcay'));
 assert(wf.includes('scripts/t06-parallel-finance-e2e.mjs'));
});
test('T06 financial conservation tested using genuine concurrent POSTs and ledger',()=>{
 for(const item of ['Promise.all','length:6','length:4','length:28','BigInt(after.treasury)',
   'BigInt(after.issued)','operation_id','===46n','!==30','Rate limit exceeded',
   'Cash issuance reference already used','Idempotency key conflict','ordinary user'])
  assert(s.includes(item),item);
 assert(!wf.includes('actions/upload-artifact@'));
});
