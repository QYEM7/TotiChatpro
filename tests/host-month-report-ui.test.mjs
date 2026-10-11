import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const ui=readFileSync(new URL('../app/phase5-host-month-review-ui.js',import.meta.url),'utf8');
const gift=readFileSync(new URL('../app/phase5-gift-history-ui.js',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('host agency month preflight is access restricted to actual Owner or specially designated main partner',()=>{
 assert.match(ui,/authority\?\.isOwner===true\|\|authority\?\.isMainPartner===true/);
 assert.match(ui,/rpc\('phase3_admin_session',\{\}\)/);
 assert.match(ui,/if\(!current\(\)\|\|!trustedAuthority\(\)/);
 assert.match(ui,/rpc\('phase5_host_month_preflight'/);
 assert.match(ui,/data\.canZeroDiamonds!==false/);
 assert.match(ui,/data\.paysSalaries!==false/);
 assert.match(ui,/data\.hasPayrollRates!==false/);
 assert.match(ui,/e\.earned_diamonds!==e\.remaining_diamonds\+e\.converted_or_allocated_diamonds/);
 const calls=[...ui.matchAll(/rpc\('([^']+)'/g)].map(x=>x[1]).sort();
 assert.deepEqual(calls,['phase3_admin_session','phase5_host_month_preflight'].sort());
 assert.doesNotMatch(ui,/\b(?:sendGift|settlePayroll|clearDiamonds|creditCoins)\s*\(/);
});
test('month report cannot show fabricated rates or current monthly zeroing',()=>{
 assert(ui.includes('لا تسوية رواتب، لا تصفير'));
 assert(ui.includes('الرواتب والعمولات والتارجت تحتاج نسباً معتمدة'));
 assert.match(ui,/value>previousMonth\(\)/);
 assert.match(ui,/Number\.isSafeInteger\(x\)/);
 assert.match(ui,/loading=true/);
 assert.match(ui,/window\.addEventListener\('totichat-phase2-auth'/);
 assert.match(ui,/if\(sheet\(\).*closeSheet\(\)/);
});
test('receipt and month report UI load only in authenticated mode without changing approved markup',()=>{
 assert(loader.includes('phase5-gift-history-ui.js'));
 assert(loader.includes('phase5-host-month-review-ui.js'));
 assert(!html.includes('phase5-host-month-review-ui.js'));
 assert(html.includes('room-seats-finish.css'));
 assert(gift.includes('phase5_gift_summary'));
});
