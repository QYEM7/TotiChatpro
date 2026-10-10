/* Real LiveKit WebRTC media adapter. Bundled locally into Android; no CDN,
 * no fake sound, no secret keys and no network side effects until connect().
 */
import {Room,RoomEvent,ConnectionState} from 'livekit-client';
let current=null;
let audio=[];
let onState=null;
let speakerVolume=1;
function signal(detail){
  if(typeof onState==='function')onState(detail);
}
function cleanAudio(){
 for(const el of audio){try{el.remove()}catch(_){}}
 audio=[];
}
export function status(){return {connected:current?.state===ConnectionState.Connected||false};}
export async function disconnect(){
 const old=current;current=null;cleanAudio();
 if(old){await old.disconnect().catch(()=>{});}
 signal({connected:false});
}
export async function connect(serverUrl,token,callback){
 if(typeof serverUrl!=='string'||!serverUrl.startsWith('wss://')||
    typeof token!=='string'||token.length<80)throw new Error('بيانات اتصال الصوت غير صالحة');
 await disconnect();onState=callback;
 const room=new Room({adaptiveStream:true,dynacast:true});
 current=room;
 room.on(RoomEvent.TrackSubscribed,(track)=>{
   if(track.kind!=='audio')return;
   const media=track.attach();
   media.setAttribute('playsinline','');
   media.autoplay=true;media.volume=speakerVolume;
   media.style.display='none';
   media.dataset.totiLiveAudio='1';
   document.body.appendChild(media);
   audio.push(media);
   const p=media.play();
   if(p&&typeof p.catch==='function')void p.catch(()=>signal({needsAudioGesture:true}));
 });
 room.on(RoomEvent.TrackUnsubscribed,track=>{
   track.detach().forEach(el=>{el.remove();audio=audio.filter(a=>a!==el)});
 });
 room.on(RoomEvent.Disconnected,()=>signal({connected:false}));
 room.on(RoomEvent.Reconnecting,()=>signal({connecting:true}));
 room.on(RoomEvent.Reconnected,()=>signal({connected:true}));
 try{
   await room.connect(serverUrl,token,{autoSubscribe:true});
   if(current!==room){await room.disconnect();return;}
   try{await room.startAudio();}catch(_){}
   signal({connected:true});
 }catch(err){await disconnect();throw err;}
}
export async function microphone(enabled){
 if(!current||current.state!==ConnectionState.Connected)
   throw new Error('اتصل بالغرفة الصوتية أولاً');
 await current.localParticipant.setMicrophoneEnabled(Boolean(enabled),{echoCancellation:true,noiseSuppression:true,autoGainControl:true});
 signal({micEnabled:Boolean(enabled)});
}

export async function resumeAudio(){
 if(!current)throw new Error("اتصل بالصوت أولاً");
 await current.startAudio();
 await Promise.all(audio.map(el=>el.play()));
}
export function setSpeakerVolume(value){
 if(typeof value!=="number"||!Number.isFinite(value)||value<0||value>1)throw new Error("مستوى الصوت غير صالح");
 speakerVolume=value;for(const el of audio)el.volume=value;
}
