#!/usr/bin/env node
'use strict';
// T48 hard release gate: prevents APK/AAB builds below 80% without release evidence.
// The development stage is intentionally DENY by default. Do not edit the percentages
// merely to bypass the gate: evidence links must be reviewed independently.
const fs=require('node:fs');
const path=require('node:path');
const file=path.join(process.cwd(),'docs/release-readiness.json');
function fail(msg){console.error('BLOCKED T48 APK release gate: '+msg);process.exit(1);}
if(process.env.OWNER_REVIEW!=='APPROVED')fail('Explicit Owner approval is required.');
if(!fs.existsSync(file))fail('Missing independently reviewed docs/release-readiness.json.');
let report;
try{report=JSON.parse(fs.readFileSync(file,'utf8'));}catch(e){fail('Invalid readiness evidence JSON.');}
if(report.release_allowed!==true)fail('Release approval remains explicitly disabled.');
if(report.project!=='TotiChatpro'||report.branch!=='develop/phase-2')
  fail('Unexpected repository or branch in readiness declaration.');
if(!Number.isFinite(report.engineering_percent)||report.engineering_percent<80||report.engineering_percent>100)
  fail('Engineering implementation is below 80%.');
if(!Number.isFinite(report.beta_readiness_percent)||report.beta_readiness_percent<80||report.beta_readiness_percent>100)
  fail('Real-world beta readiness is below 80%.');
// An entered percentage is insufficient: 40 of 50 tasks require live verification.
let tasks;
try { tasks=JSON.parse(fs.readFileSync(path.join(process.cwd(),'docs/50-task-verification.json'),'utf8')); }
catch(e) { fail('Missing 50-task verification ledger.'); }
if(!Array.isArray(tasks)||tasks.length!==50)fail('Expected 50 reviewed tasks.');
const verified=tasks.filter(t=>t.status==='verified_live'&&typeof t.evidence==='string'&&t.evidence.length>=45);
if(verified.length<40)fail('Only '+verified.length+'/50 tasks verified live; need 40 or more.');
const required=['production_backup_restore','independent_staging','real_auth_two_users',
  'two_physical_android_phones','live_voice_and_moderation','financial_conservation_and_month_close',
  'account_agency_security','full_mobile_regression'];
if(!report.evidence||typeof report.evidence!=='object')fail('Missing evidence.');
for(const field of required){
 const rec=report.evidence[field];
 if(rec?.passed!==true||typeof rec.url!=='string'||
   !/^https:\/\/(github\.com|supabase\.com)\//.test(rec.url)||
   typeof rec.notes!=='string'||rec.notes.trim().length<15){
     fail(field+' has no independently reviewable proof.');
 }
}
if(!report.reviewer||report.reviewer.trim().length<3)
  fail('Missing release reviewer.');
if(!/^\d{4}-\d{2}-\d{2}$/.test(report.verified_date||''))
  fail('Missing verified date.');
console.log('PASS T48: 80% engineering AND 80% beta readiness, Owner approved, reviewable evidence recorded.');
