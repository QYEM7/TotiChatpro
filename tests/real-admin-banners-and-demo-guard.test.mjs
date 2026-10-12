import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const banner=read('app/phase6-admin-banners.js');
const admin=read('app/phase6-inapp-admin.js');
const auth=read('app/phase2-auth.js');
const loader=read('app/phase2-backend-controls.js');
const agency=read('app/agency-hub.js');
const vip=read('app/royal-vip15.js');
test('Admin banner UI parses, is loaded, and never uses synthetic campaign data',()=>{
 for(const name of ['app/phase6-admin-banners.js','app/phase6-inapp-admin.js','app/phase2-auth.js'])
  execFileSync(process.execPath,['--check',new URL('../'+name,import.meta.url).pathname]);
 assert.match(loader,/phase6-admin-banners\.js/);
 assert.match(admin,/TotiAdminBanners\?\.formMarkup/);
 assert.match(admin,/TotiAdminBanners\?\.setRows/);
 assert.match(admin,/data-tcac-banner-edit/);
 assert.match(banner,/phase6_admin_banner_action/);
 assert.match(banner,/phase3_admin_session/);
 assert.match(banner,/uploadAdminBannerImage/);
 assert.match(banner,/p_request_id:current\.requestId/);
 assert.match(banner,/outcome\?\.saved!==true/);
 assert.doesNotMatch(banner,/demoAgents|sampleBanner|fakeCampaign/);
});
test('RLS-gated banner upload never leaks auth tokens or accepts dangerous images',()=>{
 assert.match(auth,/uploadAdminBannerImage/);
 assert.match(auth,/r\.isOwner!==true&&r\.isMainPartner!==true/);
 assert.match(auth,/blob\.type!=='image\/webp'/);
 assert.match(auth,/totichat-admin-banners/);
 assert.match(auth,/x-upsert':'false'/);
 assert.match(banner,/image\/png,image\/jpeg,image\/webp/);
 assert.match(banner,/['"]image\/webp['"]/);
 assert.match(banner,/5242880/);
 assert.match(banner,/document\.createElement\('canvas'\)/);
});
test('Only separate visual preview may mount fake agencies or 15-tier VIP prototype',()=>{
 for(const src of [agency,vip]){
  assert.match(src,/TotiLivePreviewOnly/);
  assert.match(src,/if\(liveSource\)return/);
  assert.match(src,/new URLSearchParams\(location\.search\)\.get\('mode'\)==='live'/);
 }
});
