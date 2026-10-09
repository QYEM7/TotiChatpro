/* TotiChat Phase 2: independent, genuinely persisted room directory,
 * exclusive server-side mic SEATS and text chat.
 * Actual audio transport, VIP, gifting and wallet are NOT wired by this file.
 * Guest pages retain the immutable approved UI preview.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||typeof render!=='function')return;
const $=(s,r=document)=>r.querySelector(s);
const $$=(s,r=document)=>[...r.querySelectorAll(s)];
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({
  '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
}[c]));
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
let currentUser='',rooms=null,active=null,members=[],messages=[],loadingRooms=null,refreshing=null,entering=false;
let sequence=0;
function session(){return auth.state();}
async function query(path,options){return auth.requestData(path,options);}
async function rpc(name,args){
  if(!/^phase2_room_(create|join|leave|take_seat|members|send_message)$/.test(name))
    throw new Error('Invalid room operation');
  return query('/rest/v1/rpc/'+name,{method:'POST',body:args});
}
function toast(text){if(typeof showToast==='function')showToast(String(text).slice(0,160));}
function failure(e){
  const s=String(e?.message||'تعذر الاتصال بالخادم');
  if(/duplicate key|room first|leave your current room/i.test(s))return 'لا يمكنك فتح غرفتين معاً؛ اخرج من الغرفة الحالية أولاً';
  if(/seat is occupied/i.test(s))return 'هذا المقعد محجوز، اختر مقعداً آخر';
  if(/room is private/i.test(s))return 'هذه الغرفة خاصة ولا تسمح بالدخول دون دعوة';
  if(/room does not exist/i.test(s))return 'الغرفة غير موجودة أو تم إغلاقها';
  if(/slow down/i.test(s))return 'انتظر ثانية قبل إرسال رسالة أخرى';
  return s.slice(0,160);
}
function roomImage(index){return A+assets[['room1','room2','room3','room4'][index%4]];}
function homeContent(){
  if(!session().signedIn||screen!=='home')return;
  const gallery=$('.royal-home .royal-room-gallery');
  if(gallery){
    if(rooms===null){
      gallery.innerHTML='<div class="tc-phase2-empty">جارٍ تحميل الغرف الحقيقية…</div>';
    }else if(!rooms.length){
      gallery.innerHTML='<div class="tc-phase2-empty"><b>🎙️ ماكو غرف مفتوحة حالياً</b><span>أنشئ أول غرفة صوتية حقيقية في TotiChat.</span><button data-phase2="create-room">＋ إنشاء غرفة</button></div>';
    }else{
      gallery.innerHTML=rooms.map((r,i)=>{
        if(!UUID.test(r.id))return '';
        return '<button class="royal-room-tile" data-phase2="open-room" data-room="'+esc(r.id)+'" aria-label="دخول '+esc(r.title)+'">'+
          '<img class="royal-tile-photo" src="'+esc(roomImage(i))+'" alt="">'+
          '<span class="royal-tile-top"><b>● غرفة حقيقية</b><small>🎙️ '+(r.is_private?'خاصة':'عامة')+'</small></span>'+
          '<span class="royal-tile-detail"><strong>👑 '+esc(r.title)+'</strong><span>اضغط للدخول</span></span></button>';
      }).join('');
    }
  }
  // Do not represent the old hardcoded 'nearby' people or counts as live room data.
  const near=$('.royal-home .royal-near');
  if(near){
    near.innerHTML=rooms===null?'<p class="tc-phase2-near-note">جارٍ تحميل الغرف…</p>':
      rooms.length?rooms.slice(0,4).map((r,i)=>
        '<button class="royal-near-tile" data-phase2="open-room" data-room="'+esc(r.id)+'" aria-label="دخول '+esc(r.title)+'">'+
        '<img src="'+esc(roomImage(i))+'" alt=""><span>🎙️ حقيقي</span></button>').join(''):
      '<p class="tc-phase2-near-note">لا توجد غرف مفتوحة حالياً.</p>';
  }
}
function roomContent(){
  if(!session().signedIn||screen!=='room')return;
  const view=$('.roomview.room-v2');
  if(!view)return;
  if(!active){
    const name=$('.roomidentity span b',view);
    if(name)name.textContent='اختر غرفة حقيقية من الرئيسية';
  }else{
    const title=$('.roomidentity span b',view);
    if(title)title.textContent=active.title;
    const id=$('.roomidentity span small',view);
    if(id)id.textContent='Room: '+active.id.slice(0,8).toUpperCase();
    const crowd=$('.roomevents .crowd',view);
    if(crowd)crowd.textContent='👥 '+members.length;
    const ticker=$('.giftTicker .tickerBody',view);
    if(ticker)ticker.textContent='✨ الهدايا الحقيقية قيد الربط';
    const count=$('.giftTicker .orb b',view);
    if(count)count.textContent='0';
    const all=$$('.seats .seat',view);
    for(const [index,button] of all.entries()){
      const slot=index+1;
      const p=members.find(x=>x.seat_no===slot);
      button.className='seat'+(p?' occupied':'');
      button.setAttribute('aria-label',p?'المقعد '+slot+': '+p.display_name:'المقعد '+slot+' متاح');
      const face=$('.seatface',button);
      if(face){
        face.replaceChildren();
        face.textContent=p?(p.user_id===session().user?.id?'🎙️':'🎤'):'＋';
        if(p?.user_id===session().user?.id){
          const badge=document.createElement('span');
          badge.className='seatbadge';badge.textContent='✦';face.appendChild(badge);
        }
      }
      const label=$('.seatname',button);if(label)label.textContent=p?.display_name||'مقعد '+slot;
      const level=$('.seatlv',button);
      if(level)level.textContent=p?(p.is_muted?'🔇 محجوز · صامت':'🎙️ محجوز'):'انضم للمايك';
      button.dataset.phase2='seat-action';
      button.dataset.seat=String(slot);
    }
    if(chatTab==='الكل'||chatTab==='دردشة'){
      const area=$('.chatArea',view);
      const actual=$$('.chatMsg',area);
      actual.forEach(x=>x.remove());
      if(!messages.length){
        area.insertAdjacentHTML('beforeend','<div class="chatMsg system">💬 لا توجد رسائل حقيقية بعد. كن أول من يكتب.</div>');
      }else{
        for(const m of messages){
          const who=members.find(x=>x.user_id===m.sender_id)?.display_name||'مستخدم';
          const div=document.createElement('div');
          div.className='chatMsg'+(m.sender_id===session().user?.id?' mine':' royal');
          const b=document.createElement('b');b.textContent=who+' · ';
          div.appendChild(b);div.appendChild(document.createTextNode(m.body));
          area.appendChild(div);
        }
      }
    }
  }
  const info=$('#composerWrap .composer-hint');
  if(info)info.textContent='رسائلك في الغرفة الحالية تُحفظ على خادم TotiChat الحقيقي';
  const badge=$('#composerWrap .composer-vip');
  if(badge)badge.textContent='🎙️';
}
function apply(){
  if(!session().signedIn)return;
  if(screen==='home')homeContent();
  if(screen==='room')roomContent();
}
const oldRender=render;
render=function(){const result=oldRender.apply(this,arguments);apply();return result;};
apply();
async function listRooms(){
  if(!session().signedIn)return;
  if(loadingRooms)return loadingRooms;
  const before=sequence;
  loadingRooms=(async()=>{
    try{
      const data=await query('/rest/v1/rooms?select=id,title,owner_id,is_private,created_at&order=created_at.desc&limit=40');
      if(before!==sequence)return;
      rooms=Array.isArray(data)?data:[];
      homeContent();
    }catch(err){if(before===sequence){rooms=[];homeContent();toast('فشل تحميل الغرف: '+failure(err));}}
    finally{loadingRooms=null;}
  })();
  return loadingRooms;
}
async function refreshRoom(){
  if(!active||!session().signedIn||refreshing)return;
  const current=active.id,before=sequence;
  refreshing=(async()=>{
    try{
      const [roster,history]=await Promise.all([
        rpc('phase2_room_members',{p_room_id:current}),
        query('/rest/v1/room_messages?room_id=eq.'+encodeURIComponent(current)+
          '&select=id,sender_id,body,created_at&order=created_at.desc&limit=80')
      ]);
      if(before!==sequence||active?.id!==current)return;
      members=Array.isArray(roster)?roster:[];
      messages=Array.isArray(history)?history.reverse():[];
      if(screen==='room')roomContent();
    }catch(err){
      if(before===sequence)console.warn('TotiChat real room refresh:',failure(err));
    }finally{refreshing=null;}
  })();
  return refreshing;
}
async function resume(){
  if(!session().signedIn)return;
  const before=sequence;
  try{
    const own=await query('/rest/v1/room_members?user_id=eq.'+encodeURIComponent(session().user.id)+'&select=room_id&limit=1');
    if(before!==sequence||!own?.[0]?.room_id)return;
    const result=await query('/rest/v1/rooms?id=eq.'+encodeURIComponent(own[0].room_id)+
      '&select=id,title,owner_id,is_private,created_at&limit=1');
    if(before!==sequence||!result?.length)return;
    active=result[0];members=[];messages=[];
    if(screen==='room')roomContent();
    await refreshRoom();
  }catch(err){console.warn('Room restore pending:',failure(err));}
}
async function enterRoom(id){
  if(entering)return;
  if(!UUID.test(id))return;
  if(active&&active.id!==id){toast('اخرج من غرفتك الحالية أولاً');return;}
  entering=true;
  try{
    await rpc('phase2_room_join',{p_room_id:id});
    const existing=rooms?.find(x=>x.id===id);
    const rows=existing?[existing]:await query('/rest/v1/rooms?id=eq.'+encodeURIComponent(id)+
      '&select=id,title,owner_id,is_private,created_at&limit=1');
    if(!rows?.length)throw new Error('لم نعثر على الغرفة بعد الدخول');
    active=rows[0];members=[];messages=[];
    go('room');await refreshRoom();
  }catch(err){toast(failure(err));}
  finally{entering=false;}
}
async function createRoom(){
  if(entering)return;
  const title=String($('#tc-phase2-room-title')?.value||'').trim();
  const priv=!!$('#tc-phase2-room-private')?.checked;
  if(title.length<2||title.length>60){toast('اسم الغرفة يجب أن يكون من حرفين إلى 60');return;}
  entering=true;
  try{
    const roomId=await rpc('phase2_room_create',{p_title:title,p_is_private:priv});
    if(!UUID.test(String(roomId)))throw new Error('لم يؤكد الخادم إنشاء الغرفة');
    if(typeof closeSheet==='function')closeSheet();
    rooms=null;await listRooms();
    await enterRoom(roomId);
  }catch(err){toast(failure(err));}
  finally{entering=false;}
}
function showCreate(){
  if(!session().signedIn){go('loginPreview');return;}
  if(active){toast('اخرج من الغرفة الحالية قبل إنشاء غرفة جديدة');return;}
  if(typeof showSheet!=='function')return;
  showSheet('<div class="tc-phase2-create" dir="rtl"><h3>🎙️ إنشاء غرفة حقيقية</h3>'+
    '<label>اسم الغرفة<input id="tc-phase2-room-title" maxlength="60" placeholder="اسم غرفتك"></label>'+
    '<label class="tc-phase2-private"><input type="checkbox" id="tc-phase2-room-private"> غرفة خاصة بالمالك (الدعوات قيد التطوير)</label>'+
    '<p>المقاعد والرسائل ستكون حقيقية. بث الصوت لم يُفعّل بعد.</p>'+
    '<button class="primary" data-phase2="create-room-submit">إنشاء الغرفة</button>'+
    '<button class="primary" data-a="close">إلغاء</button></div>',true);
}
async function leaveRoom(){
  if(!active)return;
  const room=active;
  if(room.owner_id===session().user?.id&&
      !window.confirm('مغادرة غرفتك ستغلقها وتحذف محادثتها الحالية. هل تريد المتابعة؟'))return;
  try{
    await rpc('phase2_room_leave',{p_room_id:room.id});
    active=null;members=[];messages=[];sequence++;
    if(typeof closeSheet==='function')closeSheet();
    minimizedRoom=false;rooms=null;
    go('home');void listRooms();
  }catch(err){toast(failure(err));}
}
async function setSeat(number){
  if(!active)return;
  try{
    const current=members.find(x=>x.user_id===session().user?.id)?.seat_no;
    await rpc('phase2_room_take_seat',{
      p_room_id:active.id,p_seat:current===number?null:number
    });
    await refreshRoom();
    toast('تم تحديث المقعد على الخادم. نقل الصوت ما زال قيد التطوير.');
  }catch(err){toast(failure(err));}
}
async function sendMessage(){
  const input=$('#composerInput');
  const body=String(input?.value||'').trim();
  if(!active||!body)return;
  try{
    await rpc('phase2_room_send_message',{p_room_id:active.id,p_body:body});
    input.value='';
    if(typeof closeComposer==='function')closeComposer();
    chatTab='الكل';await refreshRoom();render();
    const area=$('.chatArea');if(area)area.scrollTop=area.scrollHeight;
  }catch(err){toast(failure(err));}
}
document.addEventListener('click',event=>{
  if(!session().signedIn)return;
  const b=event.target.closest('[data-phase2],[data-royal="create-room"],[data-royal="hero"],[data-a="leaveRoom"],[data-a="seat"],[data-a="sendPreview"]');
  if(!b)return;
  const kind=b.dataset.phase2||b.dataset.royal||b.dataset.a;
  if(!['create-room','hero','create-room-submit','open-room','seat-action','seat','leaveRoom','sendPreview'].includes(kind))return;
  if((kind==='seat'||kind==='seat-action'||kind==='leaveRoom'||kind==='sendPreview')&&!active)return;
  event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
  if(kind==='create-room')showCreate();
  else if(kind==='hero')toast('اختر غرفة حقيقية من قائمة الغرف');
  else if(kind==='create-room-submit'){void createRoom();}
  else if(kind==='open-room')void enterRoom(b.dataset.room||'');
  else if(kind==='seat'||kind==='seat-action')void setSeat(Number(b.dataset.seat||Number(b.dataset.v)+1));
  else if(kind==='leaveRoom')void leaveRoom();
  else if(kind==='sendPreview')void sendMessage();
},true);
window.addEventListener('totichat-phase2-auth',()=>{
  const id=session().user?.id||'';
  if(id!==currentUser){
    currentUser=id;sequence++;rooms=null;active=null;members=[];messages=[];
    if(id){void listRooms();void resume();}
  }
  apply();
});
setInterval(()=>{
  if(!session().signedIn||document.hidden)return;
  if(screen==='room'&&active)void refreshRoom();
  if(screen==='home'&&!loadingRooms)void listRooms();
},7500);
window.TotiPhase2Rooms=Object.freeze({
  // Deliberately do not expose raw tokens, owner-level mutations or balance writes.
  getStatus:()=>({signedIn:session().signedIn,activeRoomId:active?.id||null,roomCount:rooms?.length??null})
});
})();
