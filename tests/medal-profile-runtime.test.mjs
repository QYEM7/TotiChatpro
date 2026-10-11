import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const source=readFileSync(new URL('../app/phase5-medals-ui.js',import.meta.url),'utf8');
function setup(){
 const events={},requests=[],micro=[],nodes={};
 let identity='11111111-1111-4111-8111-111111111111',signedIn=true;
 class Element{
  constructor(){this.children=[];this.textContent='';this.dataset={};this.attrs={};this.className='';}
  append(...items){this.children.push(...items)}
  appendChild(item){this.children.push(item)}
  replaceChildren(...items){this.children=[...items]}
  setAttribute(k,v){this.attrs[k]=v}
 }
 const inventory=new Element();
 nodes['.pr-display-items']=inventory;
 const doc={
  querySelector(k){return nodes[k]||null},
  createElement(){return new Element()},
  addEventListener(k,fn){events['doc:'+k]=fn}
 };
 const auth={
  state(){return {signedIn,user:signedIn?{id:identity}:null}},
  requestData(url,req){return new Promise(resolve=>requests.push({url,body:req.body,resolve}))}
 };
 const w={TotiLiveMode:{enabled:true},TotiPhase2Auth:auth,
  render(){},addEventListener(k,fn){events['win:'+k]=fn}};
 const context={window:w,document:doc,screen:'profilePreview',Date,
  queueMicrotask(fn){micro.push(fn)},Object,Number,String,Error,Array};
 vm.runInNewContext(source,context);
 for(const fn of micro)fn();
 return {requests,nodes,inventory,render:w.render,
  authChange(value){signedIn=Boolean(value);identity=value||'';events['win:totichat-phase2-auth']()},
  user:()=>identity};
}
const flush=async()=>{for(let i=0;i<12;i++)await Promise.resolve()};
test('real medal profile shows only verified awarded badges from authenticated RPC',async()=>{
 const f=setup();const user=f.user();
 assert.equal(f.requests.length,1);
 assert.equal(f.requests[0].url,'/rest/v1/rpc/phase5_medal_user');
 assert.equal(f.inventory.children.length,1);
 f.requests[0].resolve({userId:user,items:[
  {medal_key:'official_award',display_name:'Verified Merit',description:'Owner approved achievement'}
 ]});
 await flush();
 assert.equal(f.inventory.children.length,1);
 const card=f.inventory.children[0];
 assert.equal(card.children[1].textContent,'Verified Merit');
 assert.equal(card.attrs['aria-label'],'ميدالية مكتسبة: Verified Merit');
 assert(!f.requests.some(r=>r.url.includes('medal_owner_action')));
});
test('account switch drops old badge and rejects late former-user award response',async()=>{
 const f=setup();
 const old=f.requests[0];
 f.authChange('22222222-2222-4222-8222-222222222222');
 assert.equal(f.requests.length,2);
 assert.equal(f.inventory.children.length,1);
 old.resolve({userId:'11111111-1111-4111-8111-111111111111',items:[
  {medal_key:'old_owner_badge',display_name:'Secret Old Badge',description:''}
 ]});
 await flush();
 assert(!JSON.stringify(f.inventory).includes('Secret Old Badge'));
 const newer=f.requests[1];
 newer.resolve({userId:f.user(),items:[]});
 await flush();
 assert.equal(f.inventory.children.length,1);
 assert.match(f.inventory.children[0].textContent,/لا توجد ميداليات/);
});
