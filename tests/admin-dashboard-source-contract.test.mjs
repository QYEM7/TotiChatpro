import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
const load=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const html=load('../admin-dashboard/index.html');
const css=load('../admin-dashboard/styles.css');
const js=load('../admin-dashboard/app.js');
const management=load('../admin-dashboard/management.js');
const db=load('../supabase/migrations/20261012001500_admin_banner_images_stage.sql');
const fix=load('../supabase/migrations/20261012002000_admin_banner_actor_fix.sql');
test('isolated admin shell preserves consumer app and embeds the exact falcon',()=>{
 const mobile=load('../app/index.html');
 assert.match(html,/dir="rtl"/);
 assert.match(html,/TotiChat/);
 assert.match(html,/\.\/assets\/toti-falcon-logo\.jpg/);
 assert(existsSync(new URL('../admin-dashboard/assets/toti-falcon-logo.jpg',import.meta.url)));
 assert(existsSync(new URL('../admin-dashboard/assets/toti-icon.jpg',import.meta.url)));
 assert.match(css,/\.sidebar/);
 assert.match(css,/@media\(max-width:960px\)/);
 assert.match(css,/prefers-reduced-motion/);
 assert(!mobile.includes('admin-dashboard/app.js'));
});
test('admin authority is server-side; no secret or mocked finances are exposed',()=>{
 for(const endpoint of ['phase3_admin_session','phase4_admin_report',
 'phase6_admin_banner_list','phase6_admin_banner_action',
 'phase5_finance_integrity_preflight','phase5_medal_catalog']){
  assert((js+'\n'+management).includes(endpoint),endpoint);
 }
 assert.match(js,/grant_type=pkce/);
 assert.match(js,/grant_type=password/);
 assert.match(js,/code_challenge_method/);
 assert.doesNotMatch(js,/sb_secret_|service_role|MOCK_DATA|fakeBalance|demoAdmin/);
 assert.match(js,/session=null/);
});
test('banner upload is limited to verified static WebP and real signed RPCs',()=>{
 assert.match(html,/image\/jpeg,image\/png,image\/webp/);
 assert.match(js,/blob\.size<=512000/);
 assert.match(db,/512000/);
 assert.match(db,/tc_admin_banner_upload/);
 assert.match(db,/tc_admin_banner_cleanup/);
 assert.match(db,/phase3\.banner_admin_allowed/);
 assert.match(db,/phase3\.banner_image_can_remove/);
 assert.match(db,/phase3\.banner_action_requests/);
 assert.match(db,/public\.phase6_admin_banner_action/);
 assert.match(fix,/r\.actor_id=current_actor/);
 assert.doesNotMatch(html,/\.mp4|\.gif|video\/|<video/);
});
