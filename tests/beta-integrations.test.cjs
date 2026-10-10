'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
test('integration preflight verifies source only and cannot authorize APK or claim phone tests',()=>{
 const result=spawnSync(process.execPath,['scripts/check-beta-integrations.mjs','--strict-source'],{
  cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:20000
 });
 assert.equal(result.status,0,result.stderr);
 const r=JSON.parse(result.stdout);
 assert.equal(r.source_contracts_ok,true);
 assert.equal(r.google.real_login_passed,false);
 assert.equal(r.livekit.two_phone_audio_passed,false);
 assert.equal(r.livekit.hosted_function_parity,'UNVERIFIED');
 assert.equal(r.firebase.android_registered,true);
 assert.equal(r.firebase.real_fcm_passed,false);
 assert.equal(r.release.apk_authorized,false);
 assert.equal(r.release.release_allowed,false);
 assert.ok(r.migrations.github_sql_files>=32);
 assert.ok(r.release.missing_proofs.includes('two_physical_android_phones'));
 assert.doesNotMatch(result.stdout,/sb_publishable_|service_role|private_key|AIza[0-9A-Za-z_-]{20}/);
});
