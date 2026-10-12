import test from 'node:test';
import vmModule from 'node:vm';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const rooms=read('app/phase2-rooms.js');
const css=read('app/phase6-mic-presence.css');
const approved=read('app/index.html');
const loader=read('app/phase2-backend-controls.js');
test('approved room geometry, template and decorative premium frames are not modified',()=>{
 execFileSync(process.execPath,['--check',new URL('../app/phase2-rooms.js',import.meta.url).pathname]);
 assert(!approved.includes('phase6-mic-presence.css'));
 assert.match(loader,/phase6-mic-presence\.css/);
 assert.match(css,/#app\.rf-app\.rf-room \.roomview\.room-v2 \.seats > \.seat\.tc-mic-member/);
 assert.doesNotMatch(css,/grid-template|grid-column|display\s*:\s*none\s*!important\s*;\s*\/\*\s*seat/i);
 assert.match(css,/The 5×3 seat grid/);
 assert.match(css,/prefers-reduced-motion/);
});
test('live roster alone controls occupied avatar, muted icon and owner indicator',()=>{
 assert.match(rooms,/phase2_room_members_visual/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-member',!!p\)/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-muted',!!p&&p\.is_muted===true\)/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-unmuted',!!p&&p\.is_muted===false\)/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-owner',!!p&&p\.user_id===active\.owner_id\)/);
 assert.match(rooms,/Array\.from\(String\(p\.display_name\|\|'مستخدم'\)\.trim\(\)\)\[0\]/);
 assert.match(rooms,/level\.textContent=p\?'🎁 '/);
 assert.match(rooms,/level\.title=p\?'عدد الهدايا الحقيقية المستلمة داخل هذه الغرفة'/);
 assert.match(rooms,/micStatus\.title=p\.is_muted===true/);
 assert.match(rooms,/المايك غير مكتوم/);
 assert.match(rooms,/micStatus\.title=p\.is_muted===true/);
});
test('no mock avatar, fake VIP badge or imaginary active-speaking announcement',()=>{
 assert.match(rooms,/button\.classList\.remove\('vip1','vip5','vip8'\)/);
 assert.match(rooms,/label\.classList\.remove\('vipGold'\)/);
 assert.match(rooms,/realAvatar=url\.href/);
 assert.match(rooms,/image\.style\.setProperty\('display','none','important'\)/);
 assert.match(rooms,/badge\.style\.setProperty\('display','none','important'\)/);
 assert.doesNotMatch(css,/speaking-now|pulse-speaking|voice-level/);
 assert.doesNotMatch(rooms,/Math\.random/);
});
test('no new role tiers, unauthorized remote actions or fake member data are added',()=>{
 assert.match(css,/tc-mic-speaking\.tc-mic-unmuted/);
 assert.match(css,/@keyframes tc-real-mic-speaking/);
 assert.match(css,/prefers-reduced-motion:reduce/);
 assert.doesNotMatch(css,/(?:position\s*:\s*fixed|height\s*:\s*100dvh)/);
 assert.match(css,/max-width:355px/);
 assert.match(css,/max-height:590px/);
 assert.match(css,/tc-mic-owner-mark/);
 assert.match(css,/tc-mic-indicator/);
});

test('speaking highlight must come only from true room LiveKit ActiveSpeakersChanged event',()=>{
 const sdk=read('app/phase2-livekit-sdk.mjs');
 const voice=read('app/phase2-voice-ui.js');
 execFileSync(process.execPath,['--check',new URL('../app/phase2-livekit-sdk.mjs',import.meta.url).pathname]);
 execFileSync(process.execPath,['--check',new URL('../app/phase2-voice-ui.js',import.meta.url).pathname]);
 assert.match(sdk,/RoomEvent\.ActiveSpeakersChanged/);
 assert.match(sdk,/signal\(\{activeSpeakerIds:/);
 assert.match(sdk,/activeSpeakerIds:\[\]/);
 assert.match(voice,/totichat-live-active-speakers/);
 assert.match(voice,/Array\.isArray\(state\.activeSpeakerIds\)/);
 assert.match(rooms,/window\.addEventListener\('totichat-live-active-speakers'/);
 assert.match(rooms,/realSpeakingIds\.has\(p\.user_id\)/);
 assert.match(rooms,/detail\.roomId!==active\.id/);
 assert.match(rooms,/typeof id==='string'&&UUID\.test\(id\)/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-speaking',talking\)/);
 assert.match(rooms,/button\.classList\.toggle\('tc-mic-speaking',!!p&&p\.is_muted===false/);
 assert.doesNotMatch(rooms,/setInterval\([^;]*classList\.add\('tc-mic-speaking'/);
});


test('real LiveKit speaker event updates each seat without iterating a single element',()=>{
 const vm=vmModule;
 const start=rooms.indexOf("window.addEventListener('totichat-live-active-speakers',event=>{");
 assert.notEqual(start,-1,'speaking event handler exists');
 const end=rooms.indexOf("\n});",start);
 assert.ok(end>start);
 const handler=rooms.slice(start,end+4);
 const roomId='11111111-1111-4111-8111-111111111111';
 const speaker='22222222-2222-4222-8222-222222222222';
 const silent='33333333-3333-4333-8333-333333333333';
 const muted='44444444-4444-4444-8444-444444444444';
 const seat=(id,isMuted=false)=>{
  const flags=new Set(isMuted?[]:['tc-mic-unmuted']);
  return {
   dataset:{tcMicOccupant:id,tcMicAriaBase:'Real seat'},
   classList:{
    contains:name=>flags.has(name),
    toggle:(name,enabled)=>{if(enabled)flags.add(name);else flags.delete(name)}
   },
   setAttribute:()=>{},
   isSpeaking:()=>flags.has('tc-mic-speaking')
  };
 };
 const seats=[seat(speaker),seat(silent),seat(muted,true),seat('')];
 const listeners={};
 const window={addEventListener:(name,fn)=>{listeners[name]=fn}};
 vm.runInNewContext("let realSpeakerRoom='';let realSpeakingIds=new Set();\n"+handler,{
  window,session:()=>({signedIn:true}),active:{id:roomId},screen:'room',
  UUID:/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
  $$:selector=>{assert.ok(selector.includes('.seats'));return seats;},
  $:()=>{throw Error('single-element selector cannot supply all 15 seats')}
 });
 const dispatch=userIds=>listeners['totichat-live-active-speakers']({detail:{roomId,userIds}});
 dispatch([speaker,muted]);
 assert.deepEqual(seats.map(s=>s.isSpeaking()),[true,false,false,false]);
 dispatch([]);
 assert.deepEqual(seats.map(s=>s.isSpeaking()),[false,false,false,false]);
});


test('unjoined room cleanup iterates every seat, not a single DOM element',()=>{
 assert.ok(rooms.includes("for(const [index,button] of $$('.seats .seat',view).entries()){"));
 assert.ok(!rooms.includes("for(const [index,button] of $('.seats .seat',view).entries()){"));
});
