// T59: real disposable GoTrue + PostgREST social follow acceptance.
// Never connect hosted Supabase, copy production identities or seed Staging.
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const stop=why=>{throw Error('T59 local social E2E: '+why)};
if(process.env.T59_DISPOSABLE_ONLY!=='YES')stop('Missing explicit disposable test flag');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST'].some(k=>process.env[k]))
 stop('Remote/production credential environment is prohibited');
let cfg;
try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{stop('Local Supabase status not found')}
let root;
try{root=new URL(String(cfg.API_URL||''))}catch{stop('Local REST URL is invalid')}
if(root.protocol!=='http:'||!['127.0.0.1','localhost'].includes(root.hostname)||
 root.pathname!=='/'||root.username||root.password)stop('Only disposable loopback endpoints allowed');
const key=String(cfg.ANON_KEY||'');if(!key.startsWith('eyJ'))stop('Expected local anon JWT');
async function request(path,{jwt=key,method='GET',body,prefer}={}){
 const res=await fetch(new URL(path,root.origin),{
  method,headers:{
   apikey:key,Authorization:'Bearer '+jwt,'Content-Type':'application/json',
   ...(prefer?{Prefer:prefer}:{})
  },...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(30000)});
 let data;try{data=await res.json()}catch{data=null}
 return {status:res.status,data};
}
const ok=(r,label)=>{
 if(r.status<200||r.status>=300)stop(label+' HTTP '+r.status+' '+String(r.data?.message||r.data?.error||'').slice(0,95));
 return r.data;
};
const denied=(r,label)=>{
 if(r.status<400||r.status>=500)stop(label+' unexpectedly allowed HTTP '+r.status);
};
const seed=randomBytes(7).toString('hex');
async function account(label){
 const result=ok(await request('/auth/v1/signup',{method:'POST',body:{
  email:'t59-'+seed+'-'+label+'@example.test',
  password:randomBytes(30).toString('base64url')
 }}),'signup '+label);
 if(!result?.user?.id||!result.access_token)stop('Real local JWT signup required');
 return {id:result.user.id,jwt:result.access_token};
}
const a=await account('alice'),b=await account('bob'),other=await account('other');
const rpc=(name,user,body)=>request('/rest/v1/rpc/'+name,{jwt:user.jwt,method:'POST',body});
const profile=(who,name)=>request('/rest/v1/profiles?id=eq.'+who.id,{
 jwt:who.jwt,method:'PATCH',body:{display_name:name},prefer:'return=representation'
});
const name='T59LocalBob'+seed;
ok(await profile(b,name),'update verified profile');
const initial=ok(await rpc('phase5_social_overview',a,{p_target:a.id}),'empty overview');
if(initial.followers!==0||initial.friends!==0||initial.following!==0)
 stop('Fresh user fake counts detected');
const query=ok(await rpc('phase5_social_search',a,{p_prefix:name.slice(0,13),p_limit:15}),'social search');
if(!query.items?.some(x=>x.user_id===b.id))stop('Search missed real profile');
const keyId=randomUUID();
const follow=ok(await rpc('phase5_social_follow',a,{
 p_target:b.id,p_follow:true,p_request_id:keyId}),'A follow B');
if(follow?.followed!==true||follow.targetId!==b.id)stop('First verified follow failed');
const replay=ok(await rpc('phase5_social_follow',a,{
 p_target:b.id,p_follow:true,p_request_id:keyId}),'follow replay');
if(JSON.stringify(replay)!==JSON.stringify(follow))stop('Repeat key was not idempotent');
denied(await rpc('phase5_social_follow',a,{
 p_target:other.id,p_follow:true,p_request_id:keyId}),'conflicting request key');
ok(await rpc('phase5_social_follow',b,{
 p_target:a.id,p_follow:true,p_request_id:randomUUID()}),'B mutual follow');
const summary=ok(await rpc('phase5_social_overview',a,{p_target:a.id}),'mutual summary');
if(summary.friends!==1||summary.following!==1||summary.followers!==1)
 stop('Friends, follower or following count differs from committed graph');
const list=ok(await rpc('phase5_social_list',a,{
 p_kind:'friends',p_limit:25,p_before:null}),'friend list');
if(list.items?.length!==1||list.items[0].user_id!==b.id||
 list.items[0].is_following!==true)stop('Friend list contains wrong real account');
const stranger=ok(await request('/rest/v1/social_follows?select=follower_id',{jwt:other.jwt}),'direct RLS probe');
if(stranger.length!==0)stop('Private social edges exposed to unrelated account');
denied(await request('/rest/v1/social_follows',{jwt:other.jwt,method:'POST',
 body:{follower_id:a.id,followed_id:b.id}}),'direct forged follow');
ok(await rpc('phase2_dm_block',b,{p_other_user:a.id,p_block:true}),'real bidirectional social block');
const after=ok(await rpc('phase5_social_overview',a,{p_target:a.id}),'after block overview');
if(after.friends!==0||after.followers!==0||after.following!==0)
 stop('Blocked relationship left stale social counts');
denied(await rpc('phase5_social_follow',a,{
 p_target:b.id,p_follow:true,p_request_id:randomUUID()}),'blocked follow');
denied(await rpc('phase5_social_overview',a,{p_target:b.id}),'blocked profile counters');
console.log('PASS T59: 3 real disposable GoTrue JWT users, authenticated discovery, mutual friendships, idempotency, block severing, direct RLS denial, no fake social counts.');
