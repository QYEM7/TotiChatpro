import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';
const read=p=>readFileSync(p,'utf8');
test('rebuild replaces old UI with clean entry',()=>{
 const html=read('app/index.html');
 assert.match(html,/reborn\/core\.js/);
 assert.match(html,/reborn\/features\.js/);
 assert.match(html,/reborn\/styles\.css/);
 for(const legacy of ['royal-final.js','toti-nav-banner-refine.js','frontend-finish.js','official-auth-screen.js','phase2-rooms.js'])
  assert.ok(!html.includes(legacy),'Legacy frontend still loaded: '+legacy);
});
test('only real Google provider offered on login',()=>{
 const code=read('app/reborn/core.js');
 assert.ok(code.includes("auth.signInWithProvider('google')"));
 assert.ok(!code.includes("signInWithProvider('facebook')"));
 assert.ok(!code.includes("signInWithProvider('apple')"));
 assert.ok(!code.includes("grant_type=password"));
});
test('15 seats and fail-closed wallet/gifts',()=>{
 const core=read('app/reborn/core.js');
 const features=read('app/reborn/features.js');
 assert.match(core,/length:15/);
 assert.match(features,/phase3_send_gift/);
 assert.match(features,/phase3_purchase_store/);
 assert.match(features,/diamond_source_type==='LUCKY_GIFT'/);
 assert.match(core,/phase2_room_take_seat/);
 assert.match(core,/microphone\(false\)/);
});
test('all new controller scripts parse',()=>{
 new vm.Script(read('app/reborn/core.js'),{filename:'app/reborn/core.js'});
 new vm.Script(read('app/reborn/features.js'),{filename:'app/reborn/features.js'});
 new vm.Script(read('app/phase2-auth.js'),{filename:'app/phase2-auth.js'});
});
test('no fake financial fixtures or sample rooms in new UI',()=>{
 const text=read('app/reborn/core.js')+read('app/reborn/features.js');
 for(const bad of ['vipDemoBalance','rdata.map','previewProfileName','wallet=50000','demoChat','faker'])
   assert.ok(!text.includes(bad),bad+' prohibited');
});
test('rebuild uses staging public backend and original audio SDK source',()=>{
 assert.match(read('app/config.js'),/rziaedugbdwefbefcxjt/);
 assert.ok(existsSync('app/phase2-livekit-sdk.mjs'));
 assert.ok(read('scripts/build-reborn-web.mjs').includes('phase2-livekit-sdk.mjs'));
});

test('old UI deleted from active branch and root loads Reborn',()=>{
 for(const file of ['app/royal-final.js','app/frontend-finish.js','app/toti-nav-banner-refine.js',
  'app/official-auth-screen.js','app/phase2-rooms.js','admin-dashboard/index.html'])
  assert.equal(existsSync(file),false,'Legacy UI still present: '+file);
 const root=read('index.html');
 assert.match(root,/reborn\/core\.js/);
 assert.match(root,/<base href="\.\/app\/">/);
});
