import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import vm from 'node:vm';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const js=read('app/phase6-premium-icons.js');
const css=read('app/phase6-premium-icons.css');
const loader=read('app/phase2-backend-controls.js');
const master=read('app/index.html');

test('live-only icon assets are syntax valid and loaded in existing app without modifying master HTML',()=>{
 execFileSync(process.execPath,['--check',new URL('../app/phase6-premium-icons.js',import.meta.url).pathname]);
 assert.match(loader,/phase6-premium-icons\.css/);
 assert.match(loader,/phase6-premium-icons\.js/);
 assert(!master.includes('phase6-premium-icons.js'),'approved design reference was edited');
 assert.match(js,/if\(!window\.TotiLiveMode\?\.enabled\|\|!window\.TotiPhase2Auth\)return/);
 assert.match(js,/signedIn===true/);
 assert.match(css,/html\[data-tc-premium="1"\]/);
});
test('every major section uses one premium outline icon family instead of unrelated emoji glyphs',()=>{
 for(const name of ['home','compass','plus','messages','user','gift','gamepad','shield','crown','wallet','building','bell','music','globe','settings','award','headset','chart'])
  assert(js.includes(name+":"),"Missing semantic SVG "+name);
 for(const route of ['rechargePreview','storage','level','honor','agencyPreview','block','report','languages'])
  assert(js.includes(route+":"),"Profile action icon missing "+route);
 for(const category of ['popular','vip','friends','music','games','world','all'])
  assert(js.includes(category+":"),"Home category missing "+category);
 for(const key of ['staff','banners','host_agencies','recharge_agencies','settlement','support','vip','room_moderation'])
  assert(js.includes(key+":"),"Admin function icon missing "+key);
 assert.match(js,/stroke-width="1\.8"/);
 assert.match(js,/aria-hidden="true"/);
 assert.match(js,/focusable="false"/);
});
test('no route handlers, backend credentials, privileged actions, or earned decoration are replaced',()=>{
 for(const token of ['.tc-unified-nav button','.me-links .me-link','.me-more > button','.roomBottom > button','.tcac-bottom button'])
  assert(js.includes(token),'No implementation for '+token);
 assert.match(js,/querySelector\('\.tc-falcon-nav'\)/);
 assert.match(js,/Never replace the approved falcon identity/);
 assert.match(js,/Preserve all seats, names, overlays, mic indicators and custom animations/);
 assert.doesNotMatch(js,/(?:requestData|localStorage|fetch\(|data-a=["']|data-v=["']|\.click\(|Math\.random)/);
 assert.doesNotMatch(css,/\.seats\b|\.seatface\b|\.vip-crest\b|\.gift-effect\b/);
 assert.match(css,/prefers-reduced-motion/);
 assert.match(css,/focus-visible/);
});
function boot(liveMode,signedIn){
 let observed=0,queued=0;
 const nodes={documentElement:{dataset:{}},body:{},getElementById:()=>null,addEventListener(){}};
 const ctx={window:{TotiLiveMode:{enabled:liveMode},TotiPhase2Auth:{state(){return {signedIn}}},addEventListener(){}},
 document:nodes,MutationObserver:class{observe(){observed++}disconnect(){}},queueMicrotask(fn){queued++;fn()},console};
 vm.runInNewContext(js,ctx);
 return {observed,queued,version:ctx.window.TotiPremiumIcons?.version};
}
test('preview and signed-out sessions cannot receive premium layout mutations',()=>{
 assert.equal(boot(false,true).observed,0);
 assert.equal(boot(true,false).version,'1.0'); // module exists but paint is disabled
 assert.equal(boot(true,false).queued,0);
});
