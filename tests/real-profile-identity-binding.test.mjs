import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const live=readFileSync(new URL('../app/phase2-live-mode.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('authenticated me screen displays real account name and id while preserving design classes',()=>{
 assert.match(live,/profile\?\.display_name\|\|'مستخدم جديد'/);
 assert.match(live,/accountName\.firstChild/);
 assert.match(live,/accountId\.textContent='حساب TotiChat · ID: '\+state\.user\.id\.slice/);
 assert.match(html,/class="me-royal"/);
});
test('authenticated account cannot show hard-coded fake social counters before graph binding',()=>{
 assert.match(live,/\$\$\('\.me-statcard b'\)\.forEach\(node=>node\.textContent='—'\)/);
 assert.match(live,/\$\$\('\.pr-numbers button strong'\)\.forEach\(e=>e\.textContent='—'\)/);
 assert.match(live,/if\(!live\(\)\)return/);
});
