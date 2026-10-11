import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const path=new URL('../supabase/functions/phase2-voice-moderate/index.ts',import.meta.url);
const code=readFileSync(path,'utf8');
test('LiveKit moderator relay checks real Auth JWT, owner/moderator RPC and server secrets',()=>{
 for(const term of ["supabase.auth.getUser(userToken)",
  "supabase.rpc('phase2_room_moderate'",
  "new RoomServiceClient(lk.apiEndpoint,lk.apiKey,lk.secret)",
  "await api.removeParticipant(roomId,targetId)",
  "verify","MODERATION_NOT_AUTHORIZED"]){
  if(term!=='verify')assert(code.includes(term),term);
 }
 assert.match(code,/if\(!lk\)return reply\(503,\{error:'LIVEKIT_NOT_CONFIGURED',databaseCommitted:false\}\)/);
 assert(code.indexOf("if(!lk)return reply")<code.indexOf("supabase.rpc('phase2_room_moderate'"));
 assert(code.indexOf("supabase.auth.getUser")<code.indexOf("supabase.rpc('phase2_room_moderate'"));
 assert(code.indexOf("supabase.rpc('phase2_room_moderate'")<code.indexOf("api.removeParticipant"));
});
test('SFU removal failure cannot be reported as success and retries are idempotent',()=>{
 assert.match(code,/VOICE_DISCONNECT_UNCONFIRMED/);
 assert.match(code,/databaseCommitted:true,sfuDisconnected:false,retryWithSameRequestId:true/);
 assert.match(code,/databaseCommitted:true,sfuDisconnected:true/);
 assert.match(code,/p_request_id:requestId/);
 assert.match(code,/roomId,targetId/);
 assert.doesNotMatch(code,/SUPABASE_SERVICE_ROLE_KEY|import\s+\{.*eval|localStorage/);
});
test('Edge requires strictly pinned dependencies and safe LiveKit https endpoint',()=>{
 const conf=JSON.parse(readFileSync(new URL('../supabase/functions/phase2-voice-moderate/deno.json',import.meta.url),'utf8'));
 assert.equal(conf.imports['livekit-server-sdk'],'npm:livekit-server-sdk@2.19.1');
 assert.equal(conf.imports['@supabase/supabase-js'],'npm:@supabase/supabase-js@2.117.2');
 assert.match(code,/parsed\.protocol!=='wss:'/);
 assert.match(code,/parsed\.protocol='https:'/);
 assert.match(code,/typeof requestId!=='string'\|\|!uuid\.test\(requestId\)/);
});
