/* T16-T19 + T47: actual local Auth JWT and PostgREST room E2E, no mocks, no production. */
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const die=(s)=>{throw new Error('T16/T47 local room E2E: '+s)};
const file=process.argv[2];if(!file)die('CLI local status is required');
let cfg;try{cfg=JSON.parse(readFileSync(file,'utf8'))}catch{die('invalid local Supabase status')}
let host;try{host=new URL(cfg.API_URL)}catch{die('local API missing')}
if(host.protocol!=='http:'||!['localhost','127.0.0.1','[::1]'].includes(host.hostname)||host.username||host.password||host.port==='443')die('refusing any remotely hosted or production backend');
const key=String(cfg.ANON_KEY||'');if(!/^eyJ[A-Za-z0-9_-]+\./.test(key))die('missing local public anon JWT');
const origin=host.origin;
async function api(path,bearer=key,body){
 const request={method:body===undefined?'GET':'POST',headers:{apikey:key,Authorization:'Bearer '+bearer},signal:AbortSignal.timeout(12000)};
 if(body!==undefined){request.headers['Content-Type']='application/json';request.body=JSON.stringify(body)}
 const response=await fetch(new URL(path,origin),request);
 let data;try{data=await response.json()}catch{data=null}
 return {status:response.status,data};
}
const ok=(r,what)=>{if(r.status!==200&&r.status!==201)die(what+' HTTP '+r.status+' '+String(r.data?.message||r.data?.code||''));return r.data};
const denied=(r,what)=>{if(r.status<400||r.status>=500)die(what+' should be a client access denial, HTTP '+r.status)};
const slug=randomBytes(7).toString('hex');
async function signup(index){
 const r=await api('/auth/v1/signup',key,{email:'t47-room-'+slug+'-'+index+'@example.test',password:randomBytes(30).toString('base64url')});
 const data=ok(r,'signup '+index);
 if(!data?.user?.id||!data.access_token)die('local confirmed signup token unavailable');
 return {id:data.user.id,jwt:data.access_token};
}
const a=await signup(1),b=await signup(2);
if(a.id===b.id)die('two identities unexpectedly equal');
const rpc=(name,user,data)=>api('/rest/v1/rpc/'+name,user.jwt,data);
const created=ok(await rpc('phase2_room_create',a,{p_title:'T47 genuine ephemeral room',p_is_private:true}),'private room create');
if(!/^[0-9a-f-]{36}$/i.test(created))die('room create response must be UUID');
const roomId=created;
const privateList=ok(await api('/rest/v1/rooms?select=id&id=eq.'+roomId,b.jwt),'private room select');
if(!Array.isArray(privateList)||privateList.length!==0)die('private room metadata leaked');
denied(await rpc('phase2_room_join',b,{p_room_id:roomId}),'uninvited private room join');
const invite=ok(await rpc('phase2_room_invite_create',a,{p_room_id:roomId}),'private invitation creation');
const token=String(invite).split(':')[1];
if(!token||token.length<8)die('private invite missing nonempty token');
ok(await rpc('phase2_room_invite_join',b,{p_room_id:roomId,p_token:token}),'invited private room join');
const members=ok(await rpc('phase2_room_members',a,{p_room_id:roomId}),'members list');
if(!Array.isArray(members)||members.length!==2)die('two-room-member list mismatch');
const seat15=ok(await rpc('phase2_room_take_seat',a,{p_room_id:roomId,p_seat:15}),'owner takes seat 15');
if(seat15!==15)die('seat 15 not reserved');
denied(await rpc('phase2_room_take_seat',b,{p_room_id:roomId,p_seat:15}),'occupied seat 15');
const seat14=ok(await rpc('phase2_room_take_seat',b,{p_room_id:roomId,p_seat:14}),'guest takes seat 14');
if(seat14!==14)die('seat 14 not reserved');
ok(await rpc('phase2_room_set_muted',a,{p_room_id:roomId,p_muted:false}),'owner unmute flag');
const sent=ok(await rpc('phase2_room_send_message',a,{p_room_id:roomId,p_body:'Real authenticated private message'}),'room chat');
if(!Number.isSafeInteger(sent)||sent<1)die('chat database record ID absent');
const visible=ok(await api('/rest/v1/room_messages?select=id,body&room_id=eq.'+roomId,b.jwt),'room message RLS');
if(!Array.isArray(visible)||!visible.some(x=>x.id===sent))die('joined member could not read real message');
ok(await rpc('phase2_room_leave',b,{p_room_id:roomId}),'guest leaves room');
const after=ok(await api('/rest/v1/room_messages?select=id&room_id=eq.'+roomId,b.jwt),'departed message access');
if(!Array.isArray(after)||after.length!==0)die('departed user can still view private chat');
ok(await rpc('phase2_room_leave',a,{p_room_id:roomId}),'owner closes room');
const exists=ok(await api('/rest/v1/rooms?select=id&id=eq.'+roomId,a.jwt),'room deletion');
if(!Array.isArray(exists)||exists.length!==0)die('owner closure left room accessible');
console.log('PASS T16-T19/T47(local): 2 real GoTrue JWT accounts, private room RLS, invitation, seats 15/14, conflict denial, mic state, private chat, guest leave, owner room cleanup. Not physical-device/LiveKit E2E.');
