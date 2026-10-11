import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const src=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const management=src('../admin-dashboard/management.js');
const core=src('../admin-dashboard/app.js');
const index=src('../admin-dashboard/index.html');
const headers=JSON.parse(src('../admin-dashboard/vercel.json'));
const support=src('../supabase/migrations/20261012004500_admin_support_authority.sql');
const lists=src('../supabase/migrations/20261012004000_admin_management_directory.sql');

test('Owner has fully audited staff and support grants, while partner remains a distinct principal',()=>{
 assert.match(management,/phase3_manage_access/);
 assert.match(management,/phase5_support_action/);
 assert.match(management,/staff_grant/);
 assert.match(management,/staff_revoke/);
 assert.match(management,/p_main_partner:partner/);
 assert.match(management,/if\(!owner\(\)\)throw Error/);
 assert.match(support,/main_partner_id=phase3\.actor\(\)/);
 assert.match(lists,/p_kind not in\('staff','host_agencies','recharge_agencies'/);
 assert.doesNotMatch(management,/p_role:'owner'|value="owner"/);
});
test('exceptional host agency transfer requires investigation and does not bypass server validation',()=>{
 assert.match(management,/exception_transfer/);
 assert.match(management,/form\.querySelector\('\[name=verified\]'\)\?\.checked/);
 assert.match(management,/note\.length<10/);
 assert.match(management,/window\.confirm/);
 assert.match(management,/phase4_agency_action/);
 assert.match(management,/if\(!chief\(\)\)throw Error/);
 assert.doesNotMatch(management,/defaultSalary|defaultCommission|randomBalance/);
});
test('account switching invalidates async manager views, support messages and privileged reports',()=>{
 assert.match(core,/revision:\(\)=>epoch/);
 assert.match(core,/identity:\(\)=>session\?\.user\?\.id/);
 assert.match(management,/stamp!==revision\(\)\|\|account!==identity\(\)/);
 assert.match(management,/startPage\('support'\)/);
 assert.match(management,/startPage\('vip'\)/);
});
test('real report range and safe CSV avoid fabricated balances and spreadsheet formula injection',()=>{
 assert.match(core,/phase4_admin_report/);
 assert.match(core,/async function exportReport\(\)/);
 assert.match(core,/detailOffset,reportRange/);
 assert.match(core,/report-filter-form/);
 assert.match(core,/text="'"\+text/);
 assert.match(core,/text\/csv;charset=utf-8/);
 assert.doesNotMatch(core,/fakeBalance|demoTransactions/);
});
test('official site ready-to-deploy source does not claim a live URL or permit indexing',()=>{
 assert.match(index,/name="robots" content="noindex,nofollow,noarchive"/);
 const hs=headers.headers[0].headers;
 assert(hs.some(x=>x.key==='X-Robots-Tag'));
 assert(hs.some(x=>x.key==='Content-Security-Policy'));
});
