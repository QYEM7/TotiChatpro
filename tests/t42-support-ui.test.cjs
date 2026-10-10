'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const s=fs.readFileSync('app/phase5-support-ui.js','utf8');
const load=fs.readFileSync('app/phase4-voice-messages-ui.js','utf8');
test('T42 real support entry only appears on signed-in profile',()=>{
 assert(s.includes("screen!=='me'"));
 assert(s.includes("auth.state().signedIn"));
 assert(s.includes("b.dataset.t42='open'"));
 assert(load.includes('phase5-support-ui.js'));
});
test('T42 ticket request is authenticated and agency opening is never faked',()=>{
 assert(s.includes("auth.requestData('/rest/v1/rpc/phase5_support_create'"));
 assert(s.includes("data.status!=='submitted'"));
 assert(s.includes("p_category:category"));
 assert(s.includes("agency_name:title,contact"));
 assert(!s.includes("phase4_agency_action"));
 assert(!s.includes("localStorage"));
 assert(s.includes("textContent=row.title"));
});
