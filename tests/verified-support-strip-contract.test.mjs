import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

const load=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const global=load('app/phase2-global-gifts.js');
const rooms=load('app/phase2-rooms.js');
const live=load('app/phase2-live-mode.js');
const royal=load('app/royal-visuals.js');
const final=load('app/royal-final.js');
const admin=load('app/phase2-backend-controls.js');
const migration=load('supabase/migrations/20261012124921_verified_support_strips_min_7000.sql');

function checker(){
  const begin=global.indexOf('const MIN_REAL_SUPPORT_COINS=');
  const end=global.indexOf('\nfunction title',begin);
  assert.ok(begin>0&&end>begin,'explicit verified-gift validation function is present');
  return vm.runInNewContext(
    '(()=>{const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;'+
    global.slice(begin,end)+';return valid;})()'
  );
}
const one='11111111-1111-4111-8111-111111111111';
const two='22222222-2222-4222-8222-222222222222';
const three='33333333-3333-4333-8333-333333333333';
const four='44444444-4444-4444-8444-444444444444';
const row=(unit_price,quantity,more={})=>({
  id:one,room_id:two,sender_id:three,recipient_id:four,
  gift_id:'g1',unit_price,quantity,total_coins:unit_price*quantity,
  created_at:new Date().toISOString(),...more
});

test('public ticker requires a genuine well-formed gift event with >=7000 total coins',()=>{
 const valid=checker();
 assert.equal(valid(row(6999,1)),false);
 assert.equal(valid(row(7000,1)),true);
 assert.equal(valid(row(7001,1)),true);
 assert.equal(valid(row(1000,7)),true);
 assert.equal(valid(row(10,777)),true);
 assert.equal(valid(row(500,7)),false);
 assert.equal(valid(row(7000,1,{total_coins:7001})),false);
 assert.equal(valid(row(7000,1,{sender_id:'invalid'})),false);
 assert.equal(valid(row(7000,1,{quantity:0})),false);
});
test('old or future activity never masquerades as current confirmed support',()=>{
 const valid=checker();
 assert.equal(valid(row(7000,1,{created_at:new Date(Date.now()-6*60*1000).toISOString()})),false);
 assert.equal(valid(row(7000,1,{created_at:new Date(Date.now()+60*1000).toISOString()})),false);
 assert.equal(valid(row(7000,1,{created_at:'invalid'})),false);
});
test('no verified support means no gift strip, placeholder, image or ticker loop',()=>{
 assert.match(global,/ticker\.hidden=!current/);
 assert.match(global,/ticker\.style\.display=current\?'':'none'/);
 assert.match(global,/const current=rows\.find\(valid\)\|\|null/);
 assert.match(global,/total_coins=gte\.'\+MIN_REAL_SUPPORT_COINS/);
 assert.match(global,/created_at=gte\.'\+encodeURIComponent\(since\)/);
 assert.match(global,/rows=\[\];refreshTicker\(\)/);
 assert.match(rooms,/giftTicker\.hidden=true;giftTicker\.style\.display='none'/);
 assert.match(royal,/if\(window\.TotiLiveMode\?\.enabled\)\{/);
});
test('Owner config and backend must not allow amounts under 7000',()=>{
 assert.match(admin,/name="minPrice" min="7000"/);
 assert.match(admin,/price<7000/);
 assert.match(migration,/check\(total_coins>=7000\)/);
 assert.match(migration,/check\(min_gift_price is null or min_gift_price>=7000\)/);
 assert.match(migration,/new\.amount < greatest\(7000::bigint,cfg\.min_gift_price\)/);
 assert.match(migration,/sender_ledger\.amount_change=-new\.amount/);
 assert.match(migration,/recipient_ledger\.amount_change=new\.amount/);
 assert.match(migration,/op\.status='completed'/);
 assert.match(migration,/global_announcement_enabled=true/);
});
test('authenticated rooms do not announce fabricated LIVE/Owner or show preview phone status',()=>{
 assert.match(final,/if\(!real\|\|verified\?\.isOwner===true\)/);
 assert.match(final,/if\(!real\)\{const events=/);
 assert.match(live,/#app > \.status,#app > \.previewflag/);
 assert.match(live,/const sampleDonor=\$\('\.pr-event img'\)/);
});

test('legacy demo room/mic/friend interactions are never mounted on live or Android',()=>{
 const module=load('app/room-ui-enhancements.js');
 const artwork=load('app/royal-final.js');
 const agency=load('app/agency-hub.js');
 const vip=load('app/royal-vip15.js');
 assert.match(module,/if\(liveSource\)return/);
 assert.match(module,/location\.search\)\.get\('mode'\)==='live'/);
 assert.match(module,/TotiLivePreviewOnly/);
 assert.match(artwork,/if\(!authenticatedApp&&params\.get\('review'\)==='1'\)/);
 assert.match(agency,/if\(liveSource\)return/);
 assert.match(vip,/if\(liveSource\)return/);
 assert.match(live,/المعاينة التجريبية غير متاحة داخل التطبيق الحقيقي/);
 assert.doesNotMatch(live,/explicitPreview=true;go\('home'\)/);
});
