/* Private room recordings. No synthetic audio or public storage URLs. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth,rooms=window.TotiPhase2Rooms;if(!auth||!rooms||!window.TotiLiveMode?.enabled)return;
let version=0,listVersion=0,sheetOwner=null,sheetRoom=null,stream=null,recorder=null,recordTimer=null,draft=null,busy=false,recordStarting=false,sheetObserver=null;
const urls=new Set(),audios=new Set(),state=()=>({user:auth.state().user?.id,room:rooms.getRoomSummary?.()?.id});
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/phase4_'+name,{method:'POST',body});
const status=x=>{const n=document.querySelector('[data-voice-message-status]');if(n)n.textContent=x;};
function controls(){const n=document.querySelector('[data-voice-message-draft]');if(!n)return;for(const a of n.querySelectorAll("audio")){a.pause();audios.delete(a);}n.replaceChildren();const b=document.querySelector('[data-voice-message-action="record"]');if(b)b.textContent=recorder?.state==='recording'?'إيقاف التسجيل':'تسجيل رسالة صوتية';
 if(!draft)return;const p=document.createElement('p');p.textContent='مدة التسجيل '+Math.ceil(draft.duration/1000)+' ثانية · '+Math.ceil(draft.blob.size/1024)+' كيلوبايت';
 const audio=document.createElement('audio');audio.controls=true;audio.src=draft.url;audios.add(audio);n.append(p,audio);
 for(const [action,label] of [['send','إرسال التسجيل'],['discard','إلغاء التسجيل']]){const b=document.createElement('button');b.type='button';b.className='primary';b.dataset.voiceMessageAction=action;b.textContent=label;n.appendChild(b);}}
function stopTracks(){clearTimeout(recordTimer);stream?.getTracks().forEach(t=>t.stop());stream=null;}
function releaseDraft(){if(draft){URL.revokeObjectURL(draft.url);urls.delete(draft.url);}draft=null;controls();}
function cleanup(){sheetObserver?.disconnect();sheetObserver=null;version++;listVersion++;busy=false;if(recorder?.state==='recording')recorder.stop();recorder=null;recordStarting=false;stopTracks();for(const audio of audios)audio.pause();audios.clear();for(const url of urls)URL.revokeObjectURL(url);urls.clear();draft=null;document.querySelector('[data-voice-message-sheet]')?.remove();sheetOwner=null;sheetRoom=null;}
async function list(){const id=++listVersion,context=state();status('جارٍ تحميل الرسائل الصوتية…');try{const rows=await rpc('voice_messages',{p_room_id:sheetRoom});if(id!==listVersion||context.user!==state().user||context.room!==state().room)return;
 const n=document.querySelector('[data-voice-message-list]');if(!n)return;n.replaceChildren();
 for(const row of rows){const article=document.createElement('article'),p=document.createElement('p');p.textContent=row.display_name+' · '+Math.ceil(row.duration_ms/1000)+' ثانية · '+row.created_at;article.appendChild(p);
 const play=document.createElement('button');play.className='primary';play.type='button';play.dataset.voiceMessageAction='listen';play.textContent='استماع';play.dataset.path=row.object_path;article.appendChild(play);
 if(row.sender_id===context.user){const del=document.createElement('button');del.className='primary';del.type='button';del.dataset.voiceMessageAction='delete';del.dataset.id=row.id;del.dataset.path=row.object_path;del.textContent='حذف';article.appendChild(del);}n.appendChild(article);
 }status(rows.length?'آخر '+rows.length+' رسالة صوتية':'لا توجد رسائل صوتية في هذه الغرفة.');
 }catch(e){if(id===listVersion&&context.user===state().user)status(e.message+'؛ اضغط تحديث لإعادة المحاولة');}}
function open(){const context=state();if(!context.user||!context.room)return;cleanup();sheetOwner=context.user;sheetRoom=context.room;
 showSheet('<section class="tc-phase2-account-sheet" dir="rtl" data-voice-message-sheet><h3>الرسائل الصوتية للغرفة</h3><button class="primary" data-voice-message-action="record">تسجيل رسالة صوتية</button><div data-voice-message-draft></div><p data-voice-message-status role="status"></p><button class="primary" data-voice-message-action="refresh">تحديث</button><div data-voice-message-list></div><button class="primary" data-a="close">إغلاق</button></section>',true);const sheet=document.querySelector('[data-voice-message-sheet]');sheetObserver=new MutationObserver(()=>{if(sheet&&!sheet.isConnected)cleanup();});sheetObserver.observe(document.body,{childList:true,subtree:true});void list();}
async function record(){
 if(recorder?.state==='recording'){recorder.stop();stopTracks();return;}if(recordStarting)return;
 if(draft){status('أرسل التسجيل الحالي أو ألغِه أولاً');return;}
 if(!navigator.mediaDevices?.getUserMedia||!window.MediaRecorder)throw Error('المتصفح لا يدعم التسجيل الصوتي');
 const mime=['audio/webm;codecs=opus','audio/mp4','audio/ogg;codecs=opus'].find(x=>MediaRecorder.isTypeSupported(x));if(!mime)throw Error('لا يتوفر تنسيق صوتي مدعوم');
 const current=version,context=state();recordStarting=true;status('اسمح باستخدام الميكروفون لبدء التسجيل');
 try{const media=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true},video:false});if(current!==version||context.user!==state().user||context.room!==state().room){media.getTracks().forEach(t=>t.stop());return;}stream=media;
 const chunks=[],start=performance.now(),r=new MediaRecorder(stream,{mimeType:mime});recorder=r;let size=0;
 r.ondataavailable=e=>{if(e.data.size){chunks.push(e.data);size+=e.data.size;if(size>10485760&&r.state==='recording')r.stop();}};
 r.onerror=()=>{media.getTracks().forEach(t=>t.stop());if(current===version){status('تعذر التسجيل؛ أعد المحاولة');stopTracks();}};
 r.onstop=()=>{media.getTracks().forEach(t=>t.stop());if(current!==version||context.user!==state().user||context.room!==state().room)return;stopTracks();recorder=null;
  const type=mime.split(';')[0],blob=new Blob(chunks,{type});if(blob.size===0||blob.size>10485760){status('التسجيل فارغ أو تجاوز الحجم المسموح');controls();return;}
  const id=crypto.randomUUID(),ext=type==='audio/mp4'?'mp4':type==='audio/ogg'?'ogg':'webm',url=URL.createObjectURL(blob);urls.add(url);draft={id,blob,url,duration:Math.max(1,Math.min(120000,Math.round(performance.now()-start))),path:context.user+'/'+context.room+'/'+id+'.'+ext,uploaded:false};controls();status('راجع التسجيل قبل إرساله');};
 r.start(1000);recordTimer=setTimeout(()=>{if(r.state==='recording')r.stop();stopTracks();},120000);controls();status('جارٍ التسجيل؛ اضغط إيقاف (الحد الأقصى دقيقتان)');
 }finally{if(current===version)recordStarting=false;}}
async function send(){
 if(!draft)return;const current=version,context=state(),recording=draft;if(!confirm('إرسال هذا التسجيل إلى أعضاء الغرفة؟'))return;
 if(!recording.uploaded){await auth.voiceStorage('upload',recording.path,recording.blob);recording.uploaded=true;}
 if(current!==version||context.user!==state().user||context.room!==state().room)return;
 const result=await rpc('voice_message',{p_action:'create',p_id:recording.id,p_room_id:context.room,p_path:recording.path,p_mime:recording.blob.type,p_size:recording.blob.size,p_duration:recording.duration});
 if(current!==version||context.user!==state().user)return;if(result?.id!==recording.id||result.deleted_at)throw Error('لم يؤكد الخادم إرسال التسجيل');releaseDraft();await list();status('تم إرسال الرسالة الصوتية');}
async function discard(){if(!draft)return;const current=version,recording=draft;if(recording.uploaded)await auth.voiceStorage('delete',recording.path);if(current!==version||draft!==recording)return;releaseDraft();status('أُلغي التسجيل');}
async function run(b,task){if(busy)return;busy=true;b.disabled=true;const current=version;try{await task();}catch(e){if(current===version)status(e.name==='NotAllowedError'?'لم يُمنح إذن الميكروفون أو التشغيل؛ عدّل إذن المتصفح وأعد المحاولة':e.message);}finally{if(current===version)busy=false;if(b.isConnected)b.disabled=false;}}
window.addEventListener('click',e=>{
 const original=e.target.closest('[data-a="sheet"][data-v="messagesRoom"]'),b=e.target.closest('[data-voice-message-action]');
 if(original&&screen==='room'&&state().room){e.preventDefault();e.stopImmediatePropagation();open();return;}if(!b)return;e.preventDefault();e.stopImmediatePropagation();
 void run(b,async()=>{switch(b.dataset.voiceMessageAction){
  case 'record':await record();break;case 'send':await send();break;case 'discard':await discard();break;case 'refresh':await list();break;
  case 'listen':{const current=version,blob=await auth.voiceStorage('read',b.dataset.path);if(current!==version||!b.isConnected)return;const url=URL.createObjectURL(blob),audio=document.createElement('audio');urls.add(url);audios.add(audio);audio.controls=true;audio.src=url;b.replaceWith(audio);try{await audio.play();}catch{status('اضغط زر تشغيل الصوت داخل المشغّل');}break;}
  case 'delete':if(!confirm('حذف الرسالة الصوتية نهائياً؟'))return;await auth.voiceStorage('delete',b.dataset.path);await rpc('voice_message',{p_action:'delete',p_id:b.dataset.id});await list();status('حُذفت الرسالة الصوتية');break;
 }});
},true);
window.addEventListener('totichat-phase2-auth',()=>{if(sheetOwner&&sheetOwner!==state().user)cleanup();});
window.addEventListener('totichat-real-room-state',()=>{if(sheetRoom&&sheetRoom!==state().room)cleanup();});
window.addEventListener('click',e=>{if(e.target.closest('[data-a="close"]')&&document.querySelector('[data-voice-message-sheet]'))cleanup();},true);
})();

/* T23 independent module: injected from the last approved script in the
 * original HTML, so original approved HTML stays byte-for-byte unchanged. */
(function(){
 const base=document.currentScript?.src;
 if(!base)return;
 const node=document.createElement('script');
 node.src=new URL('./phase5-music-ui.js?v=t23-real-music-20261010-1',base).href;
 node.onerror=()=>console.warn('T23 music module unavailable; no demo playback used');
 document.head.appendChild(node);
})();

/* T42 support is loaded after approved UI without changing the master HTML. */
(function(){
 const url=document.currentScript?.src;if(!url)return;
 const el=document.createElement('script');
 el.src=new URL('./phase5-support-ui.js?v=t42-real-support-20261010-1',url).href;
 el.onerror=()=>console.warn('T42 customer support module unavailable');
 document.head.appendChild(el);
})();
