import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const medals=readFileSync(new URL('../app/phase5-medals-ui.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-medals-ui.css',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('earned medal cards are only read from real authenticated RPC',()=>{
 assert.match(medals,/if\(!auth\|\|!window\.TotiLiveMode\?\.enabled\)return/);
 assert.match(medals,/auth\.state\(\)\.signedIn===true/);
 assert.match(medals,/rpc\('phase5_medal_user',\{p_target:ref\}\)/);
 assert.match(medals,/result\.userId!==ref/);
 assert.match(medals,/Array\.isArray\(result\.items\)/);
 assert.match(medals,/if\(!items\.length\)/);
 assert.match(medals,/body\.replaceChildren\(\)/);
 assert.match(medals,/node\.textContent=String\(label\?\?''\)/);
 assert.doesNotMatch(medals,/fakeMedals|demoMedals|randomBadges|localStorage|VIP\s*11/);
});
test('only verified Owner interface can issue confirmed auditable awards',()=>{
 assert.match(medals,/approvedOwner=result\?\.isOwner===true/);
 assert.match(medals,/if\(!signed\(\)\|\|!approvedOwner\|\|busy/);
 assert.match(medals,/rpc\('phase5_medal_owner_action'/);
 assert.match(medals,/p_request_id:crypto\.randomUUID\(\)/);
 assert.match(medals,/window\.confirm/);
 assert.match(medals,/result\?\.success!==true/);
 assert.match(medals,/epoch\+\+/);
 assert.match(medals,/if\(show\(\)\)closeSheet\(\)/);
});
test('medal style is independent of approved 15 seats and master markup',()=>{
 assert(loader.includes("phase5-medals-ui.css"));
 assert(loader.includes("'phase5-medals-ui.js'"));
 assert(html.includes("room-seats-finish.css"));
 assert(!html.includes('phase5-medals-ui.js'));
 assert(css.includes('.pr-display-items .tc-live-medal'));
});
