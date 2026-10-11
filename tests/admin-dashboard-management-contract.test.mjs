import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const html=read('../admin-dashboard/index.html');
const main=read('../admin-dashboard/app.js');
const management=read('../admin-dashboard/management.js');
const css=read('../admin-dashboard/management.css');
const accessSQL=read('../supabase/migrations/20261012004500_admin_support_authority.sql');
const mgmtSQL=read('../supabase/migrations/20261012004000_admin_management_directory.sql');
const cfg=JSON.parse(read('../admin-dashboard/vercel.json'));
test('isolated admin website loads real management modules and responsive styles',()=>{
 assert.match(html,/<script src="\.\/management\.js" defer><\/script>/);
 assert.match(html,/<script src="\.\/app\.js" defer><\/script>/);
 assert.match(html,/<link rel="stylesheet" href="\.\/management\.css">/);
 assert.match(css,/max-width:650px/);
 assert.match(main,/TotiAdminManagement\?\.configure/);
 for(const route of ["hosts","recharge","support","vip","medals","team"]){
  assert.match(main,new RegExp("async function "+(route==="hosts"?"hostsPage":route==="recharge"?"rechargePage":route==="support"?"supportPage":route==="team"?"teamPage":route==="vip"?"vipPage":"medalsPage")+"\\("));
 }
});
test('management privileges are rechecked on the backend and only Owner can set roles, VIP or medals',()=>{
 assert.match(mgmtSQL,/phase3\.is_owner\(\)/);
 assert.match(mgmtSQL,/s\.main_partner_id=actor_id/);
 assert.match(mgmtSQL,/p_kind not in\('staff','host_agencies','recharge_agencies'/);
 assert.match(mgmtSQL,/revoke all on function public\.phase6_admin_management_page/);
 assert.match(mgmtSQL,/readOnly',true/);
 assert.match(management,/phase3_manage_access/);
 assert.match(management,/phase5_vip_owner_action/);
 assert.match(management,/phase5_medal_owner_action/);
 assert.match(management,/phase4_agency_action/);
 assert.match(management,/phase5_support_action/);
 assert.match(management,/if\(!owner\(\)\)throw Error/);
 assert.match(management,/if\(!chief\(\)\)throw Error/);
 assert.doesNotMatch(management,/service_role|sb_secret_|mockUsers|fakeBalances/);
});
test('support staff authorization is a real server condition, not client role text',()=>{
 assert.match(accessSQL,/phase3\.support_staff/);
 assert.match(accessSQL,/main_partner_id=phase3\.actor\(\)/);
 assert.match(accessSQL,/public\.phase6_admin_support_access/);
 assert.match(main,/phase6_admin_support_access/);
 assert.match(main,/rights=\{\.\.\.r,canSupport\}/);
 assert.match(main,/if\(id==='support'\)return rights\.canSupport===true/);
 assert.match(management,/p_scope:'all'/);
 assert.match(management,/phase5_support_thread_page/);
});
test('agency commission requires a real explicit user-provided rate; no invented 0',()=>{
 assert.match(management,/if\(decision==='approve_registration'&&\(!rawRate/);
 assert.doesNotMatch(management,/value="0"[^>]*type="number" min="0" max="100"/);
 assert.match(management,/p_request_id:crypto\.randomUUID\(\)/);
 assert.match(management,/window\.confirm/);
});
test('static site security headers prohibit clickjacking and external scripts',()=>{
 const h=cfg.headers[0].headers;
 const get=name=>h.find(x=>x.key===name)?.value||'';
 assert.match(get('Content-Security-Policy'),/script-src 'self'/);
 assert.match(get('Content-Security-Policy'),/frame-ancestors 'none'/);
 assert.match(get('Content-Security-Policy'),/connect-src 'self' https:\/\/rziaedugbdwefbefcxjt\.supabase\.co/);
 assert.equal(get('X-Frame-Options'),'DENY');
 assert.equal(get('Referrer-Policy'),'no-referrer');
});
