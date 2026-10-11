// Prelaunch T57: authenticated local REST notification acceptance (NO mocks).
// Three real disposable GoTrue identities, room moderation creates a REAL event.
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const stop=why=>{throw Error('T57 local notification E2E: '+why)};
if(process.env.T57_DISPOSABLE_ONLY!=='YES')stop('disposable runner flag missing');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST'].some(k=>process.env[k]))
 stop('linked credentials forbidden');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{stop('local Supabase status file missing')}
let root;try{root=new URL(String(cfg.API_URL||''))}catch{stop('invalid local URL')}
if(root.protocol!=='http:'||!['localhost','127.0.0.1'].includes(root.hostname)||
 root.username||root.password||root.pathname!=='/')stop('remote endpoint denied');
const key=String(cfg.ANON_KEY||'');if(!key.startsWith('eyJ'))stop('local JWT missing');
async function request(path,{jwt=key,body}={}){
 const r=await fetch(new URL(path,root.origin),{
  method:body===undefined?'GET':'POST',
  headers:{apikey:key,Authorization:'Bearer '+jwt,'Content-Type':'application/json'},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),
  signal:AbortSignal.timeout(20000)
 });
 let data;try{data=await r.json()}catch{data=null}
 return {status:r.status,data};
}
const ok=(r,label)=>{
 if(r.status<200||r.status>=300)stop(label+' HTTP '+r.status+' '+String(r.data?.message||'').slice(0,80));
 return r.data;
};
const denied=(r,label)=>{
 if(r.status<400||r.status>=500)stop(label+' improperly succeeded HTTP '+r.status);
};
const prefix=randomBytes(7).toString('hex');
async function signup(label){
 const data=ok(await request('/auth/v1/signup',{body:{
  email:'t57-'+prefix+'-'+label+'@example.test',
  password:randomBytes(32).toString('base64url')
 }}),'signup '+label);
 if(!data?.user?.id||!data.access_token)stop('test Auth unavailable');
 return {id:data.user.id,jwt:data.access_token};
}
const owner=await signup('owner'),guest=await signup('guest'),outsider=await signup('outsider');
const rpc=(name,actor,data)=>request('/rest/v1/rpc/'+name,{jwt:actor.jwt,body:data});
const room=ok(await rpc('phase2_room_create',owner,{p_title:'Real notification webhook QA',p_is_private:false}),'room create');
ok(await rpc('phase2_room_join',guest,{p_room_id:room}),'guest join');
let notification=ok(await rpc('phase5_notification_feed',guest,{p_limit:10,p_before:null}),'initial feed');
if(notification.unreadCount!==0||notification.items?.length!==0)
 stop('new user received fake notification');
const keyId=randomUUID();
const action={p_room_id:room,p_target:guest.id,p_action:'mute',p_request_id:keyId,p_reason:null};
ok(await rpc('phase2_room_moderate',owner,action),'source event');
ok(await rpc('phase2_room_moderate',owner,action),'idempotent source event replay');
notification=ok(await rpc('phase5_notification_feed',guest,{p_limit:10,p_before:null}),'real recipient inbox');
if(notification.unreadCount!==1||notification.items?.length!==1||
 notification.items[0].event_type!=='room_muted'||
 notification.items[0].context?.roomId!==room)
 stop('real moderation audit failed to generate exactly one owner-only notification');
const source=notification.items[0].id;
const outsiderRead=ok(await rpc('phase5_notification_feed',outsider,{p_limit:10,p_before:null}),'outsider feed');
if(outsiderRead.unreadCount!==0||outsiderRead.items?.length!==0)
 stop('outsider saw notification');
const strangerTable=ok(await request('/rest/v1/user_notifications?select=id,event_type',{jwt:outsider.jwt}),'outsider direct RLS');
if(strangerTable.length!==0)stop('cross-account REST notification exposure');
denied(await request('/rest/v1/user_notifications',{jwt:guest.jwt,body:{recipient_id:owner.id,event_type:'vip_granted',source_type:'security_audit',source_id:9}}),'direct forged client message');
const noMark=ok(await rpc('phase5_notification_mark',outsider,{p_ids:[source],p_all:false}),'outsider mark request');
if(noMark.updated!==0)stop('outsider marked member notification');
const ack=ok(await rpc('phase5_notification_mark',guest,{p_ids:[source],p_all:false}),'member mark read');
if(ack.updated!==1)stop('read not acknowledged');
const repeated=ok(await rpc('phase5_notification_mark',guest,{p_ids:[source],p_all:false}),'read replay');
if(repeated.updated!==0)stop('read replay should be harmless');
const after=ok(await rpc('phase5_notification_feed',guest,{p_limit:10,p_before:null}),'read feed');
if(after.unreadCount!==0||!after.items[0].read_at)stop('unread count or server timestamp mismatch');
ok(await rpc('phase2_room_leave',owner,{p_room_id:room}),'owner close');
console.log('PASS T57: three real disposable GoTrue JWT identities, committed mute audit -> one private RLS inbox event; anonymous forged INSERT rejected; outsider read/mark denied; acknowledgment idempotent.');
