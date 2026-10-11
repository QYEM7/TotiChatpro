import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-vip-status-ui.js',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');

test('approved static HTML remains free of VIP backend additions while real module is loaded after Auth',()=>{
 assert(!html.includes('phase5-vip-status-ui.js'));
 assert(loader.includes("'phase5-notifications-ui.js'"));
 assert(loader.includes("'phase5-vip-status-ui.js'"));
 assert(loader.includes("'phase5-social-ui.js'"));
 assert(loader.includes("if(!auth||!window.TotiLiveMode?.enabled)return"));
 assert(js.includes("if(!auth||!window.TotiLiveMode?.enabled)return"));
});
test('real profile VIP badges are based on authoritative VIP1..10 status, not preview VIP5',()=>{
 assert(js.includes("/rest/v1/rpc/phase5_vip_status"));
 assert(js.includes("body:{p_target:id}"));
 assert(js.includes("result.userId!==id"));
 assert(js.includes("Number.isInteger(result.tier)"));
 assert(js.includes("result.tier<0||result.tier>10"));
 assert(js.includes("status.active===true"));
 assert(js.includes("status.tier>=1&&status.tier<=10"));
 assert(js.includes("VIP غير مفعّل"));
 assert(!js.includes("VIP 5"));
 assert(!js.includes("LV45"));
});
test('VIP account switching and failed loads are fail-closed, with no fraudulent benefit claim',()=>{
 assert(js.includes("stamp!==generation"));
 assert(js.includes("id!==owner"));
 assert(js.includes("auth.state().user?.id"));
 assert(js.includes("loadedAt=0;status=null;error='';pending=null"));
 assert(js.includes("VIP · تعذّر التحقق"));
 assert(js.includes("node.replaceChildren"));
 assert(!js.includes("setTier("));
 assert(!js.includes("balance"));
});
