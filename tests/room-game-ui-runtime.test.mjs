import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../app/phase5-room-games-ui.js',import.meta.url),'utf8');
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
const rid='33333333-3333-4333-8333-333333333333';
const mid='44444444-4444-4444-8444-444444444444';
function setup(){
 const listeners={},nodes={},requests=[];
 let user=a,room=rid,shown=false,mediaEffects=0,seq=0;
 class El{
  constructor(){this.children=[];this.dataset={};this.textContent='';this.disabled=false;this.attrs={};}
  replaceChildren(...v){this.children=[...v]}
  appendChild(v){this.children.push(v)}
  append(...v){this.children.push(...v)}
  setAttribute(k,v){this.attrs[k]=v}
  hasAttribute(k){
   if(k.startsWith('data-'))return Object.hasOwn(this.dataset,k.slice(5).replace(/-([a-z])/g,(_,x)=>x.toUpperCase()));
   return Object.hasOwn(this.attrs,k);
  }
 }
 const doc={
  querySelector(k){return nodes[k]||null},
  createElement(){return new El()},
  addEventListener(k,fn){listeners['doc:'+k]=fn},
  hidden:false
 };
 nodes['#overlay']={classList:{contains(){return shown}}};
 const auth={
  state(){return {signedIn:!!user,user:user?{id:user}:null}},
  requestData(path,opts){return new Promise((resolve,reject)=>requests.push({path,body:opts.body,resolve,reject}))}
 };
 const rooms={
  getRoomSummary(){return room?{id:room,title:'Real room',isOwner:user===a}:null},
  getMembers(){return [{user_id:a,display_name:'Verified A'},
   {user_id:b,display_name:'Verified B'}]}
 };
 const window={TotiPhase2Auth:auth,TotiPhase2Rooms:rooms,TotiLiveMode:{enabled:true},
  addEventListener(k,fn){listeners['win:'+k]=fn}};
 const showSheet=()=>{shown=true;
  for(const k of ['#tc-real-room-game','#tc-game-board','#tc-game-actions','#tc-game-state','#tc-game-players'])
   nodes[k]=new El();
 };
 const closeSheet=()=>{shown=false};
 const timers=[];
 const ctx={window,document:doc,showSheet,closeSheet,Number,Object,String,
  crypto:{randomUUID(){seq++;return 'aaaaaaaa-aaaa-4aaa-8aaa-'+String(seq).padStart(12,'0')}},
  setInterval(fn){timers.push(fn)},
 };
 vm.runInNewContext(source,ctx);
 function click(key,value){
  const el=new El();
  if(key==='action')el.dataset.tcGameAction=value;
  else if(key==='cell')el.dataset.tcGameCell=String(value);
  else el.dataset.tcGameRefresh='';
  listeners['doc:click']({target:{closest(){return el}},preventDefault(){},stopImmediatePropagation(){}});
 }
 return {window,requests,nodes,click,roomSwitch(id){room=id},
  switchAccount(id){user=id;listeners['win:totichat-phase2-auth']()},
  get shown(){return shown},get mediaEffects(){return mediaEffects}};
}
async function drain(){for(let i=0;i<15;i++)await Promise.resolve()}
test('real existing room shows a nonfabricated empty state then creates server-confirmed game',async()=>{
 const h=setup();
 h.window.TotiRoomGames.open();
 assert.equal(h.shown,true);
 assert.equal(h.requests.length,1);
 assert.equal(h.requests[0].path,'/rest/v1/rpc/phase5_room_game_state');
 assert.equal(h.requests[0].body.p_room_id,rid);
 h.requests[0].resolve({hasGame:false,roomId:rid});
 await drain();
 assert.equal(h.nodes['#tc-game-actions'].children.length,1);
 assert.equal(h.nodes['#tc-game-actions'].children[0].dataset.tcGameAction,'start');
 h.click('action','start');
 assert.equal(h.requests[1].path,'/rest/v1/rpc/phase5_room_game_action');
 assert.equal(h.requests[1].body.p_action,'start');
 assert.equal(h.requests[1].body.p_cell,null);
 assert.equal(h.requests[1].body.p_room_id,rid);
 assert.match(h.requests[1].body.p_request_id,/^[a-f0-9-]{36}$/);
 h.requests[1].resolve({hasGame:true,roomId:rid,gameId:mid,type:'tic_tac_toe',
  playerX:a,playerO:null,board:'.........',nextMark:'X',turnNo:0,
  status:'waiting',winnerId:null,updatedAt:'2026-10-11T15:00:00Z'});
 await drain();
 assert.equal(h.nodes['#tc-game-board'].children.length,9);
 assert.match(h.nodes['#tc-game-state'].textContent,/بانتظار/);
 assert.equal(h.mediaEffects,0);
});
test('switching authenticated user refuses late old-room game results and closes private sheet',async()=>{
 const h=setup();h.window.TotiRoomGames.open();
 assert.equal(h.requests.length,1);
 h.switchAccount(b);assert.equal(h.shown,false);
 h.requests[0].resolve({hasGame:false,roomId:rid});await drain();
 assert.equal(h.nodes['#tc-game-board'].children.length,0,'stale result must not render another user game');
});
