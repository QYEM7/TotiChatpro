import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-notifications-ui.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-notifications-ui.css',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');

test('inbox is wired after real Supabase Auth, live gate and backend screens',()=>{
 const auth=html.indexOf('./phase2-auth.js'),live=html.indexOf('./phase2-live-mode.js');
 const back=html.indexOf('./phase2-backend-controls.js');
 const inbox=html.indexOf('./phase5-notifications-ui.js');
 assert(auth>=0&&live>auth&&back>live&&inbox>back);
 assert(html.includes('./phase5-notifications-ui.css'));
 assert.match(js,/if\(!auth\|\|!window\.TotiLiveMode\?\.enabled\)return/);
 assert.match(js,/auth\.state\(\)\.signedIn===true/);
});
test('private inbox uses only real RPCs with correct paging, mark and account switch safeguards',()=>{
 assert.match(js,/rpc\/phase5_notification_feed/);
 assert.match(js,/rpc\/phase5_notification_mark/);
 assert.match(js,/p_limit:30,p_before:cursor/);
 assert.match(js,/body:\{p_ids:ids,p_all:all\}/);
 assert.match(js,/stamp!==epoch\|\|auth\.state\(\)\.user\?\.id!==user/);
 assert.match(js,/window\.addEventListener\('totichat-phase2-auth'/);
 assert.match(js,/if\(show\(\)\)closeSheet\(\)/);
 assert.doesNotMatch(js,/fakeNotifications|mockEvents|fixtureEvents|Math\.random\(\).*notification|sampleUnread/);
});
test('notification text is injected through textContent and only inside scoped sheet',()=>{
 assert.match(js,/node\.textContent=String\(value\?\?''\)/);
 assert.match(js,/document\.createElement\('article'\)/);
 assert.match(js,/list\.replaceChildren\(\)/);
 assert.match(js,/aria-label="الإشعارات الحقيقية"/);
 assert(css.includes('.t57-inbox'));
 assert(!js.includes('innerHTML=entry.context'));
});
