// TotiChat Phase 2 — authoritative LiveKit room credentials (REAL ONLY).
// Adapted conceptually from the old project; its data/config are NOT reused.
import {createClient} from '@supabase/supabase-js';
import {AccessToken,TrackSource} from 'livekit-server-sdk';
import {rateVoiceRequest} from './rate-limit.mjs';

const headers={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
  'access-control-allow-methods':'POST,OPTIONS',
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store'
};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers});
const validUUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function env(name:string){
  return Deno.env.get(name)?.trim()||'';
}
function browserKey(){
  const v=env('SUPABASE_PUBLISHABLE_KEYS');
  if(v){
    try{const data=JSON.parse(v);if(data.default)return String(data.default);}catch(_){}
  }
  return env('SUPABASE_ANON_KEY');
}
Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
  if(request.method!=='POST')return json(405,{error:'METHOD_NOT_ALLOWED'});
  const bearer=request.headers.get('authorization')||'';
  if(!bearer.startsWith('Bearer '))return json(401,{error:'UNAUTHORIZED'});
  // Auth failures are counted too. Credentials required before Edge cutover.
  const budget=await rateVoiceRequest(bearer,{
    url:env('UPSTASH_REDIS_REST_URL'),token:env('UPSTASH_REDIS_REST_TOKEN'),
    salt:env('VOICE_RATE_LIMIT_SALT')
  });
  if(!budget.allowed)return json(budget.status,{error:budget.code});
  let roomId:string;
  try{
    const body=await request.json();
    roomId=typeof body?.roomId==='string'?body.roomId.trim():'';
    if(!validUUID.test(roomId))return json(400,{error:'INVALID_ROOM_ID'});
  }catch(_){return json(400,{error:'INVALID_JSON'});}
  const supabaseUrl=env('SUPABASE_URL');
  const anon=browserKey();
  if(!supabaseUrl||!anon)return json(503,{error:'BACKEND_NOT_CONFIGURED'});
  try{
    const db=createClient(supabaseUrl,anon,{
      global:{headers:{Authorization:bearer}},
      auth:{persistSession:false,autoRefreshToken:false}
    });
    const {data:who,error:userError}=await db.auth.getUser();
    if(userError||!who.user)return json(401,{error:'INVALID_SESSION'});
    const userId=who.user.id;
    const {data:verified,error:verificationError}=await db.rpc('phase4_verified_session');
    if(verificationError||verified!==userId)return json(403,{error:'VERIFIED_SESSION_REQUIRED'});
    const [roomResult,memberResult]=await Promise.all([
      db.from('rooms').select('id,is_private').eq('id',roomId).maybeSingle(),
      db.from('room_members').select('room_id,user_id,seat_no,is_muted')
        .eq('room_id',roomId).eq('user_id',userId).maybeSingle()
    ]);
    if(roomResult.error||memberResult.error)return json(500,{error:'ROOM_LOOKUP_FAILED'});
    if(!roomResult.data||!memberResult.data)return json(403,{error:'ROOM_MEMBERSHIP_REQUIRED'});
    const livekitUrl=env('LIVEKIT_URL');
    const livekitKey=env('LIVEKIT_API_KEY');
    const livekitSecret=env('LIVEKIT_API_SECRET');
    if(!livekitUrl||!livekitKey||!livekitSecret)return json(503,{error:'LIVEKIT_NOT_CONFIGURED'});
    if(!/^wss:\/\/[^/]+/i.test(livekitUrl))return json(503,{error:'LIVEKIT_INVALID_URL'});
    const canPublish=memberResult.data.seat_no!==null&&!memberResult.data.is_muted;
    const token=new AccessToken(livekitKey,livekitSecret,{
      identity:userId,ttl:'10m'
    });
    token.addGrant({
      roomJoin:true,
      room:roomId,
      canSubscribe:true,
      canPublish,
      canPublishData:false,
      canUpdateOwnMetadata:false,
      canPublishSources:canPublish?[TrackSource.MICROPHONE]:[]
    });
    return json(200,{
      url:livekitUrl,
      token:await token.toJwt(),
      roomId,
      participant:userId,
      canPublish
    });
  }catch(error){
    console.error('TotiChat voice token error',error instanceof Error?error.message:'unknown');
    return json(500,{error:'INTERNAL_ERROR'});
  }
});
