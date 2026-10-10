/* T49: real Storage OBJECT byte restore, NOT a production backup.
 * Runs against disposable, unlinked local Supabase API only.
 * No persistent dumps, credentials, logs of object data, or staging claims.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,createHash,randomUUID} from 'node:crypto';
import {isIP} from 'node:net';
const abort=message=>{throw Error('T49 local Storage restoration: '+message)};
if(process.env.T49_DISPOSABLE_ONLY!=='YES')abort('explicit disposable-only flag required');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','PGHOST','DATABASE_URL'].some(k=>process.env[k]))
 abort('linked/remote DB credentials forbidden');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'));}catch{abort('missing local Supabase status JSON');}
let url;try{url=new URL(String(cfg.API_URL||''));}catch{abort('API URL missing');}
if(url.protocol!=='http:'||!['localhost','127.0.0.1'].includes(url.hostname)||
 (url.hostname!=='localhost'&&!isIP(url.hostname))||url.username||url.password||
 url.pathname!=='/'||url.search||url.hash)abort('refuse any non-loopback Supabase API');
const anon=String(cfg.ANON_KEY||'');
if(!anon.startsWith('eyJ'))abort('local anonymous JWT required');
const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
async function req(path,{jwt=anon,method='GET',body,type='application/json',accept}={}){
 if(!path.startsWith('/'))abort('relative route required');
 const headers={apikey:anon,Authorization:'Bearer '+jwt,...(accept?{Accept:accept}:{})};
 if(body!==undefined)headers['Content-Type']=type;
 const res=await fetch(new URL(path,url.origin),{method,headers,
  ...(body===undefined?{}:{body:Buffer.isBuffer(body)?body:JSON.stringify(body)}),
  signal:AbortSignal.timeout(15000),cache:'no-store'});
 const bytes=Buffer.from(await res.arrayBuffer());
 let data=null;try{data=JSON.parse(bytes.toString('utf8'));}catch{}
 return {status:res.status,bytes,data};
}
function success(result,label){
 if(result.status<200||result.status>=300)abort(label+' unexpected HTTP '+result.status+': '+
  String(result.data?.message||result.data?.error||'').slice(0,130));
 return result;
}
const key=randomBytes(8).toString('hex'),actors=[];
for(const n of [1,2,3]){
 const signup=success(await req('/auth/v1/signup',{method:'POST',body:{
  email:'t49-local-storage-'+key+'-'+n+'@example.test',
  password:randomBytes(24).toString('base64url'),
  data:{display_name:'T49 Disposable '+n}
 }}),'local signup');
 if(!signup.data?.user?.id||!signup.data?.access_token)abort('GoTrue auth token not issued');
 actors.push({id:signup.data.user.id,jwt:signup.data.access_token});
}
const [owner,member,outsider]=actors;
const avatar=Buffer.from('UklGRjwAAABXRUJQVlA4IDAAAAAQAgCdASoBAAEAAUAmJaACdLoB+AH4AAPIAP7uCmf+wdMGXP8V7/16IPEG/U0AAAA=','base64');
const avatarPath=owner.id+'/'+randomUUID()+'.webp';
const avatarObject='/storage/v1/object/profile-avatars/'+avatarPath;
const avatarPublic='/storage/v1/object/public/profile-avatars/'+avatarPath;
const wrongAvatar=await req(avatarObject,{jwt:outsider.jwt,method:'POST',type:'image/webp',body:avatar});
if(wrongAvatar.status>=200&&wrongAvatar.status<300)abort('outsider uploaded into owner avatar prefix');
success(await req(avatarObject,{jwt:owner.jwt,method:'POST',type:'image/webp',body:avatar}),'avatar upload');
const savedAvatar=success(await req(avatarPublic,{jwt:anon}),'public avatar byte backup').bytes;
if(sha256(savedAvatar)!==sha256(avatar))abort('avatar backup bytes mismatch');
const wrongDeletion=await req(avatarObject,{jwt:outsider.jwt,method:'DELETE'});
if(wrongDeletion.status>=200&&wrongDeletion.status<300){
 const still=await req(avatarPublic);
 if(still.status!==200)abort('outsider erased owner avatar');
}
success(await req(avatarObject,{jwt:owner.jwt,method:'DELETE'}),'owner avatar delete');
const missingAvatar=await req(avatarPublic);
if(missingAvatar.status>=200&&missingAvatar.status<300)abort('avatar was never actually deleted');
success(await req(avatarObject,{jwt:owner.jwt,method:'POST',type:'image/webp',body:savedAvatar}),'avatar restore upload');
const restoredAvatar=success(await req(avatarPublic),'avatar restored byte download').bytes;
if(sha256(restoredAvatar)!==sha256(savedAvatar))abort('avatar SHA256 mismatch after restore');
console.log('PASS T49: public avatar binary uploaded, malicious owner-prefix upload denied, source deleted, SHA256-identical bytes restored.');
// Voice uses a PRIVATE bucket, authenticated download and real room membership,
// not fake metadata in SQL. The fixture is bytes only, not playable/licensed audio.
const created=success(await req('/rest/v1/rpc/phase2_room_create',{
 jwt:owner.jwt,method:'POST',body:{p_title:'T49 Restore Room',p_is_private:false}
}),'private-voice fixture room create');
const room=created.data;
if(typeof room!=='string'||!/^[-0-9a-f]{36}$/i.test(room))abort('room create did not return UUID');
success(await req('/rest/v1/rpc/phase2_room_join',{
 jwt:member.jwt,method:'POST',body:{p_room_id:room}
}),'private-voice member join');
const voiceId=randomUUID(),voicePath=owner.id+'/'+room+'/'+voiceId+'.webm';
const voiceRoute='/storage/v1/object/voice-messages/'+voicePath;
const privateRoute='/storage/v1/object/authenticated/voice-messages/'+voicePath;
const voice=Buffer.concat([Buffer.from('1a45dfa3','hex'),randomBytes(79)]);
const unauthorizedPut=await req(voiceRoute,{jwt:outsider.jwt,method:'POST',type:'audio/webm',body:voice});
if(unauthorizedPut.status>=200&&unauthorizedPut.status<300)
 abort('outsider uploaded private room audio');
success(await req(voiceRoute,{jwt:owner.jwt,method:'POST',type:'audio/webm',body:voice}),'owner private voice upload');
success(await req('/rest/v1/rpc/phase4_voice_message',{jwt:owner.jwt,method:'POST',body:{
 p_action:'create',p_id:voiceId,p_room_id:room,p_path:voicePath,p_mime:'audio/webm',
 p_size:voice.length,p_duration:1000
}}),'voice metadata register');
const denied=await req(privateRoute,{jwt:outsider.jwt});
if(denied.status>=200&&denied.status<300)abort('outsider read private voice audio');
const publicTry=await req('/storage/v1/object/public/voice-messages/'+voicePath,{jwt:anon});
if(publicTry.status>=200&&publicTry.status<300)abort('private voice leaked through public route');
const before=success(await req(privateRoute,{jwt:member.jwt}),'member private audio backup').bytes;
if(sha256(before)!==sha256(voice))abort('private voice bytes mismatch before deletion');
const unauthorizedDelete=await req(voiceRoute,{jwt:outsider.jwt,method:'DELETE'});
if(unauthorizedDelete.status>=200&&unauthorizedDelete.status<300){
 const still=await req(privateRoute,{jwt:owner.jwt});
 if(still.status!==200)abort('outsider deleted owner private audio');
}
success(await req(voiceRoute,{jwt:owner.jwt,method:'DELETE'}),'owner voice deletion');
const deleted=await req(privateRoute,{jwt:owner.jwt});
if(deleted.status>=200&&deleted.status<300)abort('voice audio still exists after deletion');
success(await req(voiceRoute,{jwt:owner.jwt,method:'POST',type:'audio/webm',body:before}),'owner private voice restore');
const after=success(await req(privateRoute,{jwt:member.jwt}),'private member download after restore').bytes;
if(sha256(after)!==sha256(before))abort('voice object SHA256 changed during recovery');
const outsiderAfter=await req(privateRoute,{jwt:outsider.jwt});
if(outsiderAfter.status>=200&&outsiderAfter.status<300)
 abort('restored voice private access widened');
console.log('PASS T49: PRIVATE audio object backed up from real local Storage, original deleted, SHA256 byte-identical restored, room member allowed and outsider/public denied.');
console.log('PASS T49: BOTH local Storage classes restored; this is NOT production Storage backup, audio playback proof or independent offsite recovery.');
