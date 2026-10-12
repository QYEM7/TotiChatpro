import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const royal=read('app/royal-visuals.js');
const room=read('app/phase2-rooms.js');
const live=read('app/phase2-live-mode.js');
const banner=read('app/home-banners.js');
const global=read('app/phase2-global-gifts.js');
const build=read('scripts/build-registered-staging-preview.mjs');
const preview=read('scripts/build-live-preview.mjs');

test('live home never renders reference rooms or invented nearby counts',()=>{
 assert.match(royal,/const real=window\.TotiLiveMode\?\.enabled===true&&window\.TotiPhase2Auth\?\.state\(\)\?\.signedIn===true/);
 assert.match(royal,/real\?'':roomItems\.map\(roomCard\)/);
 assert.match(royal,/real\?'':near\.map/);
 assert.match(royal,/real\?verifiedBanner:/);
 assert.match(royal,/TotiBannerData\?\.getItems\?\.\(\)\.length>0/);
 assert.match(room,/roomListError/);
 assert.match(room,/rooms===null/);
 assert.match(room,/rooms\.map\(\(r,i\)=>/);
 assert.match(room,/assets\.logo/);
});
test('no empty advertising placeholders or fabricated activity ribbon in real mode',()=>{
 assert.match(banner,/if\(window\.TotiLiveMode\?\.enabled===true\)return ''/);
 assert.match(banner,/!state\.items\.length\)return window\.TotiLiveMode\?\.enabled===true\?'':/);
 assert.match(royal,/if\(window\.TotiLiveMode\?\.enabled\)\{/);
 assert.match(global,/ticker\.style\.display=current\?'':'none'/);
 assert.match(global,/gift_global_announcements/);
 assert.match(live,/if\(state\.signedIn\)\{protectIdentity\(\);\}/);
 assert.doesNotMatch(live,/tc-phase2-online-state/);
});
test('manual web preview is real-only, using public Staging and no production credentials',()=>{
 assert.match(preview,/history\.replaceState/);
 assert.match(preview,/TotiLivePreviewOnly/);
 assert.match(build,/rziaedugbdwefbefcxjt/);
 assert.match(preview,/PRODUCTION_SUPABASE_URL/);
 assert.match(preview,/restrictDemoChoice/);
});
