/* Real GoTrue + PostgREST T23 music bookmarks and room queue, loopback only. */
import {readFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
const fail=s=>{throw Error('T23 local Auth/music QA: '+s)};
const config=JSON.parse(readFileSync(process.argv[2],'utf8'));
let target;try{target=new URL(config.API_URL)}catch{fail('missing disposable Supabase URL')}
if(target.protocol!=='http:'||!['localhost','127.0.0.1','[::1]'].includes(target.hostname)||
 target.username||target.password||target.search||target.hash)fail('production/remote host is forbidden');
const anon=String(config.ANON_KEY||'');
if(!anon.startsWith('eyJ'))fail('missing local anon JWT');
async function call(path,{jwt=anon,method='GET',body,represent=false}={}){
 const r=await fetch(new URL(path,target.origin),{
  method,signal:AbortSignal.timeout(12000),
  headers:{apikey:anon,Authorization:'Bearer '+jwt,
   ...(body!==undefined?{'Content-Type':'application/json'}:{}),
   ...(represent?{Prefer:'return=representation'}:{})},
  ...(body!==undefined?{body:JSON.stringify(body)}:{})
 });
 let output;try{output=await r.json()}catch{output=null}
 return {code:r.status,body:output};
}
const required=(r,label)=>{if(r.code<200||r.code>=300)fail(label+' HTTP '+r.code+': '+JSON.stringify(r.body).slice(0,160));return r.body};
const nonce=randomBytes(5).toString('hex'),users=[];
for(let i=0;i<3;i++){
 const data=required(await call('/auth/v1/signup',{method:'POST',body:{
  email:'t23-'+nonce+'-'+i+'@example.test',password:randomBytes(24).toString('base64url')
 }}),'signup');
 if(!data?.user?.id||!data.access_token)fail('local signup lacks real auth token');
 users.push({id:data.user.id,jwt:data.access_token});
}
const [owner,guest,outsider]=users;
const rows=(table,q='')=>'/rest/v1/'+table+'?'+q;
const saved=required(await call(rows('user_music_bookmarks','select=id,title,artist,reference_url'),{
 jwt:owner.jwt,method:'POST',represent:true,body:{
 owner_id:owner.id,title:'My independently licensed track reference',
 artist:'QA local metadata',reference_url:'https://example.test/music/owned'
 }}),'owner bookmark save');
if(!Array.isArray(saved)||saved.length!==1||!saved[0]?.id)fail('bookmark did not return a persisted database row');
const bookmark=saved[0];
const again=required(await call(rows('user_music_bookmarks','select=id,title'),{jwt:owner.jwt}),'owner music read');
if(!Array.isArray(again)||again.length!==1)fail('saved track lost after reloading list');
const guestSaved=required(await call(rows('user_music_bookmarks','select=id'),{jwt:guest.jwt}),'guest saved list');
if(!Array.isArray(guestSaved)||guestSaved.length)fail('saved music exposed to another user');
const blockedInsert=await call(rows('user_music_bookmarks','select=id'),{
 jwt:guest.jwt,method:'POST',represent:true,body:{owner_id:owner.id,title:'spoofed owned song'}
});
if(blockedInsert.code>=200&&blockedInsert.code<300)fail('guest inserted into owner music library');
const room=required(await call('/rest/v1/rpc/phase2_room_create',{
 jwt:owner.jwt,method:'POST',body:{p_title:'T23 secure music QA',p_is_private:false}
}),'real owner room');
if(!/^[0-9a-f-]{36}$/i.test(room))fail('created room UUID absent');
required(await call('/rest/v1/rpc/phase2_room_join',{
 jwt:guest.jwt,method:'POST',body:{p_room_id:room}
}),'guest join');
const before=required(await call(rows('room_music_queue','select=id,room_id,title'),{
 jwt:guest.jwt
}),'guest queue initial list');
if(!Array.isArray(before)||before.length)fail('local room queue was not empty');
const queueInsert={room_id:room,bookmark_id:bookmark.id,added_by:owner.id,
 title:bookmark.title,artist:bookmark.artist};
const guestTry=await call(rows('room_music_queue','select=id'),{
 jwt:guest.jwt,method:'POST',represent:true,body:{...queueInsert,added_by:guest.id}
});
if(guestTry.code>=200&&guestTry.code<300)fail('ordinary room guest added to owner queue');
const queue=required(await call(rows('room_music_queue','select=id,room_id,title'),{
 jwt:owner.jwt,method:'POST',represent:true,body:queueInsert
}),'room Owner queues chosen own bookmark');
if(!Array.isArray(queue)||queue.length!==1||queue[0].room_id!==room)fail('queue insert not persisted');
const visible=required(await call(rows('room_music_queue','select=id,title&room_id=eq.'+room),{
 jwt:guest.jwt
}),'joined guest queue read');
if(!Array.isArray(visible)||visible[0]?.id!==queue[0].id)fail('room member cannot view queued music metadata');
const hidden=required(await call(rows('room_music_queue','select=id&room_id=eq.'+room),{
 jwt:outsider.jwt
}),'outsider queue read');
if(!Array.isArray(hidden)||hidden.length)fail('private queued music metadata leaked to nonmember');
const deniedDelete=await call(rows('room_music_queue','id=eq.'+queue[0].id),{
 jwt:guest.jwt,method:'DELETE',represent:true
});
if(deniedDelete.code===200&&Array.isArray(deniedDelete.body)&&deniedDelete.body.length)fail('guest deleted owner queue item');
const still=required(await call(rows('room_music_queue','select=id&room_id=eq.'+room),{
 jwt:owner.jwt
}),'queue intact after guest DELETE');
if(!still.some(x=>x.id===queue[0].id))fail('guest was able to delete owner queue');
required(await call(rows('room_music_queue','id=eq.'+queue[0].id),{
 jwt:owner.jwt,method:'DELETE'
}),'owner removes queued music');
const after=required(await call(rows('room_music_queue','select=id&room_id=eq.'+room),{
 jwt:owner.jwt
}),'queue empty after owner remove');
if(after.length)fail('queue removal not persisted');
required(await call(rows('user_music_bookmarks','id=eq.'+bookmark.id),{
 jwt:owner.jwt,method:'DELETE'
}),'owner removes favorite');
const noFavorites=required(await call(rows('user_music_bookmarks','select=id'),{
 jwt:owner.jwt
}),'favorites empty');
if(noFavorites.length)fail('bookmark deletion did not persist');
console.log('PASS T23: three REAL ephemeral GoTrue users, saved music persists over fetch; IDOR uploads blocked; only owner adds/removes room queue; joined member reads; outsider denied; queue and bookmark removals persisted; NO audio streamed, NO production connectivity.');
