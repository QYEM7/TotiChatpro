// T63: real three-user GoTrue JWT + REST room-game E2E, disposable local only.
// NEVER run against hosted Supabase, use financial keys, or mint real balances.
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const stop=m=>{throw Error('T63 disposable tic-tac-toe: '+m)};
if(process.env.T63_DISPOSABLE_ONLY!=='YES')stop('Explicit temporary runner flag is required');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST'].some(x=>process.env[x]))
 stop('Linked database or project credentials prohibited');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{stop('Missing local Supabase status')}
let root;try{root=new URL(String(cfg.API_URL||''))}catch{stop('Local REST URL invalid')}
if(root.protocol!=='http:'||!['127.0.0.1','localhost'].includes(root.hostname)||
 root.pathname!=='/'||root.username||root.password)stop('Remote hosts forbidden');
const anon=String(cfg.ANON_KEY||'');if(!anon.startsWith('eyJ'))stop('Local publishable anon JWT expected');
async function req(path,{jwt=anon,body,method}={}){
 const res=await fetch(new URL(path,root.origin),{method:method|| (body===undefined?'GET':'POST'),
  headers:{apikey:anon,Authorization:'Bearer '+jwt,'Content-Type':'application/json'},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),
  signal:AbortSignal.timeout(30000)});
 let data;try{data=await res.json()}catch{data=null}
 return {status:res.status,data};
}
const ok=(x,label)=>{
 if(x.status<200||x.status>=300)
  stop(label+' denied HTTP '+x.status+' '+String(x.data?.message||x.data?.error||'').slice(0,140));
 return x.data;
};
const denied=(x,label)=>{
 if(x.status<400||x.status>=500)stop(label+' bypass unexpectedly accepted '+x.status);
};
const suffix=randomBytes(8).toString('hex');
async function signup(label){
 const result=ok(await req('/auth/v1/signup',{body:{
  email:'t63-'+suffix+'-'+label+'@example.test',
  password:randomBytes(28).toString('base64url')
 }}),'signup '+label);
 if(!result?.user?.id||!result.access_token)stop('Real disposable signed JWT missing');
 return {id:result.user.id,jwt:result.access_token};
}
const owner=await signup('owner'),opponent=await signup('opponent'),intruder=await signup('intruder');
const rpc=(name,who,body)=>req('/rest/v1/rpc/'+name,{jwt:who.jwt,body});
const room=ok(await rpc('phase2_room_create',owner,{p_title:'T63 no-stakes E2E game',p_is_private:false}),'real room');
if(!/^[a-f0-9-]{36}$/i.test(room))stop('Unexpected real room ID');
ok(await rpc('phase2_room_join',opponent,{p_room_id:room}),'opponent membership');
denied(await rpc('phase5_room_game_state',intruder,{p_room_id:room}),'outsider game read');
denied(await rpc('phase5_room_game_action',intruder,{
 p_room_id:room,p_action:'start',p_cell:null,p_request_id:randomUUID()
}),'outsider game creation');
const empty=ok(await rpc('phase5_room_game_state',owner,{p_room_id:room}),'empty match');
if(empty.hasGame!==false)stop('A ghost game exists');
const key=randomUUID();
const start=ok(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'start',p_cell:null,p_request_id:key
}),'real match start');
if(start.status!=='waiting'||start.playerX!==owner.id||start.board!=='.........')
 stop('Waiting match was not persisted correctly');
const replay=ok(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'start',p_cell:null,p_request_id:key
}),'idempotent start');
if(JSON.stringify(replay)!==JSON.stringify(start))stop('Replay changed match result');
denied(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'move',p_cell:0,p_request_id:key
}),'request key reused for different action');
denied(await rpc('phase5_room_game_action',opponent,{
 p_room_id:room,p_action:'move',p_cell:5,p_request_id:randomUUID()
}),'move without join');
ok(await rpc('phase5_room_game_action',opponent,{
 p_room_id:room,p_action:'join',p_cell:null,p_request_id:randomUUID()
}),'opponent joins game');
denied(await rpc('phase5_room_game_action',opponent,{
 p_room_id:room,p_action:'move',p_cell:5,p_request_id:randomUUID()
}),'opponent wrong turn');
const keyA=randomUUID(),keyB=randomUUID();
const dual=await Promise.all([
 rpc('phase5_room_game_action',owner,{p_room_id:room,p_action:'move',p_cell:0,p_request_id:keyA}),
 rpc('phase5_room_game_action',owner,{p_room_id:room,p_action:'move',p_cell:1,p_request_id:keyB})
]);
if(dual.filter(a=>a.status>=200&&a.status<300).length!==1||
 dual.filter(a=>a.status>=400&&a.status<500).length!==1)
 stop('Concurrent same-user moves were not serialized');
let board=ok(await rpc('phase5_room_game_state',opponent,{p_room_id:room}),'authoritative after collision');
if(board.turnNo!==1||board.board.split('X').length!==2)stop('Game accepted duplicate concurrent move');
const first=board.board.indexOf('X');const cells=first===0?[1,2]:[0,2];
ok(await rpc('phase5_room_game_action',opponent,{
 p_room_id:room,p_action:'move',p_cell:3,p_request_id:randomUUID()
}),'opponent first turn');
ok(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'move',p_cell:cells[0],p_request_id:randomUUID()
}),'owner second turn');
ok(await rpc('phase5_room_game_action',opponent,{
 p_room_id:room,p_action:'move',p_cell:4,p_request_id:randomUUID()
}),'opponent second turn');
board=ok(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'move',p_cell:cells[1],p_request_id:randomUUID()
}),'owner final turn');
if(board.status!=='won'||board.winnerId!==owner.id||board.turnNo!==5)
 stop('Game win violated server authoritative state');
denied(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'move',p_cell:8,p_request_id:randomUUID()
}),'moves after finished game');
ok(await rpc('phase5_room_game_action',owner,{
 p_room_id:room,p_action:'start',p_cell:null,p_request_id:randomUUID()
}),'second real game');
ok(await rpc('phase2_room_leave',owner,{p_room_id:room}),'Owner room departure');
const after=ok(await rpc('phase5_room_game_state',opponent,{p_room_id:room}),'room departure cancellation');
if(after.hasGame!==true||after.status!=='cancelled')stop('Room departure did not cancel stale live game');
denied(await req('/rest/v1/room_game_matches?select=id',{jwt:opponent.jwt}),
 'direct match read without RPC');
console.log('PASS T63: 3 real disposable GoTrue JWT accounts, join, turn-order, concurrent move serialization, 5-turn win, idempotency, departure cancel, private RLS. No wallet or audio mutations.');
