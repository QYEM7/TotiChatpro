/* T23: real saved music references and room queue; NO unlicensed audio playback.
 * Keeps the approved room, mic seats, LiveKit session and decorations intact.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||typeof window.render!=='function')return;
const $=s=>document.querySelector(s);
const isLive=()=>!!window.TotiLiveMode?.enabled&&auth.state().signedIn;
const safeUUID=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
let saved=[],queued=[],owner='',roomId='',busy=false,loading=false,epoch=0,lastLoad=0;
const status=t=>{const p=$('[data-t23-status]');if(p){p.textContent=t;p.setAttribute('role','status');}};
const tell=(msg,bad=false)=>{status(msg);if(bad&&typeof showToast==='function')showToast(msg);};
const getRoom=()=>window.TotiPhase2Rooms?.getRoomSummary?.()||null;
const matching=()=>auth.state().user?.id===owner&&auth.state().signedIn;
const request=(table,query,options)=>auth.requestData('/rest/v1/'+table+(query?'?'+query:''),options);
function renderLines(container,items,kind){
 if(!container)return;
 container.replaceChildren();
 if(!items.length){const p=document.createElement('p');p.className='tc-phase2-live-empty';
  p.textContent=kind==='book'?'ما عندك أغاني محفوظة بعد.':'قائمة انتظار الغرفة فارغة.';
  container.appendChild(p);return;}
 const room=getRoom();
 for(const item of items){
  const row=document.createElement('div');row.className='visual-row';
  const info=document.createElement('span');info.className='visual-copy';
  const label=document.createElement('b');label.textContent=item.title||'بدون عنوان';
  const artist=document.createElement('small');artist.textContent=item.artist||'فنان غير محدد';
  info.append(label,artist);row.append(info);
  const id=item.id;
  if(kind==='book'&&room?.isOwner){
   const add=document.createElement('button');add.type='button';add.dataset.t23='queue-add';
   add.dataset.id=id;add.textContent='＋ للغرفة';row.append(add);
  }
  if(kind==='book'||room?.isOwner){
   const remove=document.createElement('button');remove.type='button';
   remove.dataset.t23=kind==='book'?'remove-book':'remove-queue';
   remove.dataset.id=id;remove.textContent='حذف';remove.setAttribute('aria-label','حذف '+label.textContent);
   row.append(remove);
  }
  container.append(row);
 }
}
function paint(){
 document.querySelectorAll('[data-t23-bookmarks]').forEach(el=>renderLines(el,saved,'book'));
 document.querySelectorAll('[data-t23-queue]').forEach(el=>renderLines(el,queued,'queue'));
 document.querySelectorAll('[data-t23-share-note]').forEach(el=>{
   const room=getRoom();
   el.textContent=room?
    ('غرفة '+room.title+' — '+(room.isOwner?'تقدر تضيف أغانيك إلى قائمة انتظار الغرفة.':'مالك الغرفة وحده يضيف المقاطع.'))+
     ' الموسيقى الصوتية المشتركة لم تُفعّل بعد.':
    'ادخل غرفة حقيقية لإدارة قائمة انتظارها. لا يتم تشغيل أي صوت من هذه الصفحة.';
 });
}
async function load(force=false){
 if(!isLive()||loading)return;
 const uid=auth.state().user?.id||'',now=Date.now();
 if(!force&&now-lastLoad<5500)return;
 const ref=getRoom(),id=ref?.id||'',current=++epoch;
 if(uid!==owner){owner=uid;saved=[];queued=[];}
 loading=true;lastLoad=now;
 try{
  const books=await request('user_music_bookmarks','select=id,title,artist&order=created_at.desc&limit=100');
  if(!Array.isArray(books))throw Error('تعذّر قراءة الأغاني المحفوظة');
  const queue=id&&safeUUID(id)?
   await request('room_music_queue','select=id,title,artist&room_id=eq.'+encodeURIComponent(id)+'&order=created_at.asc&limit=100'):[];
  if(!Array.isArray(queue))throw Error('تعذّر قراءة قائمة انتظار الغرفة');
  if(current!==epoch||!matching()||id!==(getRoom()?.id||''))return;
  saved=books;queued=queue;roomId=id;paint();status('تم تحديث القائمة من الخادم.');
 }catch(e){if(current===epoch)tell('تعذّر تحميل الموسيقى المحفوظة؛ أعد المحاولة.',true);}
 finally{loading=false}
}
function mount(){
 if(!isLive())return;
 if(screen==='room'&&getRoom()?.id){
   const toolbar=$('.roomBottom');
   if(toolbar&&!toolbar.querySelector('[data-t23="open"]')){
    const b=document.createElement('button');b.type='button';b.dataset.t23='open';
    b.textContent='🎵';b.setAttribute('aria-label','الموسيقى المحفوظة وقائمة الغرفة');
    b.title='قائمة الموسيقى';toolbar.appendChild(b);
   }
 }
 if(screen==='musicPreview'){
   const page=$('#app');
   const note=page?.querySelector('.visual-warn');
   if(note)note.textContent='هذه قائمة محفوظة بحسابك الحقيقي. لا يوجد تشغيل صوت مشترك حتى يتم ربط مصدر مرخّص.';
   const card=page?.querySelector('.cardwhite');
   if(card){
    card.replaceChildren();
    const h=document.createElement('h3');h.textContent='🎵 أغانيي المحفوظة';
    card.append(h);
    card.insertAdjacentHTML('beforeend',formHtml());
    const list=document.createElement('div');list.dataset.t23Bookmarks='';card.append(list);
    const h2=document.createElement('h3');h2.textContent='قائمة انتظار الغرفة';
    card.append(h2);
    const shared=document.createElement('p');shared.dataset.t23ShareNote='';card.append(shared);
    const q=document.createElement('div');q.dataset.t23Queue='';card.append(q);
   }
   const empty=page?.querySelector('.empty');
   if(empty)empty.textContent='قائمة الأغاني حقيقية، أما البث الصوتي المتزامن فما زال قيد الربط.';
   paint();void load(true);
 }
}
function formHtml(){
 return '<div class="t23-music-form">'+
 '<label>اسم الأغنية<input class="field" data-t23-title maxlength="100" placeholder="اكتب اسم الأغنية" autocomplete="off"></label>'+
 '<label>الفنان (اختياري)<input class="field" data-t23-artist maxlength="80" placeholder="اسم الفنان" autocomplete="off"></label>'+
 '<label>رابط مرجعي HTTPS (اختياري، ليس لتشغيل الصوت)<input class="field" data-t23-link type="url" maxlength="500" placeholder="https://..." autocomplete="off"></label>'+
 '<button class="primary" type="button" data-t23="save">＋ حفظ في حسابي</button>'+
 '<button type="button" data-t23="refresh">↻ تحديث</button>'+
 '<p data-t23-status role="status">لا يبدأ أي تشغيل صوتي من دون مصدر مرخّص.</p></div>';
}
function openSheet(){
 if(!isLive()||!getRoom()?.id){tell('ادخل غرفة حقيقية أولاً.',true);return;}
 showSheet('<div class="t23-room-sheet" dir="rtl"><h3>🎵 موسيقى الغرفة</h3>'+
 '<p>حفظ حقيقي وربط بقائمة الغرفة، وليس بثاً صوتياً بعد.</p>'+formHtml()+
 '<h3>أغانيي المحفوظة</h3><div data-t23-bookmarks></div>'+
 '<h3>قائمة انتظار الغرفة</h3><p data-t23-share-note></p><div data-t23-queue></div>'+
 '<button type="button" data-a="close">إغلاق</button></div>',true);
 paint();void load(true);
}
async function act(action,element){
 if(busy||!isLive())return;
 const uid=auth.state().user?.id;if(!safeUUID(uid))return tell('الجلسة غير صالحة',true);
 busy=true;
 try{
  if(action==='save'){
   const area=element.closest('.t23-music-form'),title=area?.querySelector('[data-t23-title]')?.value.trim()||'';
   const artist=area?.querySelector('[data-t23-artist]')?.value.trim()||'';
   const url=area?.querySelector('[data-t23-link]')?.value.trim()||'';
   if(title.length<2||title.length>100||artist.length>80||
      (url&&(!/^https:\/\/[^ ]+$/i.test(url)||url.length>500)))throw Error('اسم الأغنية أو الرابط المرجعي غير صالح');
   const data=await request('user_music_bookmarks','select=id,title,artist',{
    method:'POST',body:{owner_id:uid,title,artist,reference_url:url||null},
    prefer:'return=representation'});
   if(!Array.isArray(data)||data.length!==1)throw Error('الخادم لم يؤكد الحفظ');
   area.querySelectorAll('input').forEach(i=>i.value='');
  }else if(action==='remove-book'){
   if(!safeUUID(element.dataset.id))return;
   await request('user_music_bookmarks','id=eq.'+encodeURIComponent(element.dataset.id),{method:'DELETE'});
  }else if(action==='queue-add'){
   const room=getRoom();
   if(!room?.isOwner||!safeUUID(room.id))throw Error('إضافة أغنية للغرفة محصورة بمالكها');
   const item=saved.find(x=>x.id===element.dataset.id);if(!item)throw Error('الأغنية غير محفوظة بحسابك');
   const data=await request('room_music_queue','select=id,room_id',{
    method:'POST',body:{room_id:room.id,bookmark_id:item.id,added_by:uid,
      title:item.title,artist:item.artist},prefer:'return=representation'});
   if(!Array.isArray(data)||data.length!==1)throw Error('لم يؤكد الخادم إضافة الأغنية للغرفة');
  }else if(action==='remove-queue'){
   const room=getRoom();if(!room?.isOwner)throw Error('مالك الغرفة فقط يمكنه حذف مقطع من قائمة الانتظار');
   if(!safeUUID(element.dataset.id))return;
   await request('room_music_queue','id=eq.'+encodeURIComponent(element.dataset.id),{method:'DELETE'});
  }
  lastLoad=0;await load(true);
 }catch(e){tell(String(e.message||'فشل حفظ القائمة').slice(0,140),true);}
 finally{busy=false}
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);mount();return result;};
document.addEventListener('click',event=>{
 const el=event.target?.closest?.('[data-t23]');if(!el||!isLive())return;
 event.preventDefault();event.stopImmediatePropagation();
 if(el.dataset.t23==='open')openSheet();
 else if(el.dataset.t23==='refresh')void load(true);
 else void act(el.dataset.t23,el);
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 if(!isLive()||auth.state().user?.id!==owner){
  epoch++;owner='';roomId='';saved=[];queued=[];lastLoad=0;paint();
 }
});
setInterval(()=>{
 if(!isLive()||document.hidden)return;
 const visible=screen==='musicPreview'||!!$('#sheet .t23-room-sheet');
 if(visible&&!loading)void load(false);
},8000);
window.TotiPhase5Music=Object.freeze({isInstalled:()=>true,refresh:()=>load(true)});
})();
