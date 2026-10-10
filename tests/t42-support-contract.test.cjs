'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ui=fs.readFileSync('app/phase5-support-ui.js','utf8');
const loader=fs.readFileSync('app/phase2-security-ui.js','utf8');
const sql=fs.readFileSync('supabase/migrations/20261010171000_t42_support_tickets.sql','utf8');
const local=fs.readFileSync('supabase/tests/t42_support_tickets.sql','utf8');
test('T42 ticket RPCs demand real signed-in session and do not fabricate records',()=>{
 assert.match(ui,/auth\.requestData\('\/rest\/v1\/rpc\/phase5_support_/);
 assert.match(ui,/auth\.state\(\)\.signedIn/);
 assert(!ui.includes('localStorage')&&!ui.includes('demoTickets'));
 assert(ui.includes("if(!response?.id)throw Error"));
 assert(ui.includes("pending={signature,key:crypto.randomUUID()}"));
});
test('T42 support entry keeps original approved HTML unchanged',()=>{
 assert(loader.includes("support.dataset.supportOpen=''"));
 assert(loader.includes('phase5-support-ui.js?v=t42-real-support'));
 assert(!fs.readFileSync('app/index.html','utf8').includes('phase5-support-ui.js'));
});
test('T42 private support tables, scoped RPC, owner-only staff assignment and audit redaction',()=>{
 for(const table of ['support_tickets','support_messages','support_staff','support_requests']){
  assert(sql.includes('alter table phase3.'+table+' enable row level security'));
 }
 assert(sql.includes('revoke all on phase3.support_staff'));
 assert(sql.includes('revoke all on function public.phase5_support_list'));
 assert(sql.includes("if not is_owner then raise exception 'Owner alone grants support access'"));
 assert(sql.includes('phase3.actor()')&&sql.includes('phase3.is_owner()'));
 assert(sql.includes('t.creator_id<>u and not staff'));
 assert(sql.includes('old.payload<>payload'));
 assert(sql.includes("body,message_text")===false);
 assert(sql.includes("jsonb_build_object('id',outcome->>'id','request_id',p_request_id)"));
});
test('T42 full PostgreSQL 5-account evidence is rollback-only',()=>{
 assert(/(?:^|\n)begin;/i.test(local));
 assert(local.includes('rollback;'));
 assert(local.includes('T42 outsider read ticket thread'));
 assert(local.includes('T42 staff self-escalated'));
 assert(local.includes('T42 revoked agent'));
 assert(local.includes('T42 idempotency replay'));
});
