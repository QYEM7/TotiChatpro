import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-social-ui.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-social-ui.css',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('real mutual friends frontend is gated by verified signed-in session, not preview',()=>{
 assert.match(js,/TotiLiveMode\?\.enabled/);
 assert.match(js,/auth\.state\(\)\.signedIn===true/);
 assert.match(js,/window\.addEventListener\('totichat-phase2-auth'/);
 assert.match(js,/generation\+\+/);
 assert.match(js,/if\(show\(\)\)closeSheet\(\)/);
 assert.match(js,/Number\.isSafeInteger\(value\)/);
 assert(!/fakeFriends|sampleFollowers|Math\.random\(\).*follow/.test(js));
});
test('verified count, follow state, search and friends list are real RPCs',()=>{
 for(const name of ['phase5_social_overview','phase5_social_list','phase5_social_search','phase5_social_follow'])
  assert(js.includes(name),name);
 assert.match(js,/followedByMe:x\.is_following===true/);
 assert.match(js,/p_request_id:crypto\.randomUUID\(\)/);
 assert.match(js,/Number\.isSafeInteger\(data\[k\]\)/);
 assert.match(js,/node\.textContent|n\.textContent=String/);
 assert(css.includes('.tc-real-social'));
});
test('social module is loaded through old approved backend script; no new master markup',()=>{
 assert(loader.includes("phase5-social-ui.css"));
 assert(loader.includes("phase5-social-ui.js"));
 assert(html.includes('room-seats-finish.css'));
 assert(!html.includes('phase5-social-ui.js'));
 assert(loader.indexOf('phase5-vip-status-ui.js')<loader.indexOf('phase5-social-ui.js'));
});

test('social overview and list fetches cannot invalidate each other while authenticating',()=>{
 assert.match(js,/overviewSeq=0,listSeq=0/);
 assert.match(js,/serial=\+\+overviewSeq/);
 assert.match(js,/token=\+\+listSeq/);
 assert.match(js,/serial!==overviewSeq/);
 assert.match(js,/token!==listSeq/);
 assert.doesNotMatch(js,/loadId/);
 assert.match(js,/Date\.now\(\)-overviewAt<10000/);
});

test('approved profile follower counters open real social lists, not preview users',()=>{
 assert(js.includes("'.me-statcard button'"));
 assert(js.includes("['followers','friends','following'][idx]"));
 assert(js.includes("if(kind)open(kind)"));
});
