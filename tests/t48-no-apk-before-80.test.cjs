'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),{spawnSync}=require('node:child_process');
const wf=fs.readFileSync('.github/workflows/phase2-android-beta.yml','utf8');
const gate=fs.readFileSync('scripts/t48-apk-readiness-gate.cjs','utf8');
test('T48 no push auto-build; release review is mandatory before JDK/Gradle',()=>{
 assert(!/\n\s*push:\s*\n/.test(wf));
 assert(wf.includes('workflow_dispatch:'));
 assert(wf.includes('node scripts/t48-apk-readiness-gate.cjs'));
 assert(wf.indexOf('t48-apk-readiness-gate.cjs')<wf.indexOf('actions/setup-java'));
 assert(gate.includes("OWNER_REVIEW!=='APPROVED'"));
});
test('T48 both app engineering and real beta readiness >=80, with recovery & two phones',()=>{
 assert(gate.includes('report.engineering_percent<80'));
 assert(gate.includes('report.beta_readiness_percent<80'));
 assert(gate.includes("verified.length<40"), '40 of 50 live verified tasks mandatory');
 for(const key of ['production_backup_restore','storage_object_backup_restore','two_physical_android_phones','financial_conservation_and_month_close'])
  assert(gate.includes(key));
});
test('T48 currently denies APK even if someone manually enters APPROVED',()=>{
 const p=spawnSync(process.execPath,['scripts/t48-apk-readiness-gate.cjs'],{
  env:{...process.env,OWNER_REVIEW:'APPROVED'},encoding:'utf8'});
 assert.notEqual(p.status,0,'Cannot generate APK until release evidence exists');
 assert.match(p.stderr,/BLOCKED T48 APK release gate/);
});
