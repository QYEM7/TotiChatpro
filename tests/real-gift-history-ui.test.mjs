import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-gift-history-ui.js',import.meta.url),'utf8');
const sql=readFileSync(new URL('../supabase/migrations/20261011213000_verified_personal_gift_history.sql',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-gift-history-ui.css',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('signed-in gift UI reads its own committed receipts without preview gift data',()=>{
 assert.match(js,/window\.TotiLiveMode\?\.enabled/);
 assert.match(js,/auth\.state\(\)\.signedIn===true/);
 assert.match(js,/rpc\('phase5_gift_summary',\{\}\)/);
 assert.match(js,/rpc\('phase5_gift_history'/);
 assert.match(js,/result\.userId!==id/);
 assert.match(js,/p_before_at:beforeAt,p_before_id:beforeId/);
 assert.match(js,/BigInt\(s\)\.toLocaleString/);
 assert.match(js,/node\.textContent|n\.textContent=String/);
 assert.match(js,/window\.addEventListener\('totichat-phase2-auth'/);
 assert.match(js,/if\(sheet\(\).*closeSheet\(\)/);
 assert.doesNotMatch(js,/fakeGift|demoGift|Math\.random\(|localStorage|phase3_send_gift/);
});
test('true gift cost is never labeled payroll or spendable balance',()=>{
 assert(js.includes('هذا ليس رصيدك الحالي ولا مستحقات راتبك'));
 assert.match(sql,/isSalaryReport',false/);
 assert.match(sql,/isBalance',false/);
 assert.match(sql,/receivedGiftDiamonds/);
 assert.match(sql,/receivedGiftCoins/);
 assert.match(sql,/sentGiftCoins/);
});
test('gift receipts remain scoped to independent signed-in module and approved HTML',()=>{
 assert(loader.includes('phase5-gift-history-ui.js'));
 assert(loader.includes('phase5-gift-history-ui.css'));
 assert(!html.includes('phase5-gift-history-ui.js'));
 assert(html.includes('room-seats-finish.css'));
 assert(css.includes('.tc-real-gift-history'));
});
