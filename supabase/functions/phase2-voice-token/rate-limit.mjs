/* T06: durable voice-token request budget. Edge-only Redis REST.
 * Configure URL, token and HMAC salt before deploying the guarded function.
 * No in-memory counters: concurrency/restarts must not bypass the budget.
 */
const LUA="local a=redis.call('INCR',KEYS[1]);if a==1 then redis.call('PEXPIRE',KEYS[1],ARGV[1]) end;local b=redis.call('INCR',KEYS[2]);if b==1 then redis.call('PEXPIRE',KEYS[2],ARGV[1]) end;return {a,b}";
const encoder=new TextEncoder();
const hex=a=>Array.from(new Uint8Array(a),n=>n.toString(16).padStart(2,'0')).join('');
export async function rateVoiceRequest(bearer,{url,token,salt,fetcher=fetch,now=Date.now()}={}){
 if(typeof bearer!=='string'||!bearer.startsWith('Bearer ')||bearer.length>4096)return {allowed:false,status:401,code:'UNAUTHORIZED'};
 let endpoint;try{endpoint=new URL(url)}catch{return {allowed:false,status:503,code:'VOICE_RATE_LIMIT_UNCONFIGURED'}};
 if(endpoint.protocol!=='https:'||!endpoint.hostname.endsWith('.upstash.io')||endpoint.hostname==='upstash.io'||endpoint.username||endpoint.password||endpoint.pathname!=='/'||endpoint.search||endpoint.hash||
 typeof token!=='string'||token.length<24||typeof salt!=='string'||salt.length<32){
  return {allowed:false,status:503,code:'VOICE_RATE_LIMIT_UNCONFIGURED'};
 }
 try{
  const key=await crypto.subtle.importKey('raw',encoder.encode(salt),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const signature=await crypto.subtle.sign('HMAC',key,encoder.encode(bearer));
  const bucket=Math.floor(now/60000);
  const payload=['EVAL',LUA,'2','totichat:voice:global:'+bucket,'totichat:voice:actor:'+bucket+':'+hex(signature),'60000'];
  const res=await fetcher(endpoint.origin,{
   method:'POST',
   headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},
   body:JSON.stringify(payload),
   signal:AbortSignal.timeout(3000)
  });
  if(!res.ok)return {allowed:false,status:503,code:'VOICE_RATE_LIMIT_UNAVAILABLE'};
  const body=await res.json();
  const counts=body?.result;
  if(!Array.isArray(counts)||counts.length!==2||counts.some(n=>!Number.isSafeInteger(n)||n<1)){
   return {allowed:false,status:503,code:'VOICE_RATE_LIMIT_UNAVAILABLE'};
  }
  if(counts[0]>600||counts[1]>12)return {allowed:false,status:429,code:'VOICE_RATE_LIMITED'};
  return {allowed:true};
 }catch{return {allowed:false,status:503,code:'VOICE_RATE_LIMIT_UNAVAILABLE'};}
}
