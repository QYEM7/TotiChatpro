import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const get=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const room=get('app/phase2-rooms.js');
const seatCSS=get('app/phase6-mic-presence.css');
const gift=get('app/phase2-catalog-ui.js');
const drawerCSS=get('app/phase6-gift-tray.css');
const loader=get('app/phase2-backend-controls.js');
const auth=get('app/official-auth-screen.js');
const authCSS=get('app/official-auth-screen.css');
const admin=get('app/phase6-inapp-admin.js');
const banner=get('app/home-banners.js');
const bannerAdmin=get('app/phase6-admin-banners.js');
const migration=get('supabase/migrations/20261012131252_verified_room_mic_cosmetics_gift_count_v1.sql');

test('all changed scripts parse and beta extras are loaded without rewriting approved HTML',()=>{
 for(const path of ['app/phase2-rooms.js','app/phase2-catalog-ui.js','app/official-auth-screen.js',
 'app/phase6-inapp-admin.js','app/phase6-admin-banners.js','app/phase2-backend-controls.js'])
  execFileSync(process.execPath,['--check',new URL('../'+path,import.meta.url).pathname]);
 assert.match(loader,/phase6-gift-tray\.css/);
 assert.match(loader,/phase6-mic-presence\.css/);
 const master=get('app/index.html');
 assert.doesNotMatch(master,/phase6-gift-tray\.css|verified_room_mic_cosmetics/);
});
test('mic has verified server-only VIP 1-10 and actually equipped active store frame',()=>{
 assert.match(migration,/Room membership required/);
 assert.match(migration,/phase3\.actor\(\)/);
 assert.match(migration,/phase6_room_mic_decorations/);
 assert.match(migration,/where o\.user_id=m\.user_id and o\.equipped=true/);
 assert.match(migration,/o\.expires_at>now\(\)/);
 assert.match(migration,/c\.is_active=true and c\.category='frames'/);
 assert.match(migration,/v\.tier between 1 and 10/);
 assert.match(migration,/revoke all on function public\.phase6_room_mic_decorations\(uuid\) from public,anon/);
 assert.match(migration,/grant execute on function public\.phase6_room_mic_decorations\(uuid\) to authenticated/);
 assert.match(room,/\/rest\/v1\/rpc\/phase6_room_mic_decorations/);
 assert.match(room,/verifiedMicDecorations=new Map\(\)/);
 assert.match(room,/button\.classList\.toggle\('tc-mic-vip',vip>0\)/);
 assert.match(room,/button\.classList\.toggle\('tc-mic-equipped-frame',!!frame\)/);
 assert.match(room,/vipLabel\.textContent='VIP '\+vip/);
 assert.match(room,/frameMark\.title=frame\.name/);
 assert.match(seatCSS,/tc-seat-vip-tier/);
 assert.match(seatCSS,/tc-seat-equipped-mark/);
 assert.doesNotMatch(seatCSS,/grid-template-columns|grid-template-rows/);
});
test('gift count directly under seat name means completed verified gifts, not random preview',()=>{
 assert.match(migration,/join public\.financial_operations op on op\.id=e\.id/);
 assert.match(migration,/op\.operation='gift' and op\.status='completed'/);
 assert.match(migration,/where e\.room_id=p_room_id and e\.recipient_id=m\.user_id/);
 assert.match(room,/level\.textContent=p\?'🎁 '/);
 assert.match(room,/receivedGifts:Number\.isSafeInteger\(giftCount\)/);
 assert.match(room,/level\.classList\.toggle\('tc-seat-gift-counter',!!p\)/);
 assert.match(room,/totichat-gift-completed/);
 assert.match(room,/verifiedMicDecorations\.clear\(\)/);
});
test('real gift box is a stable partial-height bottom sheet, independent of category',()=>{
 assert.match(gift,/id="tc-real-gift-drawer"/);
 assert.match(gift,/classList\.add\('tc-gift-sheet'\)/);
 for(const part of ['tc-gift-recipients','tc-gift-tabs','tc-gift-scroll','tc-gift-sendbar'])
  assert(gift.includes(part),part);
 assert.match(drawerCSS,/height:min\(67dvh,535px\)!important/);
 assert.match(drawerCSS,/max-height:min\(67dvh,535px\)!important/);
 assert.match(drawerCSS,/flex:1 1 0;min-height:0;height:0/);
 assert.match(drawerCSS,/overflow-y:auto!important/);
 assert.match(gift,/data\.list\('gift_categories'\)/);
 assert.match(gift,/data\.list\('gift_catalog'\)/);
 assert.match(gift,/diamond_source_type==='LUCKY_GIFT'/);
 assert.match(gift,/button\(c\.label,'gift-category',c\.id/);
});
test('sign-in is real, visually coherent and inert providers are not offered',()=>{
 assert.match(auth,/TotiPhase2Auth/);
 assert.match(auth,/tc-login-brand-icon/);
 assert.match(auth,/tc-login-eyebrow/);
 assert.match(auth,/tc-auth-art-features/);
 assert.match(auth,/formElement\.reportValidity\(\)/);
 assert.match(auth,/if\(section\)section\.hidden=enabled===0/);
 assert.match(auth,/b\.disabled=!available;b\.hidden=!available/);
 assert.match(auth,/passwordResetPreview/);
 assert.match(auth,/data-auth-action="toggle-password"/);
 assert.match(authCSS,/tc-login-panel-inner/);
 assert.match(authCSS,/tc-social-section\[hidden\]/);
});
test('banners are real only and refresh after confirmed Owner submission',()=>{
 assert.match(banner,/if\(window\.TotiLiveMode\?\.enabled===true\)return ''/);
 assert.match(banner,/core\.normalize\(results\)/);
 assert.match(bannerAdmin,/outcome\?\.saved!==true/);
 assert.match(bannerAdmin,/window\.TotiBannerData\?\.refresh\?\.\(\)/);
 const guestHero=get('app/royal-visuals.js');
 assert.match(guestHero,/real\?verifiedBanner:/);
});
test('admin center stays inside My/Profile, role-verified, with one consistent SVG icon system',()=>{
 assert.match(admin,/screen!=='me'\)return/);
 assert.match(admin,/phase3_admin_session/);
 assert.match(admin,/phase6_admin_support_access/);
 assert.match(admin,/if\(!rights\)\{removeEntry\(\);return;\}/);
 assert.match(admin,/data-tcac-entry/);
 assert.match(admin,/const iconPaths=Object\.freeze/);
 assert.match(admin,/adminIcon\(item\[0\]\)/);
 assert.doesNotMatch(admin,/window\.location\.href=.*admin/);
});


test('live Home VIP and search controls open real pages and never synthetic room cards',()=>{
 const home=get('app/royal-visuals.js');
 assert.match(home,/data-phase2="search-rooms"/);
 assert.match(home,/data-v="me" aria-label="عرض حالة VIP في ملفي"/);
 assert.match(room,/function displayRealRoomSearch\(\)/);
 assert.match(room,/function paintRealRoomSearch\(\)/);
 assert.match(room,/rooms\.filter\(item=>UUID\.test\(String\(item\.id\)\)/);
 assert.match(room,/btn\.dataset\.phase2='open-room'/);
 assert.match(room,/else if\(kind==='search-rooms'\)/);
 assert.doesNotMatch(room,/Math\.random/);
});
