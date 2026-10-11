import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

// These are behavioral tests of the actual production functions, executed with
// isolated asynchronous mocks. No real identities, database writes or audio.
const source=readFileSync(new URL('../app/phase2-rooms.js',import.meta.url),'utf8');
const section=(from,to)=>{
 const first=source.indexOf(from),last=source.indexOf(to,first+from.length);
 assert(first>=0&&last>first,'Expected room implementation: '+from);
 return source.slice(first,last);
};
const refreshBody=section('async function refreshRoom(){','async function resume(){');
const joinBody=section('async function enterRoom(id){','const INVITE=');
const cleanBody=section('function clearUnjoinedRoom(view){','function roomContent(){');
const user='11111111-1111-4111-8111-111111111111';
const a='22222222-2222-4222-8222-222222222222';
const b='33333333-3333-4333-8333-333333333333';
function deferred(){
 let resolve,reject;
 const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});
 return {promise,resolve,reject};
}
function roomFixture(initial=a){
 const requests=[],events=[],renders=[],revoked=[];
 const env={
  user,requests,events,renders,revoked,
  roster(roomId){
   const request=deferred();requests.push({roomId,...request});return request.promise;
  },
  detail(path){
   if(path.includes('/room_messages?'))return Promise.resolve([]);
   const id=decodeURIComponent(path.match(/id=eq\.([^&]+)/)?.[1]||'');
   return Promise.resolve([{id,title:'Server room '+id}]);
  }
 };
 const factory=new Function('ctx',[
  "'use strict';",
  "let active={id:ctx.initial},sequence=0,refreshing=null,members=[],messages=[];",
  "const session=()=>({signedIn:true,user:{id:ctx.user}});",
  "const rpc=(name,args)=>ctx.roster(args.p_room_id);",
  "const query=path=>ctx.detail(path);",
  "const roomMembershipRevoked=id=>ctx.revoked.push(id);",
  "const roomContent=()=>ctx.renders.push(active.id);",
  "const failure=e=>String(e);",
  "const screen='room';",
  "const console={warn(){}};",
  "const window={TotiRealVoice:{syncPermission(){}},dispatchEvent(e){ctx.events.push(e.detail)}};",
  "const CustomEvent=class{constructor(type,options){this.detail=options.detail;}};",
  refreshBody,
  "return {refreshRoom,switchRoom(id){sequence++;active={id};members=[];messages=[];},snapshot(){return {room:active?.id,members:members.map(m=>m.user_id),pending:refreshing?.roomId??null}},setRoom(id){active={id}}};"
 ].join('\n'));
 return {env,api:factory({...env,initial})};
}

test('slow room A must not prevent room B from fetching a fresh real roster',async()=>{
 const {env,api}=roomFixture();
 const old=api.refreshRoom();
 api.switchRoom(b);
 const fresh=api.refreshRoom();
 assert.deepEqual(env.requests.map(x=>x.roomId),[a,b]);
 env.requests[1].resolve([{user_id:user,seat_no:3}]);
 await fresh;
 assert.deepEqual(api.snapshot(),{room:b,members:[user],pending:null});
 env.requests[0].resolve([{user_id:'00000000-0000-4000-8000-000000000000',seat_no:5}]);
 await old;
 assert.deepEqual(api.snapshot(),{room:b,members:[user],pending:null},'stale A must not overwrite B');
 assert.equal(env.revoked.length,0);
});

test('finishing stale A never releases a pending B snapshot lock',async()=>{
 const {env,api}=roomFixture();
 const old=api.refreshRoom();
 api.switchRoom(b);
 const latest=api.refreshRoom();
 env.requests[0].resolve([{user_id:user}]);
 await old;
 const coalesced=api.refreshRoom();
 assert.equal(env.requests.length,2,'second B refresh should reuse the in-flight B promise');
 env.requests[1].resolve([{user_id:user}]);
 await Promise.all([latest,coalesced]);
 const next=api.refreshRoom();
 assert.equal(env.requests.length,3,'completed B should permit a later new refresh');
 env.requests[2].resolve([{user_id:user}]);await next;
});

test('late room join cannot restore prior account session after user switch',async()=>{
 const gate=deferred(),ctx={actor:user};
 const factory=new Function('ctx',[
  "'use strict';",
  "let active=null,rooms=null,members=[],messages=[],entering=false,sequence=0;",
  "const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;",
  "const session=()=>({signedIn:!!ctx.actor,user:{id:ctx.actor}});",
  "const rpc=()=>ctx.join;",
  "const query=()=>Promise.resolve([{id:ctx.room}]);",
  "const toast=()=>{};const failure=e=>String(e);",
  "const go=()=>{ctx.navigated=true};",
  "const refreshRoom=async()=>{};",
  joinBody,
  "return {enterRoom,logout(){ctx.actor=null;sequence++},getRoom(){return active?.id??null}};"
 ].join('\n'));
 const app=factory({...ctx,join:gate.promise,room:a});
 const pending=app.enterRoom(a);
 app.logout();
 gate.resolve(true);
 await pending;
 assert.equal(app.getRoom(),null);
});

test('unjoined room clears all 15 seats and legacy chat messages without errors',()=>{
 const buttons=Array.from({length:15},()=>({
  disabled:false,classList:{remove(){},toggle(){}},setAttribute(){},
 }));
 let removed=0,notes=0;
 const old=[{remove(){removed++}},{remove(){removed++}}];
 const area={appendChild(){notes++}};
 const factory=new Function('$','$$','document',
  "'use strict';"+cleanBody+"; return clearUnjoinedRoom;");
 const selectOne=(selector)=>selector==='.chatArea'?area:null;
 const selectAll=(selector)=>selector==='.seats .seat'?buttons:selector==='.chatMsg'?old:[];
 const clean=factory(selectOne,selectAll,{createElement:()=>({})});
 assert.doesNotThrow(()=>clean({}));
 assert.equal(buttons.filter(x=>x.disabled).length,15);
 assert.equal(removed,2);
 assert.equal(notes,1);
});
