'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261010202000_t35_agency_atomic_actor.sql','utf8');
const rig=fs.readFileSync('scripts/t35-parallel-host-transfer-e2e.mjs','utf8');
const wf=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T35 verified actor locking occurs within direct-callable private function, before rate/idempotency checks',()=>{
 assert(migration.includes('create or replace function phase3.agency_action('));
 assert(migration.includes('u uuid:=phase3.actor()'));
 assert(migration.includes("pg_advisory_xact_lock(hashtextextended('totichat-agency:'||u::text,0))"));
 assert(migration.indexOf('pg_advisory_xact_lock')<migration.indexOf('select * into prior'));
 assert(migration.indexOf('pg_advisory_xact_lock')<migration.indexOf("count(*) from phase3.agency_requests"));
 for(const rule of ['Old agency approval required','Investigating administrator required','Host membership changed','phase3.can_manage_agency(reg.kind)'])
  assert(migration.includes(rule),rule);
});
test('T35 real HTTP QA is disposable localhost with negative old-consent, IDOR and quota tests',()=>{
 for(const key of ['T35_DISPOSABLE_ONLY','SUPABASE_ACCESS_TOKEN','DATABASE_URL','PGHOST','127.0.0.1',
   'localhost','/auth/v1/signup','/rest/v1/rpc/phase4_agency_action','Promise.all','length:6','length:28',
   "move.status!=='pending_old'",'approve_old','accept_join','oldApprovedBy','31st Owner action'])
  assert(rig.includes(key),key);
 assert(!rig.includes('sqedsnyvjblvbjbizcay'));
 assert(wf.includes('scripts/t35-parallel-host-transfer-e2e.mjs'));
});
