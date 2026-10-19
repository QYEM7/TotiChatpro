// TotiChat voice moderation relay. The database decides permission and logs
// the action; only server-side LiveKit credentials can remove a live participant.
// This is not a synthetic moderation acknowledgment: a failed SFU call remains
// explicitly unconfirmed and can safely be retried with the SAME request ID.
import {createClient} from '@supabase/supabase-js';
import {RoomServiceClient} from 'livekit-server-sdk';

const responseHeaders={
 'access-control-allow-origin':'*',
 'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
 'access-control-allow-methods':'POST,OPTIONS',
 'cache-control':'no-store',
 'content-type':'application/json; charset=utf-8'
};
const reply=(status:number,obj:Record<string,unknown>)=>
 new Response(JSON.stringify(obj),{status,headers:responseHeaders});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const mutatingVoice=new Set(['kick','ban','mute','release_seat']);
const enabled=new Set(['kick','ban','mute','release_seat']);
const env=(name:string)=>Deno.env.get(name)?.trim()||'';
function publishable(){
 const value=env('SUPABASE_PUBLISHABLE_KEYS');
 if(value)try{return String(JSON.parse(value).default||'');}catch(_){}
 return env('SUPABASE_ANON_KEY');
}
// Claims are decoded only AFTER Supabase Auth validates this exact bearer
// token and the verified-session RPC checks its session + MFA state.
function userClaims(jwt:string):Record<string,unknown>|null{
 try{
  const payload=jwt.split('.')[1];
  if(!payload||payload.length>5000)return null;
  const raw=atob(payload.replace(/-/g,'+').replace(/_/g,'/'));
  const value=JSON.parse(raw);
  return value && typeof value==='object' && !Array.isArray(value)
   ? value as Record<string,unknown> : null;
 }catch(_){return null;}
}
function livekitConfig(){
 const url=env('LIVEKIT_URL'),apiKey=env('LIVEKIT_API_KEY'),
  secret=env('LIVEKIT_API_SECRET');
 if(!url||!apiKey||!secret||secret.length<12)return null;
 try{
  const parsed=new URL(url);
  if(parsed.protocol!=='wss:'||parsed.username||parsed.password||
   parsed.search||parsed.hash||!parsed.hostname)return null;
  parsed.protocol='https:';
  return {apiEndpoint:parsed.origin,apiKey,secret};
 }catch(_){return null;}
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:responseHeaders});
 if(req.method!=='POST')return reply(405,{error:'METHOD_NOT_ALLOWED'});
 const authHeader=req.headers.get('authorization')||'';
 if(!authHeader.startsWith('Bearer ')||authHeader.length>4100)
  return reply(401,{error:'UNAUTHORIZED'});
 const length=Number(req.headers.get('content-length')||0);
 if(length>4096)return reply(413,{error:'REQUEST_TOO_LARGE'});
 let body:Record<string,unknown>;
 try{
  const raw=await req.text();
  if(raw.length>4096)return reply(413,{error:'REQUEST_TOO_LARGE'});
  body=JSON.parse(raw);
  if(!body||typeof body!=='object'||Array.isArray(body))throw Error();
 }catch(_){return reply(400,{error:'INVALID_JSON'});}
 const roomId=body.roomId,targetId=body.targetId,action=body.action,
  requestId=body.requestId,reason=body.reason??null;
 if(typeof roomId!=='string'||!uuid.test(roomId)||
  typeof targetId!=='string'||!uuid.test(targetId)||
  typeof requestId!=='string'||!uuid.test(requestId)||
  typeof action!=='string'||!enabled.has(action)||
  (reason!==null&&(typeof reason!=='string'||reason.length>300)))
  return reply(400,{error:'INVALID_MODERATION_REQUEST'});
 const backendUrl=env('SUPABASE_URL'),backendKey=publishable(),
  privilegedKey=env('SUPABASE_SERVICE_ROLE_KEY');
 if(!backendUrl||!backendKey||!privilegedKey)
  return reply(503,{error:'BACKEND_NOT_CONFIGURED'});
 // Fail CLOSED before the DB commits a voice-impacting action if no SFU exists.
 const lk=mutatingVoice.has(action)?livekitConfig():null;
 if(!lk)return reply(503,{error:'LIVEKIT_NOT_CONFIGURED',databaseCommitted:false});
 try{
  const supabase=createClient(backendUrl,backendKey,{
   global:{headers:{Authorization:authHeader}},
   auth:{persistSession:false,autoRefreshToken:false}
  });
  const userToken=authHeader.slice(7);
  const {data:auth,error:authError}=await supabase.auth.getUser(userToken);
  if(authError||!auth.user)return reply(401,{error:'INVALID_SESSION'});
  if(!auth.user.email_confirmed_at&&!auth.user.phone_confirmed_at)
   return reply(403,{error:'ACCOUNT_NOT_VERIFIED'});
  const {data:verifiedActor,error:sessionError}=
   await supabase.rpc('phase4_verified_session');
  if(sessionError||String(verifiedActor)!==auth.user.id)
   return reply(403,{error:'SESSION_NOT_VERIFIED',databaseCommitted:false});
  const claims=userClaims(userToken);
  if(!claims||claims['role']!=='authenticated'||
     claims['sub']!==auth.user.id||
     typeof claims['session_id']!=='string')
   return reply(401,{error:'INVALID_SESSION_CLAIMS',databaseCommitted:false});
  // The service role is NEVER sent to the Flutter client. A privileged RPC
  // revalidates these exact session claims via phase3.actor() and room ACLs.
  const trusted=createClient(backendUrl,privilegedKey,{
   auth:{persistSession:false,autoRefreshToken:false}
  });
  const {data,error}=await trusted.rpc('phase2_room_moderate_voice_relay',{
   p_verified_user_claims:claims,
   p_room_id:roomId,p_target:targetId,p_action:action,
   p_request_id:requestId,p_reason:reason
  });
  if(error){
   if(error.code==='42501')return reply(403,{error:'MODERATION_NOT_AUTHORIZED',databaseCommitted:false});
   if(/rate limit/i.test(error.message||''))return reply(429,{error:'MODERATION_RATE_LIMITED',databaseCommitted:false});
   return reply(409,{error:'MODERATION_REJECTED',databaseCommitted:false});
  }
  if(data?.success!==true||data?.roomId!==roomId||data?.targetId!==targetId)
   return reply(503,{error:'MODERATION_RESULT_UNVERIFIED',databaseCommitted:false});
  try{
   const api=new RoomServiceClient(lk.apiEndpoint,lk.apiKey,lk.secret);
   // Fail closed: drop all currently published tracks and prevent a stale
   // participant from continuing to talk after kick, ban or moderator mute.
   // LiveKit Cloud revokes the active token on participant removal.
   // Suppress a false 404 for an already-offline participant while revoking
   // stale tokens as supported by LiveKit Cloud. The SDK expects bigint
   // Unix seconds; LiveKit requires the cutoff within 60s of server time.
   // No optimistic success is returned if the SFU API itself fails.
   await api.removeParticipant(roomId,targetId,{
    revokeTokenTs: BigInt(Math.floor(Date.now()/1000))
   });
  }catch(err){
   console.error('TotiChat LiveKit moderation disconnect unconfirmed',
    err instanceof Error?err.name:'UNKNOWN');
   // DB state is committed, but voice still MAY be active. Not a success.
   return reply(503,{error:'VOICE_DISCONNECT_UNCONFIRMED',
    databaseCommitted:true,sfuDisconnected:false,retryWithSameRequestId:true});
  }
  return reply(200,{success:true,action,roomId,targetId,
   databaseCommitted:true,sfuDisconnected:true});
 }catch(err){
  console.error('TotiChat voice moderation failed',err instanceof Error?err.name:'UNKNOWN');
  return reply(500,{error:'INTERNAL_ERROR',databaseCommitted:false});
 }
});
