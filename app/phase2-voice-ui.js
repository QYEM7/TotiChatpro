/* Real voice adapter for 2+ TotiChat participants using LiveKit SFU.
 * No audio simulation. Requires LIVEKIT_* secrets configured on the NEW
 * Supabase project and real mic permission on Android. Fail closed otherwise.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
const rooms=window.TotiPhase2Rooms;
if(!window.TotiLiveMode?.enabled||!auth||!rooms)return;
let sdk=null,connecting=false,voiceRoom='',connected=false,audioError='',needsGesture=false,attempt=0,pendingRoom='',voiceOwner='';
const $=(sel,root=document)=>root.querySelector(sel);
function error(e){
 const s=String(e?.message||'تعذر الاتصال الصوتي');
 if(/LIVEKIT_NOT_CONFIGURED|503/i.test(s))
   return 'خدمة البث الصوتي لم تُفعّل بعد على الخادم. لا يمكن سماع أو إرسال صوت الآن.';
 if(/ROOM_MEMBERSHIP_REQUIRED|403/i.test(s))
   return 'ادخل الغرفة بحسابك الحقيقي أولاً.';
 if(/notallowederror|permission denied|permission/i.test(s))
   return 'يجب منح التطبيق إذن الميكروفون.';
 return s.slice(0,170);
}
function notify(text){if(typeof showToast==='function')showToast(text);}
function ownerRoom(){return rooms.getRoomSummary?.()||null;}
function ownMic(){return rooms.getMyMicState?.()||{seatNo:null,isMuted:true};}
function controls(){
 if(screen!=='room'||!auth.state().signedIn||!ownerRoom())return;
 const parent=$('.roomview.room-v2 .roomtop');
 if(!parent)return;
 let area=$('#tc-real-voice-controls',parent);
 if(!area){
  area=document.createElement('div');
  area.id='tc-real-voice-controls';area.className='tc-real-voice-controls';
  const listen=document.createElement('button');listen.type='button';listen.dataset.realVoice='connect';
  listen.setAttribute('aria-label','توصيل الصوت الحقيقي للغرفة');area.appendChild(listen);
  const mic=document.createElement('button');mic.type='button';mic.dataset.realVoice='mic';
  mic.setAttribute('aria-label','كتم أو تشغيل الميكروفون الحقيقي');area.appendChild(mic);
  parent.appendChild(area);
 }
 const listen=$('[data-real-voice="connect"]',area);
 const mic=$('[data-real-voice="mic"]',area);
 const state=ownMic();
 listen.textContent=connecting?'جارٍ الاتصال…':connected?'🔊 الصوت متصل':'🔊 تفعيل الصوت';
 listen.disabled=connecting;
 mic.hidden=!connected||state.seatNo==null;
 mic.textContent=state.isMuted?'🎤 تشغيل المايك':'🔇 كتم المايك';
 mic.disabled=connecting;
 area.title=audioError||'اتصال صوت حقيقي فقط؛ لا يوجد صوت تجريبي';
 if(audioError)area.setAttribute('aria-label',audioError);else area.removeAttribute('aria-label');
}
async function tearDown(){
 attempt++;pendingRoom='';voiceOwner='';
 const current=sdk;sdk=null;voiceRoom='';connected=false;needsGesture=false;
 if(current)await current.disconnect().catch(()=>{});
 controls();
}
async function connect(){
 if(connecting)return;
 const info=ownerRoom();
 if(!info)return notify('ادخل غرفة حقيقية أولاً.');
 if(connected&&voiceRoom===info.id){
   try{await sdk?.resumeAudio?.();}catch(_){}
   return notify('أنت متصل بالصوت الحقيقي');
 }
 const version=++attempt,user=auth.state().user?.id;pendingRoom=info.id;voiceOwner=user;
 const valid=()=>version===attempt&&auth.state().user?.id===user&&ownerRoom()?.id===info.id;
 connecting=true;audioError='';controls();
 try{
  const grant=await auth.requestVoiceToken(info.id);
  if(!valid())return;
  if(!grant?.token||grant.roomId!==info.id||!grant?.url)throw new Error('خادم الصوت لم يؤكد الاتصال');
  const module=await import('./phase2-livekit-sdk.bundle.js');
  if(!valid())return;
  sdk=module;
  await module.connect(grant.url,grant.token,state=>{
    if(!valid())return;
    if(state.connected!==undefined)connected=state.connected;
    if(state.needsAudioGesture)needsGesture=true;
    if(!state.connecting)controls();
  });
  if(!valid()){await module.disconnect();return;}
  voiceRoom=info.id;connected=true;
  const mic=ownMic();
  if(grant.canPublish&&mic.seatNo!=null&&!mic.isMuted)await module.microphone(true);
  notify('تم الاتصال بالصوت الحقيقي للغرفة');
 }catch(e){
  if(valid()){audioError=error(e);await tearDown();notify(audioError);}
 }finally{connecting=false;pendingRoom='';controls();}
}
async function muteToggle(){
 if(connecting||!connected)return;
 const info=ownerRoom(),mic=ownMic();
 if(!info||!mic||mic.seatNo==null){
   notify('لازم تحجز مقعد مايك حقيقي أولاً');return;
 }
 const user=auth.state().user?.id,version=attempt;
 const valid=()=>version===attempt&&auth.state().user?.id===user&&ownerRoom()?.id===info.id;
 connecting=true;pendingRoom=info.id;controls();
 const updated=!mic.isMuted;
 try{
  await auth.requestData('/rest/v1/rpc/phase2_room_set_muted',{
   method:'POST',body:{p_room_id:info.id,p_muted:updated}
  });
  if(!valid())return;
  await rooms.refreshRoom();
  if(!valid())return;
  // Grants are server-authored. Reconnect with a new JWT after any mic change.
  const grant=await auth.requestVoiceToken(info.id);
  if(!valid())return;
  if(!grant?.token||grant.roomId!==info.id)throw new Error('تعذر تحديث صلاحيات الصوت');
  const client=sdk||await import('./phase2-livekit-sdk.bundle.js');
  if(!valid())return;
  sdk=client;
  await client.connect(grant.url,grant.token,state=>{
    if(!valid())return;
    if(state.connected!==undefined)connected=state.connected;
    controls();
  });
  if(!valid()){await client.disconnect();return;}
  connected=true;voiceRoom=info.id;
  if(!updated&&grant.canPublish){
    await client.microphone(true);
    notify('الميكروفون الحقيقي شغال');
  }else{notify('تم كتم الميكروفون الحقيقي');}
 }catch(e){
  audioError=error(e);
  if(!valid())return;
  if(!updated){
    // If enabling audio fails, revoke publishing at the database immediately.
    try{await auth.requestData('/rest/v1/rpc/phase2_room_set_muted',{
      method:'POST',body:{p_room_id:info.id,p_muted:true}
    });}catch(_){}
    await rooms.refreshRoom().catch(()=>{});
  }
  notify(audioError);
 }finally{connecting=false;pendingRoom='';controls();}
}
const before=render;
render=function(){const result=before.apply(this,arguments);controls();return result;};
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-real-voice]');
 if(!b)return;
 event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
 if(b.dataset.realVoice==='connect')void connect();
 else if(b.dataset.realVoice==='mic')void muteToggle();
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 if(!auth.state().signedIn||(voiceOwner&&auth.state().user?.id!==voiceOwner))void tearDown();
});
window.addEventListener('totichat-real-room-state',()=>{if((voiceRoom||pendingRoom)&&ownerRoom()?.id!==(voiceRoom||pendingRoom))void tearDown();controls();});
setInterval(()=>{
 if(voiceRoom&&ownerRoom()?.id!==voiceRoom)void tearDown();
 else if(screen==='room')controls();
},2500);
window.TotiRealVoice=Object.freeze({
 status:()=>({connected,connecting,roomId:voiceRoom||null,error:audioError||null}),
 disconnect:tearDown
});
})();
