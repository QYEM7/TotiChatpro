/* T17 live local WebSocket protocol exercise with two real JWT identities. */
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const die=s=>{throw Error('T17 realtime local test: '+s)};
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{die('local status required')}
const addr=new URL(cfg.API_URL);
if(addr.protocol!=='http:'||!['localhost','127.0.0.1','[::1]'].includes(addr.hostname))die('will not connect outside ephemeral local Supabase');
const anon=String(cfg.ANON_KEY||'');
const wsUrl=addr.origin.replace(/^http:/,'ws:')+'/realtime/v1/websocket?apikey='+encodeURIComponent(anon)+'&vsn=1.0.0';
const get=async(path,token=anon,body)=>{
 const res=await fetch(new URL(path,addr.origin),{method:body?'POST':'GET',signal:AbortSignal.timeout(12000),
 headers:{apikey:anon,Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},
 ...(body?{body:JSON.stringify(body)}:{})});
 let data;try{data=await res.json()}catch{data=null}
 return {status:res.status,data};
};
const nonce=randomBytes(6).toString('hex');const users=[];
for(const i of [1,2]){
 const s=await get('/auth/v1/signup',anon,{email:'t17-'+nonce+'-'+i+'@example.test',password:randomBytes(24).toString('base64url')});
 if(s.status!==200||!s.data?.access_token)die('disposable signup failed');
 users.push(s.data);
}
let joinConfirmed=false;const seen=[];let resolveJoined;
const joined=new Promise((resolve,reject)=>{
 resolveJoined=resolve;
 setTimeout(()=>reject(Error('WebSocket channel join timeout')),14000);
});
let ws;
try{
 ws=new WebSocket(wsUrl);
 ws.onopen=()=>ws.send(JSON.stringify({
  topic:'realtime:totichat-room-change',event:'phx_join',ref:'1',join_ref:'1',
  payload:{access_token:users[0].access_token,config:{
   broadcast:{ack:false,self:false},presence:{enabled:false},private:false,
   postgres_changes:[{event:'*',schema:'public',table:'rooms'},
     {event:'*',schema:'public',table:'room_members'},
     {event:'*',schema:'public',table:'room_messages'}]
  }}
 }));
 ws.onmessage=message=>{
  let m;try{m=JSON.parse(message.data)}catch{return}
  if(m.event==='phx_reply'&&m.ref==='1'){
   if(m.payload?.status==='ok'){joinConfirmed=true;resolveJoined();}
   else resolveJoined=()=>{},console.error('Realtime join denied'),ws.close();
  }
  if(m.event==='postgres_changes')seen.push(m.payload?.data);
 };
 ws.onerror=()=>{};
 await joined;
 if(!joinConfirmed)die('no confirmed PG changes subscription');
 const created=await get('/rest/v1/rpc/phase2_room_create',users[1].access_token,{p_title:'T17 live event '+nonce,p_is_private:false});
 if(created.status!==200||typeof created.data!=='string')die('second local user failed create room');
 const id=created.data;
 const waitUntil=async()=>{
  for(let n=0;n<40;n++){
   if(seen.some(e=>e?.table==='rooms'&&e?.record?.id===id&&e?.type==='INSERT'))return true;
   await new Promise(ok=>setTimeout(ok,250));
  }
  return false;
 };
 if(!await waitUntil())die('no RLS-authenticated room event within 10s');
 // RLS guarantees that subscription events expose only rows user can SELECT.
 console.log('PASS T17: verified local WebSocket joined with real GoTrue JWT, other user created a public room, subscribed user received PostgreSQL INSERT event.');
}finally{try{ws?.close()}catch{}}
