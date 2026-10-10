'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261010191000_t06_support_concurrency_private_retry.sql','utf8');
const fixture=fs.readFileSync('supabase/tests/t06_support_concurrency_privacy.sql','utf8');
test('T06 serialises all support action checks for the same verified actor',()=>{
 assert(migration.includes('u uuid:=phase3.actor()'));
 assert(migration.includes("pg_advisory_xact_lock(hashtextextended('totichat-support:'||u::text,0))"));
 assert(migration.indexOf('pg_advisory_xact_lock')<migration.indexOf('select * into old'));
 assert(migration.indexOf('pg_advisory_xact_lock')<migration.indexOf("count(*) from phase3.support_requests"));
 assert(migration.includes("Support rate limit exceeded"));
});
test('T06 preserves existing RPC grants, legacy retry and no plaintext duplication',()=>{
 assert(migration.includes('create or replace function public.phase5_support_action'));
 assert(migration.includes("sha256(convert_to(payload::text,'UTF8'))"));
 assert(migration.includes('old.payload<>fingerprint and old.payload<>payload'));
 assert(migration.includes('values(u,p_request_id,fingerprint,outcome)'));
 assert(!migration.includes('drop function public.phase5_support_action'));
});
test('T06 rollback fixture exercises 20th and 21st action, retry and redaction',()=>{
 assert(fixture.split('\n').some(s=>s.trim().toLowerCase()==='begin;'));
 assert(fixture.includes('rollback;'));
 for(const phrase of ['T06 21st support mutation bypassed limit','T06 raw private user content duplicated','T06 replay past rate limit failed'])
  assert(fixture.includes(phrase));
});

test('T06 financial recharge API serialises verified actor before existing ledger logic',()=>{
 const file=fs.readFileSync('supabase/migrations/20261010194500_t06_recharge_serial_actor.sql','utf8');
 assert(file.includes('create or replace function public.phase4_recharge_action'));
 assert(file.includes('u uuid:=phase3.actor()'));
 assert(file.indexOf('pg_advisory_xact_lock')<file.indexOf('return phase3.recharge_action'));
 assert(!file.includes('update public.wallets')&&!file.includes('update phase3.coin_issuance'));
 const testFixture=fs.readFileSync('supabase/tests/t06_recharge_serial_actor.sql','utf8');
 assert(testFixture.includes('Cash issuance reference already used'));
 assert(testFixture.includes('rollback;'));
});
