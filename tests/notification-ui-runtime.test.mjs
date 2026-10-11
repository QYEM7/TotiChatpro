import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('../app/phase5-notifications-ui.js',import.meta.url),'utf8');
function harness(){
 const event={},queue=[],requests=[],nodes={};
 let identity='11111111-1111-4111-8111-111111111111',signed=true;
 let overlayVisible=false;
 class El{
  constructor(tag){this.tag=tag;this.children=[];this.dataset={};this.attributes={};this.style={};this.textContent='';}
  append(...nodes){this.children.push(...nodes)}
  appendChild(node){this.children.push(node);return node}
  replaceChildren(...nodes){this.children=nodes}
  setAttribute(key,val){this.attributes[key]=val}
  querySelector(selector){
   if(selector==='[data-t57-open]')return this.children.find(c=>c.dataset.t57Open!==undefined)||null;
   return null;
  }
 }
 const panel=new El('panel');
 const overlay={classList:{contains:()=>overlayVisible}};
 nodes['#app .me-more']=panel;
 nodes['#overlay']=overlay;
 let resolveRequest;
 const requestData=(url,data)=>new Promise(resolve=>{
  requests.push({url,data,resolve});
  resolveRequest=resolve;
 });
 const document={
  querySelector(selector){return nodes[selector]||null},
  createElement(tag){return new El(tag)},
  addEventListener(name,fn){event['document:'+name]=fn},
  hidden:false
 };
 const auth={
  state(){return {signedIn:signed,user:signed?{id:identity}:null}},
  requestData
 };
 const window={
  TotiPhase2Auth:auth,TotiLiveMode:{enabled:true},
  render(){},
  addEventListener(name,fn){event['window:'+name]=fn}
 };
 function showSheet(){
  overlayVisible=true;
  for(const id of ['#t57-real-inbox','#t57-inbox-list','#t57-inbox-status',
   '#t57-inbox-summary','[data-t57-more]'])nodes[id]=new El(id);
 }
 function closeSheet(){overlayVisible=false}
 const ctx={document,window,location:{href:'https://localhost/app/'},
  screen:'me',showSheet,closeSheet,queueMicrotask:fn=>queue.push(fn),
  setInterval:()=>0,Date,Number,Object,String,Array,Error};
 vm.runInNewContext(source,ctx);
 for(const fn of queue)fn();
 const click=element=>event['document:click']({
  target:{closest(){return element}},
  preventDefault(){},stopPropagation(){},stopImmediatePropagation(){}
 });
 function switchUser(next){
  signed=!!next;identity=next||'';
  event['window:totichat-phase2-auth']();
 }
 return {window,document,panel,click,requests,nodes,switchUser,
  get open(){return overlayVisible}};
}
const settle=async()=>{for(let i=0;i<8;i++)await Promise.resolve()};

test('signed-in profile opens real inbox; RPC response renders only server notification',async()=>{
 const h=harness();
 assert.equal(h.panel.children.length,1);
 const button=h.panel.children[0];
 assert.equal(button.attributes['aria-label'],'فتح إشعارات حسابك الحقيقية');
 h.click(button);
 assert(h.open);
 assert.equal(h.requests.length,1);
 assert.equal(h.requests[0].url,'/rest/v1/rpc/phase5_notification_feed');
 const owner='11111111-1111-4111-8111-111111111111';
 assert.equal(h.requests[0].data.body.p_before,null);
 h.requests[0].resolve({
  unreadCount:1,
  items:[{id:21,event_type:'room_muted',context:{roomId:owner},
   read_at:null,created_at:'2026-10-11T13:05:00Z'}]
 });
 await settle();
 const list=h.nodes['#t57-inbox-list'];
 assert.equal(list.children.length,1);
 assert.equal(list.children[0].children[0].textContent,'تم كتم المايك إدارياً');
 assert.equal(h.nodes['#t57-inbox-summary'].textContent,'غير مقروء: 1');
 assert.equal(h.panel.children[0].children[2].textContent,'1');
});

test('switching account closes private sheet and drops late old-account responses',async()=>{
 const h=harness();
 h.click(h.panel.children[0]);assert.equal(h.requests.length,1);
 h.switchUser('22222222-2222-4222-8222-222222222222');
 assert.equal(h.open,false,'old account notification sheet must be closed');
 h.requests[0].resolve({unreadCount:1,items:[{id:77,event_type:'vip_granted',
  context:{tier:10},read_at:null}]});
 await settle();
 assert.equal(h.nodes['#t57-inbox-list'].children.length,0);
 assert.equal(h.panel.children[0].children[2].textContent,'');
});
