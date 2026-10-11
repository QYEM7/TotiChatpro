import test from 'node:test';
import assert from 'node:assert/strict';
import {checkRepository,verifyDevelopmentMode} from '../scripts/check-development-only-mode.mjs';
import {readFileSync} from 'node:fs';
test('Owner cancels launch gating for development without authorizing any release',()=>{
 const r=checkRepository();
 assert.equal(r.valid,true,r.errors.join('\n'));
 assert.equal(r.development_allowed,true);
 assert.equal(r.mode,'development_only');
 assert.equal(r.builds_allowed,false);
 assert.equal(r.deployment_allowed,false);
 assert.equal(r.historical_checks,23);
});
test('cancelled launch gates do not silently become release approval',()=>{
 const p=JSON.parse(readFileSync(new URL('../docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json',import.meta.url),'utf8'));
 assert.equal(p.release_allowed,false);
 assert.equal(p.launch_conditions_active,false);
 assert(p.gates.every(g=>g.required===false));
 assert(p.gates.some(g=>g.passed===false),'unverified work must remain visible');
 assert.equal(p.apk_aab_build_allowed,false);
});
test('staging source QA still runs security and source tests, not compiled artifacts',()=>{
 const read=name=>readFileSync(new URL('../.github/workflows/'+name,import.meta.url),'utf8');
 const qa=read('comprehensive-staging-qa.yml');
 const full=read('t03-full-stack.yml');
 assert(qa.includes('Run ALL offline repository test files sequentially'));
 assert(qa.includes('Audit committed secrets'));
 assert(full.includes('Launch disposable local Auth, REST, Storage and PostgreSQL services'));
 assert(qa.includes('if: ${{ false }}'));
 assert(read('phase2-android-beta.yml').includes('if: ${{ false }}'));
});
test('accidentally re-enabling an APK or deploy job fails the policy validator',()=>{
 const policy=JSON.parse(readFileSync(new URL('../docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json',import.meta.url),'utf8'));
 const paths=['live-preview-staging','comprehensive-staging-qa','royal-preview-qa','phase2-android-beta','free-landing-preview'];
 const flows=Object.fromEntries(paths.map(n=>['.github/workflows/'+n+'.yml',
  readFileSync(new URL('../.github/workflows/'+n+'.yml',import.meta.url),'utf8')]));
 const changed={...flows};
 changed['.github/workflows/phase2-android-beta.yml']=flows['.github/workflows/phase2-android-beta.yml']
  .replace('    if: ${{ false }}\n    runs-on:','    runs-on:');
 const r=verifyDevelopmentMode(policy,changed);
 assert.equal(r.valid,false);
 assert(r.errors.some(s=>s.includes('build-android-debug')));
});
