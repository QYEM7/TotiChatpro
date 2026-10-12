import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import vm from 'node:vm';
const load=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const center=load('../app/phase6-inapp-admin.js');
const controls=load('../app/phase2-backend-controls.js');
const css=load('../app/phase6-inapp-admin.css');
const master=load('../app/index.html');

test('new administration JS remains valid and preview HTML stays protected',()=>{
 for(const file of ['app/phase6-inapp-admin.js','app/phase2-backend-controls.js'])
  execFileSync(process.execPath,['--check',new URL('../'+file,import.meta.url).pathname]);
 assert(!master.includes('phase6-inapp-admin.js'),'approved master is not edited');
 assert(controls.includes("'phase6-inapp-admin.js'"));
 assert(controls.includes("new URL('phase6-inapp-admin.css',moduleBase)"));
 assert.match(css,/\.tcac-root/);
 assert.match(css,/prefers-reduced-motion/);
 assert.doesNotMatch(center,/sb_secret_|service_role|MOCK_DATA|fakeBalance/);
});
test('only one administrative Profile entry; legacy actions move inside center',()=>{
 const block=controls.slice(controls.indexOf('function inject(){'),controls.indexOf('async function loadAuthority(){'));
 assert.match(block,/window\.TotiInAppAdmin\?\.onProfile\(\)/);
 for(const legacy of ['data-admin-open','data-reports-open','data-tc-global-gift-admin','data-tc-host-approval'])
  assert(!block.includes(legacy),'Profile must not expose separate '+legacy);
 for(const existing of ['data-admin-open','data-reports-open','data-tc-global-gift-admin','data-tc-host-approval'])
  assert(center.includes(existing),'integrated working shortcut '+existing);
});
test('permissions and supported read paths are explicitly gated by the server',()=>{
 for(const rpc of ['phase3_admin_session','phase6_admin_support_access','phase6_admin_directory','phase6_admin_management_page'])
  assert(center.includes(rpc),rpc);
 for(const guard of ["r?.isMainPartner===true","r.role==='db'","host_agency.open","r.canSupport===true"])
  assert(center.includes(guard),guard);
 assert.match(center,/readOnly!==true/);
 assert.match(center,/uid\(\)!==id/);
 assert.match(center,/if\(!fresh\|\|!item\|\|!can/);
 assert.match(center,/exit\(\); \/\/ Close our overlay BEFORE invoking/);
});
function harness(admin,support){
 const listeners={};
 const panel={children:[],querySelector(q){return q==='[data-tcac-entry]'?this.children.find(x=>x.attr?.['data-tcac-entry']!==undefined)||null:null;},
  querySelectorAll(){return [];},
  appendChild(node){this.children.push(node);}};
 const newElement=name=>({tag:name,attr:{},children:[],className:'',textContent:'',
  setAttribute(k,v){this.attr[k]=v;},append(...n){this.children.push(...n);},
  remove(){panel.children=panel.children.filter(x=>x!==this);}});
 const doc={currentScript:null,hidden:false,documentElement:{classList:{remove(){},add(){}}},
  body:{appendChild(){}},createElement:newElement,
  querySelector(q){return q==='#app .me-more'?panel:q==='[data-tcac-entry]'?panel.querySelector(q):null;},
  querySelectorAll(){return [];},
  addEventListener(k,fn){listeners[k]=fn;}};
 const state={signedIn:true,user:{id:'test-id'}};
 const auth={state:()=>state,requestData:async(path)=>{
   if(path.endsWith('phase3_admin_session'))return admin;
   if(path.endsWith('phase6_admin_support_access'))return {canHandle:support};
   throw Error('Unexpected: '+path);
 }};
 const win={TotiPhase2Auth:auth,TotiLiveMode:{enabled:true},addEventListener(k,fn){listeners[k]=fn;}};
 const context={window:win,document:doc,screen:'me',console,Promise};
 vm.runInNewContext(center,context,{filename:'phase6-inapp-admin.js'});
 return {win,panel,state};
}
const drain=()=>new Promise(resolve=>setImmediate(resolve));
test('a normal user is never offered the administration entry',async()=>{
 const t=harness({role:'user',isOwner:false,isMainPartner:false,permissions:[]},false);
 await drain();
 assert.equal(t.panel.children.length,0);
});
test('verified Owner and delegated DB get one Profile entry each',async()=>{
 for(const data of [
  {role:'owner',isOwner:true,isMainPartner:false,permissions:[]},
  {role:'db',isOwner:false,isMainPartner:false,permissions:['host_agency.open']}
 ]){
  const t=harness(data,false);await drain();await t.win.TotiInAppAdmin.onProfile();
  assert.equal(t.panel.children.length,1);
  assert.equal(t.panel.children[0].attr['data-tcac-entry'],'');
 }
});
test('support-only employee may access the Center but ordinary support user cannot',async()=>{
 const support=harness({role:'user',permissions:[]},true);
 const user=harness({role:'user',permissions:[]},false);
 await drain();
 assert.equal(support.panel.children.length,1);
 assert.equal(user.panel.children.length,0);
});

test('Owner-only VIP and medal actions re-authorize and use real audited RPCs',()=>{
 for(const name of ['phase5_vip_owner_action','phase5_vip_status','phase5_medal_owner_action','phase5_medal_catalog'])
  assert(center.includes(name),name);
 assert.match(center,/if\(!opened\|\|!authz\|\|!owner\(authz\)/);
 assert.match(center,/p_request_id:pendingMutation\.id/);
 assert.match(center,/confirm\(confirmation\)/);
 assert.match(center,/reason\.length<10/);
 assert.match(center,/phase6_admin_banner_list/);
 assert.match(css,/toti_falcon_logo_1790422919580\.jpg/);
});

test('finance, host-month and medals no longer create duplicate visible Profile entries',()=>{
 for(const file of ['phase5-finance-integrity-ui.js','phase5-host-month-review-ui.js','phase5-medals-ui.js']){
  const src=load('../app/'+file);
  assert.match(src,/if\(window\.TotiInAppAdmin\)return/,'legacy entry still present: '+file);
 }
 assert.match(center,/concealLegacyEntries\(\)/);
 assert.match(center,/finance_integrity:'data-finance-inspect'/);
 assert.match(center,/host_month:'data-tc-host-month'/);
});

test('Owner special ID entry is centralized without removing existing approved flow',()=>{
 const existing=load('../app/phase5-special-id-ui.js');
 assert.match(existing,/if\(window\.TotiInAppAdmin\)return/);
 assert.match(center,/special_id:'data-tc-special-id-open'/);
 assert.match(center,/data-tc-special-id-open/);
 assert.match(existing,/phase5_special_id_grant/);
});

test('support staff inbox and owner grants are real server-authorized in-app forms',()=>{
 for(const rpc of ['phase5_support_list','phase5_support_thread_page','phase5_support_action','phase3_manage_access'])
  assert(center.includes(rpc),'real operation missing '+rpc);
 for(const form of ['tcac-support-reply','tcac-support-status','tcac-staff-grant','tcac-support-staff'])
  assert(center.includes(form),'in-app form absent '+form);
 assert.match(center,/if\(view!=='staff'\|\|!owner\(r\)\)/);
 assert.match(center,/if\(view!=='support'\|\|r\.canSupport!==true/);
 assert.match(center,/p_request_id:requestId/);
 assert.match(center,/partner&&role!=='super_admin'/);
 assert(!center.includes("support:'data-support-open'"),'support must not be a customer help shortcut');
});

test('Owner and named partner only can execute server-audited room-scoped moderation',()=>{
 assert.match(center,/room_moderation','إشراف الغرف والحظر/);
 assert.match(center,/tcac-room-moderation/);
 assert.match(center,/phase6_admin_room_action/);
 assert.match(center,/if\(view!=='room_moderation'\|\|!chief\(r\)\)/);
 assert.match(center,/result\?\.success!==true/);
 assert.match(center,/p_room_id:room,p_target:target,p_action:action,p_reason:reason/);
});
