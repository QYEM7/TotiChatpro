import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync(new URL('../supabase/migrations/20261011141000_backend_actor_serialization_support_privacy.sql',import.meta.url),'utf8');
function definition(name){
 const from=sql.indexOf('CREATE OR REPLACE FUNCTION phase3.'+name+'(');
 const next=sql.indexOf('\n\nCREATE OR REPLACE FUNCTION',from+1);
 assert(from>=0,'Expected private backend function '+name);
 return sql.slice(from,next<0?sql.length:next);
}

for(const name of ['agency_action','recharge_action','support_action']){
 test('verified actor: '+name+' locks before idempotency and rate checks',()=>{
  const fn=definition(name);
  assert.match(fn,/u uuid:=phase3\.actor\(\)/,'verified actor is server-derived');
  const lock=fn.indexOf("pg_advisory_xact_lock(hashtextextended('totichat-"+name+":'||u::text,0))");
  const reuse=fn.indexOf('select * into ');
  assert(lock>0&&reuse>lock,'serialize before the first retry lookup');
  assert.equal(fn.match(/pg_advisory_xact_lock/g)?.length,1);
  assert.match(fn,/Idempotency key conflict|Request key conflict/);
 });
}

test('support retry ledger hashes private user text and accepts legacy matching retries',()=>{
 const support=definition('support_action');
 assert.match(support,/encode\(sha256\(convert_to\(jsonb_build_object\('action',p_action,'data',p_data\)::text,'UTF8'\)\),'hex'\)/);
 assert.doesNotMatch(support,/payload:=jsonb_build_object\('action',p_action,'data',p_data\)/);
 assert.match(support,/prev\.payload<>jsonb_build_object\('action',p_action,'data',p_data\)/);
 assert.match(support,/insert into public\.support_messages\(ticket_id,author_id,body\)/);
});

test('migration preserves business decisions and never zeroes diamonds or distributes salaries',()=>{
 assert.match(definition('agency_action'),/host_agency\.open/);
 assert.match(definition('agency_action'),/phase3\.can_manage_agency/);
 assert.match(definition('recharge_action'),/phase3\.is_owner/);
 assert.doesNotMatch(sql,/\bTRUNCATE\b|\bDROP\s+TABLE\b|\bDELETE\s+FROM\s+public\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+public\.wallets\s+SET\s+diamonds\s*=\s*0\b/i);
});
