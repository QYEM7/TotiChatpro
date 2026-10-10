/* T14 real local-only signup + binary avatar Storage upload and profile read-back. */
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const die=s=>{throw Error('T14 local avatar QA: '+s)};
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{die('local CLI status missing')}
const origin=new URL(cfg.API_URL);
if(origin.protocol!=='http:'||!['localhost','127.0.0.1','[::1]'].includes(origin.hostname))die('NOT a local Supabase');
const anon=String(cfg.ANON_KEY||'');
if(!anon.startsWith('eyJ'))die('local anon JWT missing');
async function call(path,token=anon,{method='GET',body,contentType}={}){
 const headers={apikey:anon,Authorization:'Bearer '+token};
 if(body!==undefined)headers['Content-Type']=contentType||'application/json';
 const response=await fetch(new URL(path,origin.origin),{method,headers,
  ...(body!==undefined?{body:contentType==='image/webp'?body:JSON.stringify(body)}:{}),
  signal:AbortSignal.timeout(12000)});
 const output=await response.text();
 let parsed;try{parsed=JSON.parse(output)}catch{parsed=output}
 return {status:response.status,data:parsed};
}
const seed=randomBytes(6).toString('hex');
const ids=[];
for(const i of [1,2]){
 const res=await call('/auth/v1/signup',anon,{method:'POST',body:{
  email:'totichat-t14-'+seed+'-'+i+'@example.test',password:randomBytes(28).toString('base64url'),
  data:{display_name:'T14 Avatar User '+i}
 }});
 if(res.status!==200||!res.data?.access_token||!res.data.user?.id)die('real ephemeral signup failed');
 ids.push({id:res.data.user.id,jwt:res.data.access_token});
}
const webp=Buffer.from('UklGRjwAAABXRUJQVlA4IDAAAAAQAgCdASoBAAEAAUAmJaACdLoB+AH4AAPIAP7uCmf+wdMGXP8V7/16IPEG/U0AAAA=','base64');
const path=ids[0].id+'/'+crypto.randomUUID()+'.webp';
const upload='/storage/v1/object/profile-avatars/'+path;
const reject=await call(upload,ids[1].jwt,{method:'POST',contentType:'image/webp',body:webp});
if(![400,401,403].includes(reject.status))die('other user was allowed to upload in owner directory: '+reject.status);
const put=await call(upload,ids[0].jwt,{method:'POST',contentType:'image/webp',body:webp});
if(![200,201].includes(put.status))die('owner upload failed '+put.status+' '+String(put.data).slice(0,80));
const publicUrl=origin.origin+'/storage/v1/object/public/profile-avatars/'+path;
const updated=await call('/rest/v1/profiles?id=eq.'+ids[0].id+'&select=id,avatar_url,display_name',ids[0].jwt,{
 method:'PATCH',body:{avatar_url:publicUrl}
});
if(![200,204].includes(updated.status))die('profile PATCH failed '+updated.status);
const read=await call('/rest/v1/profiles?id=eq.'+ids[0].id+'&select=id,avatar_url',ids[1].jwt);
if(read.status!==200||read.data?.[0]?.avatar_url!==publicUrl)die('other authenticated user cannot view publicly shown profile image');
const unauthorized=await call('/rest/v1/profiles?id=eq.'+ids[0].id+'&select=id,avatar_url',ids[1].jwt,{
 method:'PATCH',body:{avatar_url:'https://invalid.example/forged.webp'}});
if(![200,204,401,403].includes(unauthorized.status))die('unauthorized patch unexpected response');
const verify=await call('/rest/v1/profiles?id=eq.'+ids[0].id+'&select=avatar_url',ids[0].jwt);
if(verify.data?.[0]?.avatar_url!==publicUrl)die('another user tampered with avatar URL');
const downloaded=await fetch(publicUrl,{signal:AbortSignal.timeout(12000)});
if(downloaded.status!==200||Number(downloaded.headers.get('content-length')||webp.length)!==webp.length)die('public avatar bytes missing');
console.log('PASS T14: 2 real disposable GoTrue users, binary WebP Storage upload, public image read, profile update; cross-user upload and profile edit denied.');
