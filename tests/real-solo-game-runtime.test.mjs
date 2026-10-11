import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const js=readFileSync(new URL('../app/phase5-solo-games-ui.js',import.meta.url),'utf8');
const multiplayer=readFileSync(new URL('../app/phase5-room-games-ui.js',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
class El{
 constructor(){this.children=[];this.dataset={};this.attrs={};this.textContent='';this.className='';}
 replaceChildren(...x){this.children=x}
 appendChild(x){this.children.push(x)}
 append(...x){this.children.push(...x)}
 setAttribute(k,v){this.attrs[k]=v}
 hasAttribute(k){
  if(k.startsWith('data-'))return this.dataset[k.slice(5).replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]!==undefined;
  return Object.hasOwn(this.attrs,k);
 }
}
function harness(){
 const listeners={},nodes={};
 let owner='11111111-1111-4111-8111-111111111111',signed=true,room='22222222-2222-4222-8222-222222222222',shown=false,disconnections=0;
 const auth={state(){return {signedIn:signed,user:signed?{id:owner}:null}}};
 const rooms={getRoomSummary(){return room?{id:room}:null}};
 const document={
  querySelector(key){return nodes[key]||null},
  createElement(){return new El()},
  addEventListener(k,fn){listeners['d:'+k]=fn}
 };
 nodes['#overlay']={classList:{contains:()=>shown}};
 const window={TotiPhase2Auth:auth,TotiPhase2Rooms:rooms,TotiLiveMode:{enabled:true},
  addEventListener(k,fn){listeners['w:'+k]=fn},
  TotiRoomGames:{open(){disconnections+=100}}
 };
 const showSheet=()=>{
  shown=true;
  for(const key of ['#tc-ttt-solo-game','#tc-solo-board','#tc-solo-state'])
   nodes[key]=new El();
 };
 const closeSheet=()=>{shown=false};
 vm.runInNewContext(js,{window,document,showSheet,closeSheet,Number,Array,String,Object});
 function tap(cell){
  const el=new El();el.dataset.tcSoloCell=String(cell);
  listeners['d:click']({target:{closest(){return el}},
   preventDefault(){},stopImmediatePropagation(){}});
 }
 return {window,tap,board:()=>nodes['#tc-solo-board'].children.map(x=>x.textContent),
  state:()=>nodes['#tc-solo-state'].textContent,
  logout(){owner='';signed=false;listeners['w:totichat-phase2-auth']()},
  get visible(){return shown},
  get disconnections(){return disconnections}};
}
test('single-player is actual playable algorithm, not fake online room member',()=>{
 const f=harness();f.window.TotiSoloGames.open();
 assert.equal(f.visible,true);
 assert.deepEqual(f.board(),Array(9).fill(''));
 f.tap(0);
 const marks=f.board();
 assert.equal(marks[0],'✕');
 assert.equal(marks[4],'◯','local bot chooses center, not a fabricated player');
 assert.equal(marks.filter(x=>x).length,2);
 f.tap(0);
 assert.deepEqual(f.board(),marks,'occupied square cannot be replayed');
 assert.equal(f.disconnections,0);
 f.logout();
 assert.equal(f.visible,false,'logout closes private solo game');
});
test('the multiplayer room button can switch to genuine solo without changing master HTML',()=>{
 assert(multiplayer.includes('data-tc-solo-launch'));
 assert(js.includes('data-tc-duo-launch'));
 assert(loader.includes('phase5-solo-games-ui.js'));
 assert(loader.includes('phase5-solo-games-ui.css'));
 assert(!html.includes('phase5-solo-games-ui.js'));
 assert(html.includes('room-seats-finish.css'));
 assert.doesNotMatch(js,/\.disconnect\(|\.microphone\(|phase2_room_take_seat|wallet_|diamond|\.rpc\(|requestData\(/i);
});
