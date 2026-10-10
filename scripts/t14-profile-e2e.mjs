/* T14 true GoTrue+Storage+PostgREST local integration with two real JWT users.
 * API must point to loopback only. No production secrets or writes.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const die=m=>{throw Error('T14 isolated identity/storage smoke: '+m)};
const cfg=JSON.parse(readFileSync(process.argv[2],'utf8'));
let root;try{root=new URL(cfg.API_URL)}catch{die('missing local Supabase status')}
if(root.protocol!=='http:'||!['127.0.0.1','localhost','[::1]'].includes(root.hostname)||root.username||root.password||root.search||root.hash)die('remote Supabase target forbidden');
const apikey=String(cfg.ANON_KEY||'');if(!apikey.startsWith('eyJ'))die('missing local key');
async function req(p,{jwt=apikey,method='GET',body,type='application/json'}={}){
 const resp=await fetch(new URL(p,root.origin),{method,signal:AbortSignal.timeout(12000),
  headers:{apikey,Authorization:'Bearer '+jwt,...(body?{'Content-Type':type}:{})},
  ...(body?{body:type==='application/json'?JSON.stringify(body):body}:{})
 });
 let data;try{data=await resp.json()}catch{data=null}
 return {status:resp.status,data};
}
const prefix=randomBytes(5).toString('hex'),users=[];
for(const i of [1,2]){
 const a=await req('/auth/v1/signup',{method:'POST',body:{
  email:'t14-'+prefix+'-'+i+'@example.test',password:randomBytes(24).toString('base64url')
 }});
 if(a.status!==200||!a.data?.access_token||!a.data?.user?.id)die('GoTrue signup failed: '+a.status);
 users.push({id:a.data.user.id,jwt:a.data.access_token});
}
const [alice,bob]=users;
const name=alice.id+'/'+randomUUID()+'.jpg';
const jpeg=new Uint8Array([255,216,255,224,0,16,74,70,73,70,0,1,255,217]);
const blocked=await req('/storage/v1/object/profile-avatars/'+name,{
 jwt:bob.jwt,method:'POST',body:jpeg,type:'image/jpeg'});
if(blocked.status<400||blocked.status>=500)die('cross-account upload accepted or server broken: '+blocked.status);
const uploaded=await req('/storage/v1/object/profile-avatars/'+name,{
 jwt:alice.jwt,method:'POST',body:jpeg,type:'image/jpeg'});
if(![200,201].includes(uploaded.status))die('own avatar upload failed: HTTP '+uploaded.status+' '+JSON.stringify(uploaded.data).slice(0,120));
const publicGet=await fetch(new URL('/storage/v1/object/public/profile-avatars/'+name,root.origin),{signal:AbortSignal.timeout(12000)});
if(publicGet.status!==200)die('public profile photo not downloadable: '+publicGet.status);
const path='storage:profile-avatars/'+name;
const own=await req('/rest/v1/profiles?id=eq.'+alice.id+'&select=id,avatar_url',{
 jwt:alice.jwt,method:'PATCH',body:{avatar_url:path}});
if(own.status!==200&&own.status!==204)die('owner profile PATCH failed '+own.status);
const rows=await req('/rest/v1/profiles?id=eq.'+alice.id+'&select=id,avatar_url',{jwt:alice.jwt});
if(rows.status!==200||rows.data?.[0]?.avatar_url!==path)die('owner avatar path not persisted');
const idor=await req('/rest/v1/profiles?id=eq.'+alice.id+'&select=id,avatar_url',{
 jwt:bob.jwt,method:'PATCH',body:{avatar_url:'storage:profile-avatars/'+bob.id+'/'+randomUUID()+'.jpg'}});
if(idor.status===200&&Array.isArray(idor.data)&&idor.data.length)die('cross-user profile update succeeded');
const check=await req('/rest/v1/profiles?id=eq.'+alice.id+'&select=id,avatar_url',{jwt:bob.jwt});
if(check.data?.[0]?.avatar_url!==path)die('cross-user mutation changed saved avatar');
console.log('PASS T14: two genuine disposable GoTrue JWT identities; unauthorized avatar POST denied; owner upload/public image URL/owner profile PATCH succeeds; cross-user profile IDOR denied. Production untouched.');
