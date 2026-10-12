import test from 'node:test';
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
 assert.match(rooms,/p\.is_muted===true\?'المايك مكتوم':'غير مكتوم'/);
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
 assert.doesNotMatch(rooms,/tc-mic-speaking|Math\.random/);
});
test('no new role tiers, unauthorized remote actions or fake member data are added',()=>{
 assert.doesNotMatch(css,/(?:@keyframes|animation\s*:.*infinite)/);
 assert.doesNotMatch(css,/(?:position\s*:\s*fixed|height\s*:\s*100dvh)/);
 assert.match(css,/max-width:355px/);
 assert.match(css,/max-height:590px/);
 assert.match(css,/tc-mic-owner-mark/);
 assert.match(css,/tc-mic-indicator/);
});
