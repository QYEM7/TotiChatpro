'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const json=p=>JSON.parse(read(p));
test('zero-budget static site builds from approved falcon without generating APK',()=>{
 const run=spawnSync(process.execPath,['scripts/build-free-landing.mjs'],{cwd:root,encoding:'utf8',timeout:30000});
 assert.equal(run.status,0,run.stderr+run.stdout);
 const expected=['dist-free-site/index.html','dist-free-site/privacy.html','dist-free-site/_headers','dist-free-site/brand/falcon.jpg'];
 for(const name of expected)assert.ok(fs.statSync(path.join(root,name)).size>0,name);
 assert.deepEqual(fs.readFileSync(path.join(root,'dist-free-site/brand/falcon.jpg')),
  fs.readFileSync(path.join(root,'assets/images/toti_falcon_logo_1790422919580.jpg')));
 assert.ok(!fs.existsSync(path.join(root,'dist-free-site/app-debug.apk')));
});
test('site never publishes a working APK link or fictitious released binaries',()=>{
 const html=read('site/index.html');
 assert.match(html,/<html lang="ar" dir="rtl">/);
 assert.match(html,/تحميل نسخة Android غير متاح حالياً/);
 assert.doesNotMatch(html,/<a[^>]+href=["'][^"']+\.apk/gi);
 assert.doesNotMatch(html,/firebaseapp\.com|supabase\.co\/auth/i);
 assert.doesNotMatch(html,/<script/i);
 assert.match(html,/brand\/falcon\.jpg/);
});
test('free services must be explicit, paid default DISABLED and unrelated DBs deferred',()=>{
 const p=json('docs/free-tier-service-policy.json'),s=json('docs/beta30-scope.json');
 assert.equal(p.budget_usd_now,0);
 assert.equal(p.paid_activation_authorized,false);
 assert.equal(s.budget_usd_now,0);
 for(const name of ['supabase','google_oauth','livekit','firebase_fcm','cloudflare_pages','github_actions','github_releases','encrypted_backups']){
  const service=p.services.find(x=>x.id===name);
  assert.ok(service,name);
  assert.ok(service.doc.startsWith('https://'),name);
  assert.ok(service.stage&&service.caveat&&service.purpose,name);
 }
 for(const name of ['cloudflare_r2','firebase_storage'])
  assert.equal(p.services.find(x=>x.id===name).enable_now,false);
 assert.equal(p.services.find(x=>x.id==='livekit').enable_now,false);
 assert.equal(p.services.find(x=>x.id==='github_releases').enable_now,false);
});
test('the downloadable beta is still blocked by exact official release gate',()=>{
 const report=json('docs/release-readiness.json');
 assert.equal(report.release_allowed,false);
 assert.ok(report.engineering_percent<80);
 assert.ok(report.beta_readiness_percent<80);
 const scope=json('docs/beta30-scope.json');
 assert.equal(scope.release_allowed,false);
 const gate=read('scripts/t48-apk-readiness-gate.cjs');
 assert.match(gate,/verified.length<40/);
 assert.match(gate,/OWNER_REVIEW!=='APPROVED'/);
});
test('Cloudflare static response headers restrict scripting and third-party embedding',()=>{
 const headers=read('site/_headers');
 assert.match(headers,/X-Content-Type-Options: nosniff/);
 assert.match(headers,/default-src 'none'/);
 assert.match(headers,/frame-ancestors 'none'/);
 assert.match(headers,/form-action 'none'/);
});
