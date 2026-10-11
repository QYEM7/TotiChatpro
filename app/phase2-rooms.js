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
let roomListError='';
let sequence=0,sending=false;
let realtime=null,realtimeUser='';
function session(){return auth.state();}
async function query(path,options){return auth.requestData(path,options);}
async function rpc(name,args){
  if(!/^phase2_room_(create|join|leave|take_seat|members|members_visual|send_message|invite_create|invite_join)$/.test(name))
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
  if(/invalid invite|invite expired or used/i.test(s))return 'رمز الدعوة غير صحيح، منتهي الصلاحية أو مستخدم مسبقاً';
  if(/not owner of a private room/i.test(s))return 'الدعوات متاحة لمالك الغرفة الخاصة فقط';
  return s.slice(0,160);
}
const imageServer=String(window.TOTICHAT_PUBLIC_BACKEND?.supabaseUrl||'');
function publishedImage(path,id,revision){
 if(!UUID.test(String(id))||!['cover','background'].some(kind=>path===id+'/'+kind+'.webp')||
    !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(imageServer))return '';
 return imageServer+'/storage/v1/object/public/totichat-room-images/'+path.split('/').map(encodeURIComponent).join('/')+(UUID.test(String(revision))?'?v='+encodeURIComponent(revision):'');
}
function roomImage(room,index){
 return publishedImage(room.cover_path,room.id,room.image_revision)||A+assets[['room1','room2','room3','room4'][index%4]];
}
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
          '<img class="royal-tile-photo" src="'+esc(roomImage(r,i))+'" alt="">'+
          '<span class="royal-tile-top"><b>● غرفة حقيقية</b><small>🎙️ '+(r.is_private?'خاصة':'عامة')+'</small></span>'+
          '<span class="royal-tile-detail"><strong>👑 '+esc(r.title)+'</strong><span>اضغط للدخول</span></span></button>';
      }).join('');
    }
  }
  // A failed backend request is NOT an empty directory. Keep last-known real cards.
  if(gallery&&roomListError){
    if(!rooms?.length)gallery.replaceChildren();
    gallery.insertAdjacentHTML('afterbegin',
      '<div class="tc-phase2-empty" role="alert"><b>تعذّر تحديث الغرف الحقيقية</b>'+
      '<span>'+esc(roomListError)+'</span>'+
      '<button type="button" data-phase2="retry-rooms">إعادة المحاولة</button></div>');
  }
  // A separate server-backed entry point for private rooms, which are deliberately
  // hidden from other members in the public directory by the RLS policy.
  const listing=$('.royal-home .royal-room-gallery');
  if(listing&&!$('#tc-phase2-invite-entry')){
    const container=document.createElement('div');
    container.className='tc-phase2-invite-entry';container.id='tc-phase2-invite-entry';
    const button=document.createElement('button');button.type='button';
    button.dataset.phase2='invite-enter';button.textContent='🔒 دخول غرفة خاصة برمز دعوة';
    container.appendChild(button);
    listing.insertAdjacentElement('afterend',container);
  }
  // Do not represent the old hardcoded 'nearby' people or counts as live room data.
  const near=$('.royal-home .royal-near');
  if(near){
    near.innerHTML=roomListError?'<p class="tc-phase2-near-note" role="status">تعذّر تحديث الغرف الحقيقية.</p>':
      rooms===null?'<p class="tc-phase2-near-note">جارٍ تحميل الغرف…</p>':
      rooms.length?rooms.slice(0,4).map((r,i)=>
        '<button class="royal-near-tile" data-phase2="open-room" data-room="'+esc(r.id)+'" aria-label="دخول '+esc(r.title)+'">'+
        '<img src="'+esc(roomImage(r,i))+'" alt=""><span>🎙️ حقيقي</span></button>').join(''):
      '<p class="tc-phase2-near-note">لا توجد غرف مفتوحة حالياً.</p>';
  }
}
function clearUnjoinedRoom(view){
  // The approved HTML includes sample users/gifts for visual-review mode.
  // Scrub ONLY illustrative people/data while waiting for a real room;
  // keep all 15 approved seats, their frames, ornaments and layouts.
  const name=$('.roomidentity span b',view);
  if(name)name.textContent='اختر غرفة حقيقية من الرئيسية';
  const id=$('.roomidentity span small',view);
  if(id)id.textContent='لا توجد غرفة متصلة';
  const cover=$('.roomidentity img',view);
  if(cover)cover.hidden=true;
  const activity=$('.roomevents > b',view);
  if(activity)activity.textContent='● انتظار الانضمام';
  const crowd=$('.roomevents .crowd',view);
  if(crowd)crowd.textContent='👥 0';
  const ticker=$('.giftTicker .tickerBody',view);
  if(ticker)ticker.textContent='🎁 لا توجد إعلانات هدايا مؤكدة';
  // The approved review template also ships a sample donor portrait.
  const donor=$('.giftTicker img',view);
  if(donor)donor.hidden=true;
  const count=$('.giftTicker .orb b',view);
  if(count)count.textContent='0';
  for(const [index,button] of $('.seats .seat',view).entries()){
    button.disabled=true;
    button.classList.remove('occupied','locked');
    button.setAttribute('aria-label','المقعد '+(index+1)+' — انضم لغرفة أولاً');
    const face=$('.seatface',button);
    if(face){
      const photo=$('img',face);
      if(photo)photo.style.setProperty('display','none','important');
      const badge=$('.seatbadge',face);
      if(badge)badge.style.setProperty('display','none','important');
      let glyph=$('[data-real-seat-glyph]',face);
      if(!glyph){
        glyph=document.createElement('span');
        glyph.dataset.realSeatGlyph='';
        glyph.className='tc-real-seat-glyph';
        face.appendChild(glyph);
      }
      glyph.hidden=false;glyph.textContent='＋';
    }
    const label=$('.seatname',button);
    if(label)label.textContent='مقعد '+(index+1);
    const level=$('.seatlv',button);
    if(level)level.textContent='بانتظار الغرفة';
  }
  $('.chatMsg',view).forEach(node=>node.remove());
  const area=$('.chatArea',view);
  if(area){
    const note=document.createElement('p');
    note.className='chatMsg system';
    note.textContent='💬 اختر غرفة حقيقية لمشاهدة الرسائل المحفوظة';
    area.appendChild(note);
  }
}
function roomContent(){
  if(!session().signedIn||screen!=='room')return;
  const view=$('.roomview.room-v2');
  if(!view)return;
  if(!active){
    clearUnjoinedRoom(view);
  }else{
    if(active.is_private&&active.owner_id===session().user?.id){
      const header=$('.roomtop',view);
      if(header&&!$('#tc-phase2-room-share',header)){
        const button=document.createElement('button');
        button.id='tc-phase2-room-share';button.type='button';
        button.dataset.phase2='invite-generate';button.className='tc-phase2-room-share';
        button.textContent='🔒 دعوة';
        button.setAttribute('aria-label','إنشاء رمز دعوة آمن لغرفتك الخاصة');
        header.appendChild(button);
      }
    }
    const title=$('.roomidentity span b',view);
    if(title)title.textContent=active.title;
    const wallpaper=publishedImage(active.background_path,active.id,active.image_revision);
    // The approved room art actually reads --room-art, not the rejected theme's
    // --tc-room-wallpaper variable. Preserve its original image for Reset.
    if(!view.dataset.tcDefaultRoomArt)
      view.dataset.tcDefaultRoomArt=view.style.getPropertyValue('--room-art')||'none';
    if(wallpaper){
      view.style.setProperty('--room-art','url("'+wallpaper+'")');
      view.style.setProperty('--tc-room-wallpaper','url("'+wallpaper+'")');
    }else{
      view.style.setProperty('--room-art',view.dataset.tcDefaultRoomArt);
      view.style.removeProperty('--tc-room-wallpaper');
    }
    let welcome=$('[data-live-room-welcome]',view);
    if(active.welcome_message){
      if(!welcome){
        welcome=document.createElement('aside');
        welcome.dataset.liveRoomWelcome='';welcome.className='tc-room-welcome';
        const top=$('.roomtop',view);
        if(top)top.insertAdjacentElement('afterend',welcome);else view.prepend(welcome);
      }
      welcome.textContent='💜 '+active.welcome_message;
    }else welcome?.remove();
    const cover=publishedImage(active.cover_path,active.id,active.image_revision);
    const roomAvatar=$('.roomidentity img',view);
    if(roomAvatar){
      if(cover){roomAvatar.src=cover;roomAvatar.hidden=false;}
      else{roomAvatar.hidden=true;roomAvatar.removeAttribute('src');}
    }
    const id=$('.roomidentity span small',view);
    if(id)id.textContent='Room: '+active.id.slice(0,8).toUpperCase();
    const activity=$('.roomevents > b',view);
    if(activity)activity.textContent='● غرفة حقيقية';
    const crowd=$('.roomevents .crowd',view);
    if(crowd)crowd.textContent='👥 '+members.length;
    const ticker=$('.giftTicker .tickerBody',view);
    if(ticker)ticker.textContent='🎁 لا توجد إعلانات هدايا حقيقية الآن';
    const count=$('.giftTicker .orb b',view);
    if(count)count.textContent='0';
    window.TotiGlobalGiftFeed?.decorateTicker?.(view);
    const all=$$('.seats .seat',view);
    for(const [index,button] of all.entries()){
      button.disabled=false;
      const slot=index+1;
      const p=members.find(x=>x.seat_no===slot);
      // Do not overwrite the approved VIP/decorative seat classes on every refresh.
      button.classList.toggle('occupied',!!p);
      // An empty seat is available; the old preview class suggested a false lock.
      button.classList.remove('locked');
      button.setAttribute('aria-label',p?'المقعد '+slot+': '+p.display_name:'المقعد '+slot+' متاح');
      const face=$('.seatface',button);
      if(face){
        // Preserve original seat frames, ornaments, CSS effects and children.
        // Never expose a sample person's photo or sample VIP badge in REAL mode.
        const image=$('img',face);
        let realAvatar='';
        if(p?.avatar_url&&imageServer){
          try{
            const url=new URL(p.avatar_url);
            const host=new URL(imageServer);
            if(url.origin===host.origin&&url.pathname.startsWith('/storage/v1/object/public/profile-avatars/'))
              realAvatar=url.href;
          }catch(_){}
        }
        if(image){
          if(realAvatar){
            if(image.src!==realAvatar)image.src=realAvatar;
            image.style.removeProperty('display');
          }else image.style.setProperty('display','none','important');
        }
        let glyph=$('[data-real-seat-glyph]',face);
        if(!glyph){
          glyph=document.createElement('span');
          glyph.dataset.realSeatGlyph='';
          glyph.className='tc-real-seat-glyph';
          face.appendChild(glyph);
        }
        glyph.hidden=!!realAvatar;
        glyph.textContent=p?(p.user_id===session().user?.id?'🎙️':'🎤'):'＋';
        const badge=$('.seatbadge',face);
        if(badge)badge.style.setProperty('display','none','important');
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
      const data=await query('/rest/v1/rooms?select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&order=created_at.desc&limit=40');
      if(before!==sequence)return;
      if(!Array.isArray(data))throw new Error('استجابة قائمة الغرف غير صالحة');
      rooms=data;roomListError='';
      homeContent();
    }catch(err){if(before===sequence){roomListError=failure(err);homeContent();toast('فشل تحميل الغرف: '+roomListError);}}
    finally{if(before===sequence)loadingRooms=null;}
  })();
  return loadingRooms;
}
function roomMembershipRevoked(roomId){
  // Never keep a revoked room's voice/mic alive after the backend removes us.
  if(active?.id!==roomId)return;
  sequence++;active=null;members=[];messages=[];rooms=null;
  void window.TotiRealVoice?.disconnect?.();
  if(typeof closeSheet==='function')closeSheet();
  if(screen==='room')go('home');
  toast('انتهت عضويتك بالغرفة أو أُغلقت. تم فصل الصوت');
  void listRooms();
}
async function refreshRoom(){
  if(!active||!session().signedIn||refreshing)return;
  const current=active.id,before=sequence;
  refreshing=(async()=>{
    try{
      const [roster,history,roomMeta]=await Promise.all([
        rpc('phase2_room_members_visual',{p_room_id:current}),
        query('/rest/v1/room_messages?room_id=eq.'+encodeURIComponent(current)+
          '&select=id,sender_id,body,created_at&order=created_at.desc&limit=80'),
        query('/rest/v1/rooms?id=eq.'+encodeURIComponent(current)+
          '&select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&limit=1')
      ]);
      if(before!==sequence||active?.id!==current)return;
      if(!Array.isArray(roomMeta)||!Array.isArray(roster)||!Array.isArray(history))
        throw new Error('Room snapshot malformed');
      // An empty room record or a roster excluding our authenticated account
      // means the membership/room has really been removed, not a demo logout.
      if(roomMeta.length!==1||!roster.some(m=>m.user_id===session().user?.id)){
        roomMembershipRevoked(current);return;
      }
      active=roomMeta[0];
      members=roster;
      messages=history.reverse();
      if(screen==='room')roomContent();
      // Sync client-side microphone publication after moderator changes.
      window.TotiRealVoice?.syncPermission?.();
      window.dispatchEvent(new CustomEvent('totichat-real-room-state',{detail:{roomId:current}}));
    }catch(err){
      if(before!==sequence||active?.id!==current)return;
      // The RLS-checked room_members_visual RPC explicitly rejects former
      // members. Ordinary timeouts, failed reads or 5xx errors are NOT kicks.
      const message=String(err?.message||'');
      if((err?.status===403||err?.status===401)&&/room membership required/i.test(message)){
        roomMembershipRevoked(current);return;
      }
      console.warn('TotiChat real room refresh:',failure(err));
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
      '&select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&limit=1');
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
      '&select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&limit=1');
    if(!rows?.length)throw new Error('لم نعثر على الغرفة بعد الدخول');
    active=rows[0];members=[];messages=[];
    go('room');await refreshRoom();
  }catch(err){toast(failure(err));}
  finally{entering=false;}
}
const INVITE=/^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):([0-9a-f]{48})$/i;
async function generateInvite(){
  if(!active||!active.is_private||active.owner_id!==session().user?.id)return;
  try{
    const raw=await rpc('phase2_room_invite_create',{p_room_id:active.id});
    if(!INVITE.test(String(raw)))throw new Error('لم يُنشئ الخادم رمز دعوة صالحاً');
    if(typeof showSheet==='function'){
      showSheet('<div class="tc-phase2-create tc-phase2-invite" dir="rtl">'+
        '<h3>🔒 رمز الدعوة لمرة واحدة</h3>'+
        '<p>صالح لمدة 30 دقيقة ولمستخدم واحد فقط. إنشاء رمز جديد يلغي الرمز السابق.</p>'+
        '<label>انسخ رمز الدعوة وأرسله للشخص الذي تريد دعوته.'+
        '<textarea id="tc-phase2-invite-code" rows="4" readonly dir="ltr"></textarea></label>'+
        '<button class="primary" data-phase2="invite-copy">نسخ رمز الدعوة</button>'+
        '<button class="primary" data-a="close">إغلاق</button></div>',true);
      const target=$('#tc-phase2-invite-code');if(target)target.value=raw;
    }
  }catch(err){toast(failure(err));}
}
function inviteForm(){
  if(!session().signedIn){go('loginPreview');return;}
  if(active){toast('اخرج من الغرفة الحالية قبل قبول دعوة جديدة');return;}
  if(typeof showSheet!=='function')return;
  showSheet('<div class="tc-phase2-create tc-phase2-invite" dir="rtl">'+
    '<h3>🔒 الدخول إلى غرفة خاصة</h3>'+
    '<p>استخدم الرمز الذي أرسله مالك الغرفة. الرمز يُستعمل لمرة واحدة فقط.</p>'+
    '<label>رمز الدعوة<textarea id="tc-phase2-redeem-code" rows="4" dir="ltr" maxlength="100" placeholder="RoomID:InviteCode"></textarea></label>'+
    '<button class="primary" data-phase2="invite-redeem">دخول الغرفة</button>'+
    '<button class="primary" data-a="close">إلغاء</button></div>',true);
}
async function redeemInvite(){
  if(entering||active)return;
  const raw=String($('#tc-phase2-redeem-code')?.value||'').trim().toLowerCase();
  const match=INVITE.exec(raw);
  if(!match){toast('تنسيق رمز الدعوة غير صحيح');return;}
  entering=true;
  try{
    await rpc('phase2_room_invite_join',{p_room_id:match[1],p_token:match[2]});
    const rows=await query('/rest/v1/rooms?id=eq.'+encodeURIComponent(match[1])+
      '&select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&limit=1');
    if(!rows?.length)throw new Error('الغرفة ليست متاحة');
    active=rows[0];members=[];messages=[];
    if(typeof closeSheet==='function')closeSheet();
    go('room');await refreshRoom();
  }catch(err){toast(failure(err));}
  finally{entering=false;}
}
async function copyInvite(){
  const field=$('#tc-phase2-invite-code');
  if(!field?.value)return;
  if(navigator.clipboard?.writeText){
    try{await navigator.clipboard.writeText(field.value);toast('تم نسخ رمز الدعوة');return;}catch(_){}
  }
  field.focus();field.select();
  toast('حدد رمز الدعوة وانسخه يدوياً');
}

async function imageToWebp(file){
 if(!file)return null;
 if(!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size<1||file.size>6291456)
  throw Error('اختر صورة JPG أو PNG أو WebP بحجم لا يتجاوز 6 ميغابايت');
 const image=await createImageBitmap(file);
 try{
  const side=Math.min(image.width,image.height);
  if(side<1||image.width>8192||image.height>8192)throw Error('أبعاد الصورة غير مدعومة');
  const canvas=document.createElement('canvas');canvas.width=720;canvas.height=720;
  const ctx=canvas.getContext('2d');
  if(!ctx)throw Error('تعذّرت معالجة الصورة');
  ctx.drawImage(image,(image.width-side)/2,(image.height-side)/2,side,side,0,0,720,720);
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',0.82));
  if(!blob||blob.size<1||blob.size>2097152)throw Error('الصورة المعالجة تجاوزت 2 ميغابايت');
  return blob;
 }finally{image.close?.();}
}
async function customizeRoom(id,welcome,cover,background,clearBackground=false){
 const body={p_room_id:id,p_welcome_message:welcome};
 if(cover)body.p_cover_path=await auth.uploadRoomImage(id,'cover',await imageToWebp(cover));
 if(background)body.p_background_path=await auth.uploadRoomImage(id,'background',await imageToWebp(background));
 else if(clearBackground)body.p_background_path='';
 const confirmed=await query('/rest/v1/rpc/phase2_room_customize',{method:'POST',body});
 if(confirmed!==true)throw Error('الخادم لم يؤكد حفظ بيانات الغرفة');
 if(active?.id===id){
  active={...active,welcome_message:welcome,
   cover_path:body.p_cover_path===undefined?active.cover_path:body.p_cover_path,
   background_path:body.p_background_path===undefined?active.background_path:body.p_background_path};
  // Fetch the server-generated image revision so all devices invalidate cached art.
  const rows=await query('/rest/v1/rooms?id=eq.'+encodeURIComponent(id)+
    '&select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&limit=1');
  if(Array.isArray(rows)&&rows.length===1&&active?.id===id)active=rows[0];
  roomContent();
 }
 rooms=null;void listRooms();
}
async function createRoom(){
 if(entering)return;
 const title=String($('#tc-phase2-room-title')?.value||'').trim();
 const priv=!!$('#tc-phase2-room-private')?.checked;
 const welcome=String($('#tc-phase2-room-welcome')?.value||'').trim();
 const cover=$('#tc-phase2-room-cover')?.files?.[0]||null;
 const background=$('#tc-phase2-room-background')?.files?.[0]||null;
 if(title.length<2||title.length>60){toast('اسم الغرفة يجب أن يكون من حرفين إلى 60');return;}
 if(welcome.length>500){toast('الترحيب يجب ألا يتجاوز 500 حرف');return;}
 entering=true;
 try{
  const roomId=await rpc('phase2_room_create',{p_title:title,p_is_private:priv});
  if(!UUID.test(String(roomId)))throw new Error('لم يؤكد الخادم إنشاء الغرفة');
  if(typeof closeSheet==='function')closeSheet();
  try{await customizeRoom(roomId,welcome,cover,background);}
  catch(err){toast('أُنشئت الغرفة لكن تعذّر حفظ الترحيب أو الصورة: '+failure(err));}
  rooms=null;await listRooms();
  entering=false;await enterRoom(roomId);
 }catch(err){toast(failure(err));}
 finally{entering=false;}
}
function showCreate(){
 if(!session().signedIn){go('loginPreview');return;}
 if(active){toast('اخرج من الغرفة الحالية قبل إنشاء غرفة جديدة');return;}
 if(typeof showSheet!=='function')return;
 showSheet('<div class="tc-phase2-create tc-room-editor" dir="rtl"><h3>🎙️ إنشاء غرفة TotiChat</h3>'+
  '<label>اسم الغرفة *<input id="tc-phase2-room-title" maxlength="60" required placeholder="اسم غرفتك"></label>'+
  '<label>صورة الغرفة<input id="tc-phase2-room-cover" type="file" accept="image/png,image/jpeg,image/webp"></label>'+
  '<label>رسالة ترحيبية للأعضاء<textarea id="tc-phase2-room-welcome" rows="3" maxlength="500" placeholder="أهلاً بيكم بغرفتنا 💜"></textarea></label>'+
  '<label>خلفية الغرفة (اختيارية)<input id="tc-phase2-room-background" type="file" accept="image/png,image/jpeg,image/webp"></label>'+
  '<label class="tc-phase2-private"><input type="checkbox" id="tc-phase2-room-private"> غرفة خاصة بالدعوات</label>'+
  '<p>الاسم والترحيب والصور تُحفظ على خادم Staging الحقيقي.</p>'+
  '<button class="primary" data-phase2="create-room-submit">إنشاء الغرفة</button>'+
  '<button class="primary" data-a="close">إلغاء</button></div>',true);
}
function openSettings(){
 if(!active||active.owner_id!==session().user?.id){toast('الإعدادات لصاحب الغرفة فقط');return;}
 showSheet('<div class="tc-phase2-create tc-room-editor" dir="rtl"><h3>🎨 إعدادات الغرفة</h3>'+
  '<p>الغرفة: '+esc(active.title)+'</p>'+
  '<label>الرسالة الترحيبية<textarea id="tc-phase2-room-welcome-edit" rows="3" maxlength="500">'+esc(active.welcome_message||'')+'</textarea></label>'+
  '<label>صورة جديدة<input id="tc-phase2-room-cover-edit" type="file" accept="image/png,image/jpeg,image/webp"></label>'+
  '<label>خلفية جديدة<input id="tc-phase2-room-background-edit" type="file" accept="image/png,image/jpeg,image/webp"></label>'+
  '<label class="tc-phase2-private"><input type="checkbox" id="tc-phase2-room-clear-background"> استعادة الخلفية الافتراضية</label>'+
  '<button class="primary" data-phase2="room-settings-save">حفظ التغييرات</button>'+
  '<button class="primary" data-a="close">إغلاق</button></div>',true);
}
let roomSettingsSaving=false;
async function saveRoomSettings(){
 if(roomSettingsSaving||!active||active.owner_id!==session().user?.id)return;
 const id=active.id,welcome=String($('#tc-phase2-room-welcome-edit')?.value||'').trim();
 const cover=$('#tc-phase2-room-cover-edit')?.files?.[0]||null;
 const background=$('#tc-phase2-room-background-edit')?.files?.[0]||null;
 const clear=!!$('#tc-phase2-room-clear-background')?.checked;
 if(welcome.length>500){toast('الرسالة الترحيبية طويلة');return;}
 roomSettingsSaving=true;
 try{await customizeRoom(id,welcome,cover,background,clear);closeSheet();toast('تم حفظ إعدادات الغرفة على الخادم');}
 catch(err){toast('تعذّر حفظ الغرفة: '+failure(err));}
 finally{roomSettingsSaving=false;}
}
async function leaveRoom(){
  if(!active)return;
  const room=active;
  if(room.owner_id===session().user?.id&&
      !window.confirm('مغادرة غرفتك ستغلقها وتحذف محادثتها الحالية. هل تريد المتابعة؟'))return;
  try{
    await window.TotiRealVoice?.disconnect?.();
    await rpc('phase2_room_leave',{p_room_id:room.id});
    active=null;members=[];messages=[];sequence++;loadingRooms=null;roomListError='';
    if(typeof closeSheet==='function')closeSheet();
    minimizedRoom=false;rooms=null;
    go('home');void listRooms();
  }catch(err){toast(failure(err));}
}
async function setSeat(number){
  if(!active)return;
  try{
    // Releasing or switching a seat must close the existing media publication.
    await window.TotiRealVoice?.disconnect?.();
    const current=members.find(x=>x.user_id===session().user?.id)?.seat_no;
    await rpc('phase2_room_take_seat',{
      p_room_id:active.id,p_seat:current===number?null:number
    });
    await refreshRoom();
    toast('تم تحديث مقعد المايك الحقيقي. لتشغيل الصوت اضغط تفعيل الصوت.');
  }catch(err){toast(failure(err));}
}
async function sendMessage(){
  if(sending)return;
  const input=$('#composerInput');
  const body=String(input?.value||'').trim();
  if(!active||!body)return;
  sending=true;
  try{
    await rpc('phase2_room_send_message',{p_room_id:active.id,p_body:body});
    input.value='';
    if(typeof closeComposer==='function')closeComposer();
    chatTab='الكل';await refreshRoom();render();
    const area=$('.chatArea');if(area)area.scrollTop=area.scrollHeight;
  }catch(err){toast(failure(err));}
  finally{sending=false;}
}
// The approved guest composer sends demo messages on Enter. For signed-in
// room members, intercept Enter before that legacy handler and use the
// authenticated RPC instead; never display an unsent local fake message.
document.addEventListener('keydown',event=>{
  if(!session().signedIn||!active||event.key!=='Enter'||event.shiftKey||event.target?.id!=='composerInput')return;
  event.preventDefault();event.stopImmediatePropagation();
  void sendMessage();
},true);
document.addEventListener('click',event=>{
  if(!session().signedIn)return;
  const b=event.target.closest('[data-phase2],[data-royal="create-room"],[data-royal="hero"],[data-a="leaveRoom"],[data-a="seat"],[data-a="sendPreview"]');
  if(!b)return;
  const kind=b.dataset.phase2||b.dataset.royal||b.dataset.a;
  if(!['create-room','hero','create-room-submit','open-room','seat-action','seat','leaveRoom','sendPreview','invite-enter','invite-redeem','invite-generate','invite-copy','retry-rooms','room-settings-save'].includes(kind))return;
  if((kind==='seat'||kind==='seat-action'||kind==='leaveRoom'||kind==='sendPreview')&&!active)return;
  event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
  if(kind==='retry-rooms')void listRooms();
  else if(kind==='create-room')showCreate();
  else if(kind==='hero')toast('اختر غرفة حقيقية من قائمة الغرف');
  else if(kind==='create-room-submit'){void createRoom();}
  else if(kind==='room-settings-save'){void saveRoomSettings();}
  else if(kind==='open-room')void enterRoom(b.dataset.room||'');
  else if(kind==='seat'||kind==='seat-action')void setSeat(Number(b.dataset.seat||Number(b.dataset.v)+1));
  else if(kind==='leaveRoom')void leaveRoom();
  else if(kind==='sendPreview')void sendMessage();
  else if(kind==='invite-enter')inviteForm();
  else if(kind==='invite-redeem')void redeemInvite();
  else if(kind==='invite-generate')void generateInvite();
  else if(kind==='invite-copy')void copyInvite();
},true);
function resumeRealRoomReads(){
  if(!session().signedIn||document.hidden)return;
  if(screen==='room'&&active)void refreshRoom();
  if(screen==='home')void listRooms();
}
window.addEventListener('online',resumeRealRoomReads);
window.addEventListener('focus',resumeRealRoomReads);
document.addEventListener('visibilitychange',resumeRealRoomReads);
window.addEventListener('totichat-phase2-auth',()=>{
  const id=session().user?.id||'';
  if(id!==currentUser){
    currentUser=id;sequence++;rooms=null;roomListError='';loadingRooms=null;active=null;members=[];messages=[];
    if(id){void listRooms();void resume();}
  }
  // User switches/revocations dispose the old socket, so no stale events
  // cross account boundaries. Disconnected sockets fall back to 7.5s polling.
  if(realtimeUser!==id){
    realtime?.close();realtime=null;realtimeUser=id;
    if(id)realtime=auth.watchRoomUpdates(table=>{
      if(!session().signedIn)return;
      if(table==='rooms'||table==='room_members')void listRooms();
      if(active&&screen==='room')void refreshRoom();
    });
  }
  apply();
});
// Reconcile server state quickly after Android switches apps or regains signal.
 // Keep the existing low-frequency RLS-authorized polling as a fallback;
 // do not claim that the room service is socket-based Realtime yet.
let lastForegroundSync=0;
function syncVisibleRoom(){
  if(!session().signedIn||document.hidden||Date.now()-lastForegroundSync<2500)return;
  lastForegroundSync=Date.now();
  if(screen==='room'&&active)void refreshRoom();
  else if(screen==='home'&&!loadingRooms)void listRooms();
}
document.addEventListener('visibilitychange',()=>{if(!document.hidden)syncVisibleRoom();});
window.addEventListener('online',syncVisibleRoom);
window.addEventListener('focus',syncVisibleRoom);
setInterval(()=>{
  if(!session().signedIn||document.hidden)return;
  if(screen==='room'&&active)void refreshRoom();
  if(screen==='home'&&!loadingRooms)void listRooms();
},7500);
window.TotiPhase2Rooms=Object.freeze({
  // Deliberately do not expose raw tokens, owner-level mutations or balance writes.
  getStatus:()=>({signedIn:session().signedIn,activeRoomId:active?.id||null,roomCount:rooms?.length??null}),
  getRoomSummary:()=>active?Object.freeze({id:active.id,title:active.title,isPrivate:active.is_private,memberCount:members.length,isOwner:active.owner_id===session().user?.id,welcomeMessage:active.welcome_message||''}):null,
  getMyMicState:()=>{const m=members.find(x=>x.user_id===session().user?.id);return Object.freeze({seatNo:m?.seat_no??null,isMuted:m?.is_muted??true});},
  getMembers:()=>members.map(m=>Object.freeze({user_id:m.user_id,display_name:m.display_name})),
  refreshRoom,openSettings
});
})();
