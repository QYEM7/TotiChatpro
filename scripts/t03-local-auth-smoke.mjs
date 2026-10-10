/* T03 local-only Supabase full-stack integration. Auth/REST/Storage are REAL ephemeral services. */
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {isIP} from 'node:net';
const fail=m=>{throw Error('BLOCKED T03 local integration: '+m)};
const input=process.argv[2];if(!input)fail('local status file required');
let conf;try{conf=JSON.parse(readFileSync(input,'utf8'))}catch{fail('invalid local CLI status JSON')}
const root=String(conf.API_URL||''),anon=String(conf.ANON_KEY||'');
let url;try{url=new URL(root)}catch{fail('no local API URL')}
if(url.protocol!=='http:'||!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!isIP(url.hostname.replace(/^\[|\]$/g,''))&&url.hostname!=='localhost'||url.username||url.password||url.search||url.hash)fail('API must point at an unlinked local HTTP Supabase instance');
if(!anon||!anon.startsWith('eyJ'))fail('local anon key missing');
async function call(p,{method='GET',bearer=anon,body}={}){
 const response=await fetch(new URL(p,url.origin),{
  method,signal:AbortSignal.timeout(12000),
  headers:{apikey:anon,Authorization:'Bearer '+bearer,...(body?{'Content-Type':'application/json'}:{})},
  ...(body?{body:JSON.stringify(body)}:{})
 });
 let payload;try{payload=await response.json()}catch{payload=null}
 return {status:response.status,data:payload};
}
const h=await call('/auth/v1/health');
if(h.status!==200)fail('GoTrue Auth health not 200, HTTP '+h.status);
const token=randomBytes(7).toString('hex');
const users=[];
for(const index of [1,2]){
 const user=await call('/auth/v1/signup',{method:'POST',body:{
  email:'totichat-t03-'+token+'-'+index+'@example.test',
  password:randomBytes(24).toString('base64url'),
  data:{display_name:'T03 isolated QA '+index}
 }});
 if(user.status!==200||!user.data?.user?.id||!user.data?.access_token)fail('local Auth signup requires confirmed session; HTTP '+user.status);
 const who=await call('/auth/v1/user',{bearer:user.data.access_token});
 if(who.status!==200||who.data?.id!==user.data.user.id)fail('JWT Auth identity mismatch');
 const ref=await call('/rest/v1/profiles?select=id,display_name&id=eq.'+user.data.user.id,{bearer:user.data.access_token});
 if(ref.status!==200||!Array.isArray(ref.data)||ref.data.length!==1||ref.data[0].id!==user.data.user.id)fail('new user profile does not match real RLS identity');
 users.push(user.data.user.id);
}
if(users[0]===users[1])fail('two isolated auth accounts collapsed into one user ID');
const rejected=await call('/rest/v1/profiles?select=id&limit=1');
if(![401,403].includes(rejected.status))fail('anonymous request to private profile endpoint unexpectedly succeeded (HTTP '+rejected.status+')');
const catalog=await call('/rest/v1/home_banners?select=id&limit=1');
if(catalog.status!==200||!Array.isArray(catalog.data))fail('public banner RLS smoke failed (HTTP '+catalog.status+')');
const storage=await call('/storage/v1/bucket');
if(![200,401,403].includes(storage.status))fail('Storage service HTTP health failed (HTTP '+storage.status+')');
console.log('PASS T03: ephemeral GoTrue Auth created two distinct REAL local accounts; sessions and RLS profiles verified; anon blocked; REST catalog and Storage responded. No production connectivity or credentials.');
