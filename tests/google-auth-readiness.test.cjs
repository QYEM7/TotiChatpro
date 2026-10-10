'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
let modulePromise;
const sdk=()=>modulePromise??=import('../scripts/inspect-google-auth-readiness.mjs');
const cfg=fs.readFileSync('app/config.js','utf8');
test('public key only, Supabase allowed host only; never use private server key',async()=>{
 const {readPublicBackend}=await sdk();
 const s=readPublicBackend(cfg);
 assert.equal(s.url,'https://sqedsnyvjblvbjbizcay.supabase.co');
 assert.ok(s.key.startsWith('sb_publishable_'));
 assert.throws(()=>readPublicBackend('supabaseUrl:"https://evil.example.com",publishableKey:"sb_publishable_fake"'),/non-Supabase/);
 assert.throws(()=>readPublicBackend('supabaseUrl:"https://sqedsnyvjblvbjbizcay.supabase.co",publishableKey:"sb_secret_fake"'),/publishable/);
});
test('Google provider OFF blocks readiness even if other providers are enabled',async()=>{
 const {inspect}=await sdk();
 const res=await inspect({configText:cfg,fetchImpl:async(url,opt)=>{
  assert.ok(url.endsWith('/auth/v1/settings'));
  assert.equal(opt.method,'GET');
  assert.ok(opt.headers.apikey.startsWith('sb_publishable_'));
  return {ok:true,json:async()=>({external:{google:false,apple:true,facebook:true}})};
 }});
 assert.equal(res.google,false);
 assert.equal(res.readiness,'blocked_google_provider_disabled');
});
test('Google flag ON is only provider setup, never fake Android session verification',async()=>{
 const {summarizeFlags}=await sdk();
 assert.deepEqual(summarizeFlags({external:{google:true,apple:false,facebook:false}}),
 {google:true,apple:false,facebook:false,readiness:'google_provider_enabled_callback_unverified'});
 assert.equal(summarizeFlags({}).readiness,'unverified');
});
test('read-only errors do not fall back to fake success',async()=>{
 const {inspect}=await sdk();
 await assert.rejects(()=>inspect({configText:cfg,fetchImpl:async()=>({ok:false,status:401})}),/HTTP 401/);
});
