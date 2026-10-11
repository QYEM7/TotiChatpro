// TotiChat Staging LiveKit token authority (real sessions only).
// Never imports production credentials or trusts client-supplied VIP/mic/room roles.
import {createClient} from '@supabase/supabase-js';
import {AccessToken,TrackSource} from 'livekit-server-sdk';

const headers={
 'access-control-allow-origin':'*',
 'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
 'access-control-allow-methods':'POST,OPTIONS',
 'content-type':'application/json; charset=utf-8',
 'cache-control':'no-store'
};
const json=(status:number,body:Record<string,unknown>)=>
 new Response(JSON.stringify(body),{status,headers});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const env=(key:string)=>Deno.env.get(key)?.trim()||'';
function publicKey(){
 const v=env('SUPABASE_PUBLISHABLE_KEYS');
 if(v)try{return String(JSON.parse(v).default||'');}catch(_){}
 return env('SUPABASE_ANON_KEY');
}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return json(405,{error:'METHOD_NOT_ALLOWED'});
 const authHeader=req.headers.get('authorization')||'';
 if(!authHeader.startsWith('Bearer '))return json(401,{error:'UNAUTHORIZED'});
 let roomId='';
 try{
  const data=await req.json();
  roomId=typeof data?.roomId==='string'?data.roomId.trim():'';
  if(!uuid.test(roomId))return json(400,{error:'INVALID_ROOM_ID'});
 }catch(_){return json(400,{error:'INVALID_JSON'});}
 const url=env('SUPABASE_URL'),key=publicKey();
 if(!url||!key)return json(503,{error:'BACKEND_NOT_CONFIGURED'});
 try{
  const supabase=createClient(url,key,{
   global:{headers:{Authorization:authHeader}},
   auth:{persistSession:false,autoRefreshToken:false}
  });
  const {data:userResult,error:userError}=await supabase.auth.getUser(authHeader.slice(7));
  if(userError||!userResult.user)return json(401,{error:'INVALID_SESSION'});
  const member=userResult.user;
  if(!member.email_confirmed_at&&!member.phone_confirmed_at)
   return json(403,{error:'ACCOUNT_NOT_VERIFIED'});
  const lkUrl=env('LIVEKIT_URL'),lkKey=env('LIVEKIT_API_KEY'),lkSecret=env('LIVEKIT_API_SECRET');
  if(!lkUrl||!lkKey||!lkSecret)return json(503,{error:'LIVEKIT_NOT_CONFIGURED'});
  try{
   const parsed=new URL(lkUrl);
   if(parsed.protocol!=='wss:'||!parsed.hostname||parsed.username||parsed.password)throw new Error('unsafe url');
  }catch(_){return json(503,{error:'LIVEKIT_INVALID_URL'});}
  // This database RPC checks membership, assigned seat, mute state, and 20/min budget.
  const {data:permission,error:permissionError}=await supabase.rpc(
   'phase2_voice_token_preflight',{p_room_id:roomId}
  );
  if(permissionError){
   const msg=String(permissionError.message||'');
   if(msg.includes('VOICE_RATE_LIMITED'))return json(429,{error:'VOICE_RATE_LIMITED'});
   if(permissionError.code==='42501'||msg.includes('ROOM_MEMBERSHIP_REQUIRED'))
    return json(403,{error:'ROOM_MEMBERSHIP_REQUIRED'});
   return json(503,{error:'ROOM_AUTHORIZATION_FAILED'});
  }
  if(permission?.roomId!==roomId)return json(403,{error:'ROOM_AUTHORIZATION_FAILED'});
  const canPublish=permission?.canPublish===true;
  const token=new AccessToken(lkKey,lkSecret,{identity:member.id,ttl:'5m'});
  token.addGrant({
   roomJoin:true,room:roomId,canSubscribe:true,canPublish,
   canPublishData:false,canUpdateOwnMetadata:false,
   canPublishSources:canPublish?[TrackSource.MICROPHONE]:[]
  });
  return json(200,{url:lkUrl,token:await token.toJwt(),roomId,
   participant:member.id,canPublish});
 }catch(error){
  console.error('TotiChat voice authorization failed',error instanceof Error?error.name:'UNKNOWN');
  return json(500,{error:'INTERNAL_ERROR'});
 }
});
