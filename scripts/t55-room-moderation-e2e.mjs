/* Real disposable local Auth + PostgREST moderation acceptance.
 * Absolutely no remote Supabase, external LiveKit or financial changes.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const stop=m=>{throw Error('T55 local room moderation E2E: '+m)};
if(process.env.T55_DISPOSABLE_ONLY!=='YES')stop('explicit disposable switch missing');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST'].some(k=>process.env[k]))
 stop('linked or production credential environment is forbidden');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{stop('local Supabase status missing')}
let root;try{root=new URL(String(cfg.API_URL||''))}catch{stop('invalid localhost endpoint')}
if(root.protocol!=='http:'||!['localhost','127.0.0.1'].includes(root.hostname)||root.pathname!=='/'||root.username||root.password)
 stop('only disposable loopback Auth REST permitted');
const anon=String(cfg.ANON_KEY||'');
if(!anon.startsWith('eyJ'))stop('disposable anon public token absent');
async function req(path,{token=anon,body}={}){
 const response=await fetch(new URL(path,root.origin),{
  method:body===undefined?'GET':'POST',
  headers:{apikey:anon,Authorization:'Bearer '+token,'Content-Type':'application/json'},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),
  signal:AbortSignal.timeout(30000)});
 let data;try{data=await response.json()}catch{data=null}
 return {status:response.status,data};
}
const ok=(r,label)=>{
 if(r.status<200||r.status>=300)
  stop(label+' failed HTTP '+r.status+' '+String(r.data?.message||r.data?.error||'').slice(0,110));
 return r.data;
};
const denied=(r,label)=>{
 if(r.status<400||r.status>=500)stop(label+' improperly accepted HTTP '+r.status);
};
const suffix=randomBytes(7).toString('hex');
async function signup(n){
 const data=ok(await req('/auth/v1/signup',{body:{
  email:'t55-moderator-'+suffix+'-'+n+'@test.invalid',
  password:randomBytes(30).toString('base64url')
 }}),'signup '+n);
 if(!data?.user?.id||!data.access_token)stop('verified disposable login failed');
 return {id:data.user.id,jwt:data.access_token};
}
const owner=await signup('owner'),moderator=await signup('mod');
const guest=await signup('guest'),outsider=await signup('outsider');
const rpc=(name,who,body)=>req('/rest/v1/rpc/'+name,{token:who.jwt,body});
const act=(who,target,action,room,requestId=randomUUID(),reason=null)=>
 rpc('phase2_room_moderate',who,{p_room_id:room,p_target:target.id,p_action:action,p_request_id:requestId,p_reason:reason});
const room=ok(await rpc('phase2_room_create',owner,{p_title:'Local moderated room',p_is_private:false}),'room create');
ok(await rpc('phase2_room_join',moderator,{p_room_id:room}),'moderator join');
ok(await rpc('phase2_room_join',guest,{p_room_id:room}),'guest join');
denied(await act(guest,guest,'grant_moderator',room),'customer self elevation');
ok(await act(owner,moderator,'grant_moderator',room),'owner grants moderator');
const state=ok(await rpc('phase2_room_moderation_state',owner,{p_room_id:room}),'owner moderation roster');
if(!state.moderators?.some(m=>m.userId===moderator.id))stop('owner moderator roster omitted grant');
denied(await rpc('phase2_room_moderation_state',outsider,{p_room_id:room}),'outsider roster');
denied(await act(moderator,guest,'ban',room,randomUUID(),'Unauthorized moderator ban'),'moderator ban scope');
ok(await rpc('phase2_room_take_seat',guest,{p_room_id:room,p_seat:12}),'guest seat');
ok(await rpc('phase2_room_set_muted',guest,{p_room_id:room,p_muted:false}),'guest initial self unmute');
ok(await act(moderator,guest,'mute',room),'moderator imposes mute');
denied(await rpc('phase2_room_set_muted',guest,{p_room_id:room,p_muted:false}),'member mute bypass');
ok(await rpc('phase2_room_leave',guest,{p_room_id:room}),'guest leaves');
ok(await rpc('phase2_room_join',guest,{p_room_id:room}),'guest rejoins');
ok(await rpc('phase2_room_take_seat',guest,{p_room_id:room,p_seat:12}),'guest retakes seat');
denied(await rpc('phase2_room_set_muted',guest,{p_room_id:room,p_muted:false}),'rejoin mute bypass');
ok(await act(moderator,guest,'allow_mic',room),'moderator lifts own mute');
ok(await rpc('phase2_room_set_muted',guest,{p_room_id:room,p_muted:false}),'member can unmute again');
ok(await act(owner,guest,'mute',room),'owner imposes mute');
denied(await act(moderator,guest,'mute',room),'moderator overwrite of owner mute');
denied(await act(moderator,guest,'allow_mic',room),'moderator clear owner mute');
ok(await act(owner,guest,'allow_mic',room),'owner clears own mute');
ok(await act(moderator,guest,'release_seat',room),'moderator releases seat');
const members=ok(await rpc('phase2_room_members',owner,{p_room_id:room}),'member list');
const victim=members.find(m=>m.user_id===guest.id);
if(victim?.seat_no!=null||victim?.is_muted!==true)stop('released seat still active');
ok(await act(moderator,guest,'kick',room),'moderator kicks guest');
ok(await rpc('phase2_room_join',guest,{p_room_id:room}),'guest rejoined after non-ban kick');
const key=randomUUID();
const banned=ok(await act(owner,guest,'ban',room,key,'Documented violation of room rules'),'owner bans member');
const replay=ok(await act(owner,guest,'ban',room,key,'Documented violation of room rules'),'identical retry');
if(JSON.stringify(banned)!==JSON.stringify(replay))stop('moderation idempotency failed');
denied(await act(owner,guest,'unban',room,key),'conflicting idempotency');
denied(await rpc('phase2_room_join',guest,{p_room_id:room}),'banned public room join');
denied(await rpc('phase2_room_moderation_state',guest,{p_room_id:room}),'ban roster data leak');
ok(await act(owner,guest,'unban',room),'owner removes ban');
ok(await rpc('phase2_room_join',guest,{p_room_id:room}),'member rejoins after unban');
denied(await req('/rest/v1/room_bans?select=room_id',{token:guest.jwt}),'direct ban ledger read');
ok(await rpc('phase2_room_leave',owner,{p_room_id:room}),'owner closes moderated room');
console.log('PASS T55: 4 real disposable GoTrue JWT accounts; moderator grants, forced mute across rejoin, Owner hierarchy, 15-seat release, kick, ban/unban, IDOR denied and same-key idempotency.');
