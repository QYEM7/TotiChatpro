import test from 'node:test';
import assert from 'node:assert/strict';
import {detectCredential,auditTrackedFiles} from '../scripts/t03-secret-audit.mjs';
test('T03 blocks accidental private dotenv, keys and actual key patterns',()=>{
 for(const p of ['.env','.env.staging','.env.production','secrets/private.pem','android/release.jks','secret.key']){
  assert.equal(detectCredential(p,'x'),'credential-file');
 }
 assert.equal(detectCredential('app/config.js','let k="'+('sb_'+'secret_'+'Z'.repeat(25))+'";'),'supabase-secret');
 assert.equal(detectCredential('.env.example','LIVEKIT_API_SECRET=hardcoded'),'nonempty-private-template');
});
test('T03 permits empty template, public publishable key and benign test code',()=>{
 assert.equal(detectCredential('.env.example','LIVEKIT_API_SECRET=\nSUPABASE_SERVICE_ROLE_KEY=\n'),null);
 assert.equal(detectCredential('app/config.js','window.key="sb_publishable_examplepublic"'),null);
 assert.equal(detectCredential('tests/some.cjs','const svc="service_role";'),null);
});
test('T03 scans the actual committed repository paths, not installed dependencies',()=>{
 const a=auditTrackedFiles();
 assert(a.filesScanned>=100,'Repository tree unexpectedly short');
 assert.deepEqual(a.findings,[],'Private material detected: filenames only');
});
