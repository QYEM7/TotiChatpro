'use strict';
// T48 boundary test of the real release gate with synthetic data in OS temp.
// No build, no APK, no production/project data, no real release approval.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const gate=path.resolve('scripts/t48-apk-readiness-gate.cjs');
const required=['production_backup_restore','storage_object_backup_restore',
  'independent_staging','real_auth_two_users','two_physical_android_phones',
  'live_voice_and_moderation','financial_conservation_and_month_close',
  'account_agency_security','full_mobile_regression'];
function verify({engineering=80,beta=80,allowed=true,review='APPROVED'}={}){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'totichat-t48-unit-only-'));
 try{
  fs.mkdirSync(path.join(dir,'docs'));
  const evidence=Object.fromEntries(required.map(key=>[key,{
   passed:true,url:'https://github.com/example/synthetic-not-real-evidence',
   notes:'Synthetic threshold test only; this is not real approval or live evidence.'
  }]));
  fs.writeFileSync(path.join(dir,'docs','release-readiness.json'),JSON.stringify({
   project:'TotiChatpro',branch:'develop/phase-2',engineering_percent:engineering,
   beta_readiness_percent:beta,release_allowed:allowed,evidence,
   reviewer:'Synthetic unit test reviewer',verified_date:'2026-10-10'
  }));
  fs.writeFileSync(path.join(dir,'docs','50-task-verification.json'),JSON.stringify(
   Array.from({length:50},(_,i)=>({
    id:'T'+String(i+1).padStart(2,'0'),status:'verified_live',
    evidence:'Synthetic T48 boundary fixture — NOT a live QA result, not for production use.'
   }))
  ));
  return spawnSync(process.execPath,[gate],{cwd:dir,
   env:{...process.env,OWNER_REVIEW:review},encoding:'utf8',timeout:10000});
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
}
test('T48 real gate DENIES APK if engineering is 79% even when beta is 100%',()=>{
 const r=verify({engineering:79,beta:100});
 assert.notEqual(r.status,0);
 assert.match(r.stderr,/Engineering implementation is below 80%/);
});
test('T48 real gate DENIES APK if beta is 79% even when engineering is 100%',()=>{
 const r=verify({engineering:100,beta:79});
 assert.notEqual(r.status,0);
 assert.match(r.stderr,/Real-world beta readiness is below 80%/);
});
test('T48 real gate denies fractional percentages less than 80 on either side',()=>{
 for(const bad of [{engineering:79.99,beta:100},{engineering:100,beta:79.99}]){
  const r=verify(bad);
  assert.notEqual(r.status,0);
  assert.match(r.stderr,/below 80%/);
 }
});
test('T48 >=80 AND >=80 is necessary, but explicit release and Owner review still mandatory',()=>{
 for(const scores of [{engineering:80,beta:80},{engineering:80,beta:100},
   {engineering:100,beta:80}]){
  const noRelease=verify({...scores,allowed:false});
  assert.notEqual(noRelease.status,0);
  assert.match(noRelease.stderr,/Release approval remains explicitly disabled/);
  const noOwner=verify({...scores,review:'DENIED'});
  assert.notEqual(noOwner.status,0);
  assert.match(noOwner.stderr,/Explicit Owner approval/);
  // Pure gate-unit positive control ONLY. This creates no APK and touches no real readiness.
  const synthetic=verify(scores);
  assert.equal(synthetic.status,0,synthetic.stderr);
  assert.match(synthetic.stdout,/PASS T48/);
 }
});
test('T48 uses the actual current readiness file to deny APK today',()=>{
 const r=spawnSync(process.execPath,[gate],{
  env:{...process.env,OWNER_REVIEW:'APPROVED'},encoding:'utf8',timeout:10000
 });
 assert.notEqual(r.status,0);
 assert.match(r.stderr,/BLOCKED T48 APK release gate/);
});
