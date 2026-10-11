import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const fixture=(tag)=>({
 tag,className:'',dataset:{},isConnected:false,children:[],
 setAttribute(){},remove(){this.isConnected=false;},
 appendChild(node){this.children.push(node);node.isConnected=true;},
 replaceChildren(){this.children=[];},
 querySelector(selector){
  if(selector==='strong')return {textContent:''};
  if(selector==='input')return {focus(){},value:''};
  if(selector==='button')return {disabled:false};
  return null;
 }
});

test('opening another private conversation does not wait on a stale pending thread',async()=>{
 const viewer='11111111-1111-4111-8111-111111111111';
 const alice='22222222-2222-4222-8222-222222222222';
 const bob='33333333-3333-4333-8333-333333333333';
 const requests=[];
 const area=fixture('section'),feedback=fixture('p');
 let currentOverlay=null;
 const document={
  createElement:fixture,hidden:false,addEventListener(){},
  querySelector(selector){
   return selector==='#tc-dm-messages'?area:selector==='#tc-dm-status'?feedback:null;
  },
  body:{appendChild(node){currentOverlay=node;node.isConnected=true;}}
 };
 const auth={
  state:()=>({signedIn:true,user:{id:viewer}}),
  requestData:(endpoint,options)=>new Promise(resolve=>{
   requests.push({endpoint,payload:options.body,resolve});
  })
 };
 const window={
  TotiPhase2Auth:auth,TotiLiveMode:{enabled:true},addEventListener(){}
 };
 const code=readFileSync(new URL('../app/phase2-private-messages.js',import.meta.url),'utf8');
 new Function('window','document','vMessages','vChat','render','screen','setInterval','crypto','showToast',code)(
  window,document,()=>'',()=>'',()=>{},'room',()=>{},
  {randomUUID:()=>viewer},()=>{}
 );
 const first=window.TotiPrivateMessages.open(alice,'Alice');
 const second=window.TotiPrivateMessages.open(bob,'Bob');
 assert.equal(requests.length,2,'The latest chat must load even if the prior RPC is pending.');
 assert.deepEqual(requests.map(r=>r.payload.p_other_user),[alice,bob]);
 requests[1].resolve([]);
 await second;
 assert.equal(currentOverlay.isConnected,true);
 assert.equal(area.children.length,1);
 const lastContent=area.children[0].textContent;
 requests[0].resolve([{id:1,sender_id:alice,recipient_id:viewer,body:'STALE_MESSAGE',created_at:'2026-10-11T00:00:00Z'}]);
 await first;
 assert.equal(area.children.length,1,'Stale response cannot replace the new conversation.');
 assert.equal(area.children[0].textContent,lastContent);
 window.TotiPrivateMessages.close();
 assert.equal(currentOverlay.isConnected,false);
});
