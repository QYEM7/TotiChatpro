import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {auditGate} from '../scripts/check-backend-prelaunch.mjs';
const evidence=JSON.parse(readFileSync(new URL('../docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json',import.meta.url),'utf8'));
test('release remains blocked by actual missing SFU, Android and approved payroll proof',()=>{
 const r=auditGate(evidence);
 assert.equal(r.valid,true);
 assert.equal(r.release_allowed,false);
 assert(r.blocked.includes('live_voice_two_phones'));
 assert(r.blocked.includes('monthly_host_payroll_conservation'));
 assert(r.blocked.includes('android_reinstall_update'));
});
test('claims of beta release fail when a required gate is still blocked',()=>{
 const r=auditGate({...evidence,release_allowed:true,reviewer:'QA-reviewer',reviewer_approved_at:'2026-10-11'});
 assert.equal(r.valid,false);
});
test('passing an evidence gate without an HTTPS evidence URL is refused',()=>{
 const gates=evidence.gates.map(g=>({...g}));
 gates[0].evidence='unverified';
 const r=auditGate({...evidence,gates});
 assert.equal(r.valid,false);
 assert(r.errors.some(x=>x.includes('link')));
});
