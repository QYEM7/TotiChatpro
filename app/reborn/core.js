/* TotiChat REBORN — new UI controller, original secure Auth & LiveKit transports.
 * No preview fixtures, invented balances, local pseudo-transactions, or live production writes. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
const root=document.getElementById('app');
const falcon='../assets/images/toti_falcon_logo_1790422919580.jpg';
const s={screen:'login',sheet:'',loading:true,busy:false,notice:'',error:'',
  rooms:[],room:null,members:[],messages:[],banners:[],wallet:null,inbox:[],thread:[],
  profile:null,authority:null,selectedPeer:null,peerName:'',selectedSeat:null,
  gifts:[],store:[],giftCategory:'all',selectedGift:null,recipient:null,qty:1,
  tab:'all',search:'',roomFilter:'all',voice:false,mic:false,audioGesture:false,
  stage:0,seq:0,socket:null,voiceClient:null,financeBusy:false,requestKey:null,
  avatarStatus:'',adminData:null,extra:{},userId:null};
const esc=x=>String(x==null?'':x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','"':'&quot;',"'":'&#39;'}[c]));
const money=x=>Number.isSafeInteger(Number(x))?Number(x).toLocaleString('en-US'):'—';
const validId=x=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(x));
const el=q=>document.querySelector(q);
const me=()=>auth?.state()?.user?.id||'';
const live=()=>!!auth?.state()?.signedIn;
const endpoint=(path,options)=>auth.requestData('/rest/v1/'+path,options||{});
const rpc=(name,args)=>endpoint('rpc/'+name,{method:'POST',body:args||{}});
function notify(msg,bad=false){
 s.notice=String(msg||'').slice(0,240);
 s.error=bad?s.notice:'';
 const box=el('#global-notice');if(box){box.textContent=s.notice;box.className='status'+(bad?' error':'');box.hidden=!s.notice;}
}
function fail(err){notify(String(err?.message||err||'تعذر الاتصال بالخادم').slice(0,180),true);}
function icon(char){return '<span aria-hidden="true">'+char+'</span>';}
function avatar(url,cls=''){
 const safe=String(url||'');return '<span class="avatar '+cls+'">'+
 (safe.startsWith('https://')?'<img src="'+esc(safe)+'" alt="" loading="lazy" referrerpolicy="no-referrer">':'🦅')+'</span>';
}
function header(title,back=true,right=''){
 return '<header class="topbar">'+(back?'<button class="back" data-act="back" aria-label="رجوع">›</button>':'')+
 '<strong class="title">'+esc(title)+'</strong><div class="icons">'+right+'</div></header>';
}
function nav(){
 const items=[['home','⌂','الرئيسية'],['explore','◎','اكتشف'],['CREATE','+','غرفة'],['inbox','✉','الرسائل'],['me','◉','ملفي']];
 return '<nav class="nav" aria-label="التنقل الرئيسي">'+items.map(x=>
 '<button type="button" class="'+(x[0]===s.screen?'active ':'')+(x[0]==='CREATE'?'create':'')+'" data-nav="'+x[0]+'"'+
 (s.screen===x[0]?' aria-current="page"':'')+'><span class="ico">'+x[1]+'</span><span>'+x[2]+'</span></button>').join('')+'</nav>';
}
function empty(title,detail,button=''){
 return '<div class="empty"><strong>'+esc(title)+'</strong><p>'+esc(detail||'')+'</p>'+button+'</div>';
}
function roomPhoto(r){
 if(!r?.cover_path||!validId(r.id))return '';
 const raw=String(r.cover_path);if(!raw.startsWith(r.id+'/')||!/^[a-f0-9-]+\/cover\.webp$/i.test(raw))return '';
 return String(window.TOTICHAT_PUBLIC_BACKEND.supabaseUrl)+'/storage/v1/object/public/totichat-room-images/'+raw+'?v='+encodeURIComponent(String(r.image_revision||'0'));
}
function roomTiles(list){
 return '<div class="rooms">'+list.map(r=>'<button class="room-tile" data-room="'+esc(r.id)+'">'+
 '<div class="art">'+(roomPhoto(r)?'<img src="'+esc(roomPhoto(r))+'" alt="" loading="lazy">':'🎙️')+'</div>'+
 '<div class="info"><b>'+esc(r.title)+'</b><small>'+(r.is_private?'🔒 غرفة خاصة':'● غرفة عامة')+'</small></div></button>').join('')+'</div>';
}
function myProfile(){return auth?.state()?.profile||s.profile||{};}
function renderLogin(){
 return '<main class="login-layout" dir="rtl"><div class="login-art">'+
 '<img class="login-mark" src="'+falcon+'" alt="شعار صقر TotiChat"><h1>TotiChat</h1>'+
 '<p>صوتك يجمعنا، ومساحتك بين الأصدقاء.</p><p>غرف صوتية حقيقية · عالم اجتماعي جديد</p></div>'+
 '<section class="login-content"><span class="inline-badge">WELCOME TO TOTICHAT</span>'+
 '<h2>أهلاً بيك من جديد</h2><p>ادخل إلى عالم TotiChat بأمان عن طريق حساب Google.</p>'+
 '<div class="separator"></div>'+
 '<button class="google" id="google-login" data-act="google" '+(s.busy?'disabled':'')+'>'+
 '<svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.73 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.29 5.48-4.87 7.18l7.73 6C44.31 38.03 46.98 31.9 46.98 24.55z"/><path fill="#FBBC05" d="M10.53 28.59A14.4 14.4 0 0 1 9.75 24c0-1.6.27-3.14.76-4.59l-7.95-6.19A24 24 0 0 0 0 24c0 3.87.93 7.52 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.91-5.8l-7.73-6C30.03 37.62 27.3 38.5 24 38.5c-6.27 0-11.57-4.22-13.47-9.91l-7.97 6.19C6.51 42.62 14.62 48 24 48z"/></svg>'+
 '<span>'+(s.busy?'جارٍ فتح تسجيل الدخول…':'المتابعة باستخدام Google')+'</span></button>'+
 '<p id="provider-status" class="login-note">طريقة الدخول الوحيدة المفعّلة حالياً هي Google. لا نطلب كلمة مرورك.</p>'+
 (s.notice?'<p id="global-notice" class="status'+(s.error?' error':'')+'" role="status">'+esc(s.notice)+'</p>':'<p id="global-notice" hidden role="status"></p>')+
 '<p class="permission">بالمتابعة، أنت توافق على شروط الخدمة وسياسة الخصوصية. تسجيل الدخول يتم عبر Supabase Auth الحقيقي، وليس حساباً تجريبياً.</p>'+
 '</section></main>';
}
function home(){
 const name=myProfile().display_name||'مستخدم TotiChat';
 const published=s.banners.filter(x=>x.status==='published'&&/^https:\/\//.test(x.image_url||'')&&(!x.starts_at||Date.parse(x.starts_at)<=Date.now())&&(!x.ends_at||Date.parse(x.ends_at)>Date.now()));
 const show=s.rooms.filter(r=>!r.is_private);
 return '<div class="topbar"><div class="brand"><img src="'+falcon+'" alt=""><span>TotiChat<small>كل الأصوات إلها مكان</small></span></div>'+
 '<div class="icons"><button class="icon-btn" data-nav="notifications" aria-label="الإشعارات">♧</button><button class="icon-btn" data-nav="explore" aria-label="البحث">⌕</button></div></div>'+
 '<div class="hero"><img src="'+falcon+'" alt=""><div><h1>هلا '+esc(name)+' ✦</h1><p>اكتشف أصدقاء وغرف صوتية حقيقية، وخلي صوتك يوصل.</p></div></div>'+
 (published.length?'<div class="section-head"><h2>آخر الإعلانات</h2></div><div class="promo"><img src="'+esc(published[0].image_url)+'" alt=""><b>'+esc(published[0].title)+'</b></div>':'')+
 '<div class="section-head"><h2>عالمك في TotiChat</h2></div>'+
 '<div class="quick"><button data-nav="wallet"><span>◈</span>المحفظة</button><button data-nav="cp"><span>♡</span>علاقات CP</button><button data-nav="agencies"><span>♛</span>الوكالات</button></div>'+
 '<div class="section-head"><h2>الغرف العامة</h2><button data-nav="explore">عرض الكل ‹</button></div>'+
 (show.length?roomTiles(show.slice(0,14)):empty('ماكو غرف مفتوحة هسه','اصنع أول غرفة وابدأ حديثك.','<button class="primary" data-act="create">إنشاء غرفة</button>'));
}
function explore(){
 const found=s.rooms.filter(r=>!r.is_private&&String(r.title||'').toLocaleLowerCase().includes(s.search.toLocaleLowerCase()));
 return header('اكتشف الغرف',false,'<button class="icon-btn" data-act="refresh">↻</button>')+
 '<div class="hero"><img src="'+falcon+'" alt=""><div><h1>اكتشف مجتمعك</h1><p>كل الغرف هنا من الخادم الحقيقي.</p></div></div>'+
 '<div style="margin:15px 0"><input class="field" data-input="search" placeholder="ابحث عن غرفة باسمها…" aria-label="ابحث عن غرفة" value="'+esc(s.search)+'"></div>'+
 '<div class="section-head"><h2>الغرف المتاحة</h2><button class="secondary" data-act="inviteJoin">🔒 رمز دعوة</button><span class="inline-badge">'+found.length+' غرفة</span></div>'+
 (found.length?roomTiles(found):empty('ماكو نتائج','جرّب بحثاً مختلفاً أو أنشئ غرفة جديدة.'));
}
function profile(){
 const p=myProfile();return header('ملفي',false,'<button class="icon-btn" data-nav="notifications">♧</button>')+
 '<div class="me-hero"><div class="row">'+avatar(p.avatar_url,'xl')+'<div class="grow"><h2 style="margin:0">'+esc(p.display_name||'مستخدم جديد')+'</h2>'+
 '<small>ID الخاص: '+esc(s.extra.publicId?.assigned?s.extra.publicId.publicId:'بانتظار منح ID من الإدارة')+'</small><br><span class="vip">TotiChat Member</span></div>'+
 '<button class="icon-btn" data-nav="editProfile">✎</button></div></div>'+
 '<div class="section-head"><h2>حسابك</h2></div><div class="quick">'+
 '<button data-nav="wallet"><span>🪙</span>الرصيد</button><button data-nav="store"><span>◇</span>المتجر</button><button data-nav="vip"><span>♛</span>VIP</button></div>'+
 '<div class="section-head"><h2>الاختصارات</h2></div>'+
 menuRow('☏','الرسائل الخاصة','inbox')+menuRow('♡','علاقاتي CP','cp')+menuRow('♧','الوكالات','agencies')+
 menuRow('◈','مركز الهدايا','giftHistory')+menuRow('♧','الإشعارات','notifications')+
 menuRow('♕','الأصدقاء والمتابعة','social')+menuRow('✎','الدعم والبلاغات','support')+
 (s.authority&&(s.authority.isOwner||s.authority.isMainPartner||s.authority.canManageCatalogs||s.authority.canReadReports||s.authority.role==='db')?
 menuRow('⚙','مركز الإدارة','admin'):'')+
 menuRow('⚙','إعدادات الحساب','settings');
}
function menuRow(symbol,title,route){return '<button class="list-item" data-nav="'+route+'"><span style="font-size:23px;width:31px;text-align:center;color:#73549a">'+symbol+'</span><b>'+title+'</b><span class="end">‹</span></button>';}
function wallet(){
 const w=s.wallet;
 return header('المحفظة')+'<div class="hero"><div><h1>محفظتك الحقيقية</h1><p>كل عملية تُدار من الخادم ويتم تدقيق الرصيد.</p></div></div>'+
 '<div class="section-head"><h2>الأرصدة</h2><button data-act="refresh">تحديث</button></div>'+
 (w?'<div class="balances"><div class="balance"><small>🪙 كوينز</small><b>'+money(w.coins)+'</b></div>'+
 '<div class="balance"><small>💎 ماس</small><b>'+money(w.diamonds)+'</b></div>'+
 '<div class="balance"><small>◈ فضة</small><b>'+money(w.silver)+'</b></div></div>':
 empty('الرصيد غير متوفر','أعد المحاولة إذا لم يتم تحميله من الخادم.'))+
 '<div class="card" style="margin-top:15px"><b>شحن العملات</b><p class="hint">الشحن يتم عبر وكلاء الشحن المعتمدين. لا توجد مشتريات مباشرة داخل هذا التطبيق.</p><button class="secondary" data-nav="agencies">الوكالات</button></div>';
}
function room(){
 const r=s.room;if(!r)return home();
 const mine=s.members.find(m=>m.user_id===me())||{};
 const roster=Array.from({length:15},(_,i)=>{
  const member=s.members.find(m=>Number(m.seat_no)===i+1);
  return '<button type="button" class="seat '+(member?.user_id===me()?'mine':'')+'" data-seat="'+(i+1)+'" aria-label="المقعد '+(i+1)+'">'+
  '<span class="face">'+(member?.avatar_url?'<img src="'+esc(member.avatar_url)+'" alt="">':member?'♛':'🎙')+'</span>'+
  '<span>'+(member?esc(member.display_name||'عضو'): 'المقعد '+(i+1))+'</span>'+
  '<small>'+(!member?'فارغ':member.is_muted?'مكتوم':'متحدث')+'</small></button>';
 }).join('');
 const avatarImg=roomPhoto(r);
 return '<section class="room-page"><div class="room-backdrop"></div>'+
 '<header class="topbar"><button class="back" data-act="roomMenu">‹</button><strong>TotiChat • الغرفة الصوتية</strong><button class="icon-btn" data-act="roomInfo">ⓘ</button></header>'+
 '<div class="room-head">'+(avatarImg?'<div class="avatar lg"><img src="'+esc(avatarImg)+'" alt=""></div>':'<span class="avatar lg">🎙</span>')+
 '<div class="meta"><h2>'+esc(r.title)+'</h2><small>'+esc(r.welcome_message||'غرفة حقيقية')+' · '+s.members.length+' عضو</small></div>'+
 '<button class="icon-btn" data-act="roomMenu">⋮</button></div>'+
 '<div class="room-audio"><button data-act="voice" class="'+(s.voice?'on':'')+'">'+(s.voice?'🔊 الصوت متصل':'🔊 تفعيل الصوت')+'</button>'+
 '<button data-act="mic" '+(!s.voice||!mine.seat_no?'disabled':'')+' class="'+(!mine.is_muted?'on':'')+'">'+(mine.is_muted?'🎤 تشغيل المايك':'🔇 كتم المايك')+'</button>'+
 (s.audioGesture?'<button data-act="resumeAudio">▶ تشغيل السماعة</button>':'')+
 '<button data-act="gifts">🎁 الهدايا</button></div>'+
 '<div class="seats" aria-label="15 مقعد صوتي">'+roster+'</div>'+
 '<div class="row between" style="margin:0 0 9px"><b>دردشة الغرفة</b><button class="secondary" data-act="roomMembers">الأعضاء</button></div>'+
 '<div class="room-chat" id="room-messages" aria-live="polite">'+(s.messages.length?s.messages.map(m=>{
 const user=s.members.find(x=>x.user_id===m.sender_id);
 return '<div class="msg '+(m.sender_id===me()?'mine':'')+'"><b>'+esc(user?.display_name||'عضو')+': </b>'+esc(m.body)+'</div>';
 }).join(''):'<div class="status">لا توجد رسائل في الغرفة بعد.</div>')+'</div>'+
 '<form id="chat-form" class="room-compose"><input name="body" required maxlength="500" class="field" placeholder="اكتب رسالة للغرفة…"><button class="primary" type="submit">إرسال</button></form>'+
 '</section>';
}
function roomInfo(){
 const r=s.room;return '<h2>'+esc(r?.title||'الغرفة')+'</h2>'+
 '<p class="hint">معرف الغرفة: '+esc(r?.id||'')+'</p><p class="hint">'+esc(r?.welcome_message||'')+'</p>'+
 (r?.owner_id===me()?'<button class="secondary full" data-act="roomInvite">إنشاء دعوة للغرفة الخاصة</button>':'');
}
function roomMenu(){return '<h2>خيارات الغرفة</h2><div class="stack"><button class="secondary full" data-act="minimize">تصغير الغرفة</button><button class="danger full" data-act="leave">مغادرة الغرفة</button></div>';}
function loading(){return '<div class="loading-cover"><div><img src="'+falcon+'" alt="TotiChat"><div>جاري تجهيز حسابك الحقيقي…</div></div></div>';}
function render(){
 if(!root)return;
 if(s.loading){root.innerHTML=loading();return;}
 const isAuth=!live();
 s.screen=isAuth?'login':s.screen==='login'?'home':s.screen;
 let page='';
 if(isAuth)page=renderLogin();
 else if(s.screen==='home')page=home();
 else if(s.screen==='explore')page=explore();
 else if(s.screen==='room')page=room();
 else if(s.screen==='me')page=profile();
 else if(s.screen==='wallet')page=wallet();
 else page=window.TotiRebornFeatures?.view?.(s.screen)||header(s.screen)+empty('قيد التحميل','');
 root.className='shell'+(isAuth?' auth-root':'');
 root.innerHTML=(isAuth?page:'<main class="content">'+page+
 '<p id="global-notice" class="status'+(s.error?' error':'')+'" role="status" '+(!s.notice?'hidden':'')+'>'+esc(s.notice)+'</p></main>'+
 (s.screen==='room'?'':nav())+(s.room&&s.screen!=='room'&&!isAuth?'<button class="mini-room" data-nav="room">🎙️ '+esc(s.room.title)+' <span>العودة للغرفة ‹</span></button>':''))+
 (s.sheet?'<div class="sheet-wrap" id="sheet-wrap"><div class="sheet" role="dialog" aria-modal="true" aria-label="خيارات"><div class="row between"><span></span><button class="x" data-act="closeSheet" aria-label="إغلاق">×</button></div>'+
 (s.sheet==='roomMenu'?roomMenu():s.sheet==='roomInfo'?roomInfo():window.TotiRebornFeatures?.sheet?.(s.sheet)||'')+'</div></div>':'');
}
const views=['home','explore','me','wallet','room','inbox','store','cp','agencies','admin','notifications','editProfile','vip','giftHistory','social','support','settings','thread'];
function open(route){
 if(route==='CREATE'){showCreate();return}
 if(!views.includes(route))return;
 if(!live())return;
 if(route==='room'&&!s.room)return;
 s.screen=route;s.notice='';s.error='';s.search=route==='explore'?s.search:'';
 render();void loadRoute(route);
}
function sheet(name){s.sheet=name;render();}
function closeSheet(){s.sheet='';render();}
async function readRooms(){
 const owner=me();if(!owner)return;
 const rows=await endpoint('rooms?select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&order=created_at.desc&limit=100');
 if(owner!==me())return;
 if(!Array.isArray(rows))throw Error('Invalid room directory response');
 s.rooms=rows.filter(r=>validId(r.id));if(s.screen==='home'||s.screen==='explore')render();
}
async function readBanners(){
 const rows=await endpoint('home_banners?select=id,title,image_url,status,starts_at,ends_at,sort_order&status=eq.published&order=sort_order.asc&limit=20');
 if(!Array.isArray(rows))throw Error('Invalid banner response');
 s.banners=rows;if(s.screen==='home')render();
}
async function readWallet(){
 const id=me();if(!id)return;
 const rows=await endpoint('wallets?select=user_id,coins,diamonds,silver&user_id=eq.'+encodeURIComponent(id)+'&limit=1');
 if(id!==me())return;
 s.wallet=Array.isArray(rows)&&rows[0]?.user_id===id?rows[0]:null;if(s.screen==='wallet')render();
}
async function readPublicId(){
 const uid=me();if(!uid)return;
 try{const result=await rpc('phase5_special_id_status',{p_target:uid});
  if(uid!==me())return;
  if(result?.userId===uid&&typeof result.assigned==='boolean'){
   s.extra.publicId=result;if(s.screen==='me')render();
  }
 }catch(_){s.extra.publicId=null;}
}
async function readAuthority(){
 try{const role=await rpc('phase3_admin_session',{});
  if(!live())return;s.authority=role;if(s.screen==='me')render();
 }catch(_){s.authority=null;}
}
let polling=null;
async function enterRoom(id){
 if(s.busy||!validId(id))return;
 if(s.room&&s.room.id!==id){notify('غادر الغرفة الحالية أولاً حتى لا ينقطع الصوت بشكل غير متوقع',true);return;}
 const found=s.rooms.find(r=>r.id===id);
 s.busy=true;
 try{
  await rpc('phase2_room_join',{p_room_id:id});
  const rows=await endpoint('rooms?select=id,title,owner_id,is_private,created_at,cover_path,background_path,welcome_message,image_revision&id=eq.'+id+'&limit=1');
  const r=Array.isArray(rows)&&rows[0]||found;
  if(!r)throw Error('تعذر العثور على الغرفة');
  s.room=r;s.screen='room';s.sheet='';s.voice=false;s.mic=false;
  await refreshRoom();render();
  if(polling)clearInterval(polling);
  polling=setInterval(()=>{if(s.room&&!document.hidden)void refreshRoom().catch(()=>{});},7500);
 }catch(e){fail(e);}finally{s.busy=false;}
}
async function refreshRoom(){
 const r=s.room;if(!r||!live())return;
 const [members,messages]=await Promise.all([
  rpc('phase2_room_members_visual',{p_room_id:r.id}),
  endpoint('room_messages?room_id=eq.'+r.id+'&select=id,sender_id,body,created_at&order=created_at.desc&limit=80')
 ]);
 if(!s.room||s.room.id!==r.id)return;
 if(!Array.isArray(members)||!Array.isArray(messages))throw Error('Invalid room state');
 s.members=members;s.messages=messages.slice().reverse();
 if(s.screen==='room'){render();const chat=el('#room-messages');if(chat)chat.scrollTop=chat.scrollHeight;}
 if(s.voice&&!s.members.some(m=>m.user_id===me()&&m.seat_no&&!m.is_muted)){
  void s.voiceClient?.microphone(false).catch(()=>disconnectVoice());
  s.mic=false;
 }
}
async function leaveRoom(){
 if(!s.room||s.busy)return;const id=s.room.id;s.busy=true;
 try{await disconnectVoice();await rpc('phase2_room_leave',{p_room_id:id});
  if(polling)clearInterval(polling);polling=null;s.room=null;s.members=[];s.messages=[];s.sheet='';s.screen='home';
  render();await readRooms();
 }catch(e){fail(e);}finally{s.busy=false;}
}
async function selectSeat(n){
 if(!s.room||s.busy||n<1||n>15)return;
 const current=s.members.find(m=>m.user_id===me())?.seat_no||null;
 s.busy=true;
 try{
  await disconnectVoice();
  await rpc('phase2_room_take_seat',{p_room_id:s.room.id,p_seat:current===n?null:n});
  await refreshRoom();notify('تم تحديث المقعد. فعّل الصوت للتحدث.');
 }catch(e){fail(e);}finally{s.busy=false;}
}
async function disconnectVoice(){
 const module=s.voiceClient;s.voiceClient=null;s.voice=false;s.mic=false;s.audioGesture=false;
 if(module)await module.disconnect().catch(()=>{});
}
async function connectVoice(){
 if(!s.room||s.busy||s.voice)return;s.busy=true;
 try{
  const roomId=s.room.id;
  const grant=await auth.requestVoiceToken(roomId);
  if(!grant?.token||grant.roomId!==roomId||!grant.url)throw Error('تعذر الحصول على إذن الصوت الحقيقي');
  const module=await import('../phase2-livekit-sdk.bundle.js');
  if(s.room?.id!==roomId)return;
  s.voiceClient=module;
  await module.connect(grant.url,grant.token,event=>{
   if(!s.room||s.room.id!==roomId)return;
   if(event.needsAudioGesture)s.audioGesture=true;
   if(event.connected===false){s.voice=false;s.mic=false;}
   if(s.screen==='room')render();
  });
  if(s.room?.id!==roomId){await module.disconnect();return;}
  s.voice=true;notify('الصوت متصل بالخادم الحقيقي');
 }catch(e){await disconnectVoice();fail(e);}finally{s.busy=false;render();}
}
async function toggleMic(){
 if(!s.room||!s.voice||s.busy)return;
 const member=s.members.find(m=>m.user_id===me());
 if(!member?.seat_no){notify('احجز مقعد مايك أولاً',true);return;}
 const oldMuted=!!member.is_muted,requestMuted=!oldMuted;
 s.busy=true;
 try{
  if(requestMuted){
   try{await s.voiceClient.microphone(false);}catch(e){await disconnectVoice();throw Error('تم فصل الصوت لأن إيقاف المايك تعذّر');}
   s.mic=false;
  }
  await rpc('phase2_room_set_muted',{p_room_id:s.room.id,p_muted:requestMuted});
  await refreshRoom();
  const grant=await auth.requestVoiceToken(s.room.id);
  if(!grant?.token||grant.roomId!==s.room.id)throw Error('تعذر تحديث صلاحية الميكروفون');
  await s.voiceClient.connect(grant.url,grant.token,()=>{});
  if(!requestMuted){
   if(!grant.canPublish)throw Error('لا توجد صلاحية للميكروفون في هذا المقعد');
   await s.voiceClient.microphone(true);s.mic=true;
  }else s.mic=false;
  notify(requestMuted?'الميكروفون مكتوم':'الميكروفون شغال');
 }catch(e){
  if(!requestMuted){try{await s.voiceClient?.microphone(false);}catch(_){await disconnectVoice();}
   try{if(s.room)await rpc('phase2_room_set_muted',{p_room_id:s.room.id,p_muted:true});}catch(_){}}
  fail(e);
 }finally{s.busy=false;void refreshRoom().catch(()=>{});}
}
async function roomChat(form){
 if(!s.room||s.busy)return;const msg=String(new FormData(form).get('body')||'').trim();
 if(!msg||msg.length>500)return;
 s.busy=true;try{await rpc('phase2_room_send_message',{p_room_id:s.room.id,p_body:msg});
 form.reset();await refreshRoom();}catch(e){fail(e);}finally{s.busy=false;}
}
async function imageBlob(file){
 if(!(file instanceof File)||!['image/jpeg','image/png','image/webp'].includes(file.type)||!file.size||file.size>6291456)throw Error('اختر صورة JPG أو PNG أو WebP بحجم أقل من 6MB');
 const bitmap=await createImageBitmap(file),side=Math.min(bitmap.width,bitmap.height);
 if(!side||side>8192)throw Error('أبعاد الصورة غير صالحة');
 const canvas=document.createElement('canvas');canvas.width=720;canvas.height=720;
 canvas.getContext('2d').drawImage(bitmap,(bitmap.width-side)/2,(bitmap.height-side)/2,side,side,0,0,720,720);bitmap.close?.();
 const blob=await new Promise(ok=>canvas.toBlob(ok,'image/webp',0.8));
 if(!blob||blob.size>2097152)throw Error('تعذّر تجهيز الصورة');
 return blob;
}
function showCreate(){
 if(!live()){open('login');return}
 sheet('createRoom');
}
async function createRoom(form){
 if(s.busy||!live())return;
 const data=new FormData(form),title=String(data.get('title')||'').trim(),welcome=String(data.get('welcome')||'').trim();
 const cover=data.get('cover'),privateRoom=data.get('private')==='on';
 if(title.length<2||title.length>60||welcome.length<2||welcome.length>500){notify('أدخل اسم الغرفة ورسالة ترحيب صحيحة',true);return;}
 if(!(cover instanceof File)||!cover.size){notify('صورة الغرفة مطلوبة',true);return;}
 s.busy=true;let createdId=null;
 try{
  const blob=await imageBlob(cover);
  createdId=await rpc('phase2_room_create',{p_title:title,p_is_private:privateRoom});
  if(!validId(createdId))throw Error('الخادم لم يؤكد إنشاء الغرفة');
  const path=await auth.uploadRoomImage(createdId,'cover',blob);
  const saved=await rpc('phase2_room_customize',{p_room_id:createdId,p_welcome_message:welcome,p_cover_path:path,p_background_path:null});
  if(saved!==true)throw Error('تعذّر حفظ صورة الغرفة والترحيب');
  s.sheet='';await readRooms();
  notify('تم إنشاء الغرفة');s.busy=false;await enterRoom(createdId);
 }catch(e){fail(e);if(createdId)notify('تم إنشاء الغرفة لكن حفظ الصورة أو الترحيب لم يكتمل. تحقق من الغرف.',true);}
 finally{s.busy=false;}
}
function bindRealtime(){
 s.socket?.close?.();s.socket=null;
 if(!live())return;
 s.socket=auth.watchRoomUpdates(table=>{if(table==='rooms'||table==='room_members')void readRooms().catch(()=>{});
 if(s.room&&['room_members','room_messages','rooms'].includes(table))void refreshRoom().catch(()=>{});});
}
async function loadRoute(route){
 if(!live())return;
 const run=async()=>{
  if(route==='home')await Promise.allSettled([readRooms(),readBanners()]);
  else if(route==='explore')await readRooms();
  else if(route==='wallet')await readWallet();
  else if(route==='room')await refreshRoom();
  else if(route==='me')await Promise.allSettled([readAuthority(),readPublicId()]);
  else if(window.TotiRebornFeatures?.load)await window.TotiRebornFeatures.load(route);
 };
 try{await run();}catch(e){fail(e);}
}
function onAuthChange(){
 const id=me();if(id!==s.userId){
  s.userId=id;s.rooms=[];s.room=null;s.messages=[];s.wallet=null;s.authority=null;
  s.inbox=[];s.profile=null;s.sheet='';s.notice='';s.error='';s.extra={};
  if(polling)clearInterval(polling);polling=null;void disconnectVoice();bindRealtime();
 }
 if(!s.loading){s.screen=live()?(s.screen==='login'?'home':s.screen):'login';render();if(live())void loadRoute(s.screen);}
}
async function boot(){
 if(!auth){s.loading=false;notify('إعدادات تسجيل الدخول غير متاحة',true);render();return;}
 await bindNativeOAuth();
 window.addEventListener('totichat-auth-error',e=>{fail(e.detail);render();});
 try{await auth.resume();}catch(e){fail(e);}
 s.loading=false;s.userId=me();s.screen=live()?'home':'login';
 bindRealtime();render();
 if(live())void Promise.allSettled([loadRoute('home'),readAuthority(),readWallet(),readPublicId()]);
 else void checkGoogle();
}
async function checkGoogle(){
 try{const providers=await auth.providers();
  const btn=el('#google-login'),msg=el('#provider-status');
  if(!providers.google){if(btn)btn.disabled=true;if(msg)msg.textContent='تسجيل Google غير متاح حالياً من خادم المصادقة. لا يوجد دخول وهمي.';}
 }catch(e){const msg=el('#provider-status');if(msg)msg.textContent='تعذّر التحقق من خدمة Google. تأكد من الاتصال بالإنترنت.';}
}
async function bindNativeOAuth(){
 if(!(location.protocol==='https:'&&location.hostname==='localhost'))return;
 const app=window.Capacitor?.Plugins?.App;
 if(!app?.addListener)return;
 await app.addListener('appUrlOpen',async event=>{
  if(!event?.url||!event.url.startsWith('com.totichat.beta://auth/callback'))return;
  try{await auth.handleOAuthCallback(event.url);await window.Capacitor?.Plugins?.Browser?.close?.();s.sheet='';s.screen='home';render();await loadRoute('home');}
  catch(e){fail(e);render();}
 });
}
async function loginGoogle(){
 if(s.busy||!auth)return;s.busy=true;render();
 try{const p=await auth.providers();if(!p.google)throw Error('Google غير مفعّل على الخادم');
  await auth.signInWithProvider('google');
 }catch(e){s.busy=false;fail(e);render();}
}
document.addEventListener('click',event=>{
 const target=event.target?.closest?.('[data-nav],[data-act],[data-room],[data-seat]');
 if(!target)return;
 const a=target.dataset.act,nav=target.dataset.nav;
 if(nav){event.preventDefault();open(nav);return;}
 if(target.dataset.room){event.preventDefault();void enterRoom(target.dataset.room);return;}
 if(target.dataset.seat){event.preventDefault();void selectSeat(Number(target.dataset.seat));return;}
 if(!a)return;
 event.preventDefault();
 switch(a){
  case 'back':open(s.room?'room':'home');break;
  case 'google':void loginGoogle();break;
  case 'refresh':void loadRoute(s.screen);break;
  case 'create':showCreate();break;
  case 'closeSheet':closeSheet();break;
  case 'roomMenu':sheet('roomMenu');break;
  case 'roomInfo':sheet('roomInfo');break;
  case 'minimize':closeSheet();open('home');break;
  case 'leave':void leaveRoom();break;
  case 'voice':void connectVoice();break;
  case 'mic':void toggleMic();break;
  case 'resumeAudio':void s.voiceClient?.resumeAudio().then(()=>{s.audioGesture=false;render();}).catch(fail);break;
  case 'roomMembers':sheet('roomMembers');break;
  case 'roomInvite':void (async()=>{try{if(!s.room?.is_private||s.room.owner_id!==me())throw Error('الدعوات للغرفة الخاصة بصاحبها فقط');const code=await rpc('phase2_room_invite_create',{p_room_id:s.room.id});s.extra.invite=code;s.sheet='roomInvite';render();}catch(e){fail(e);}})();break;
  case 'gifts':s.sheet='gifts';render();void window.TotiRebornFeatures?.loadSheet?.('gifts');break;
  case 'inviteJoin':sheet('inviteJoin');break;
  default:if(window.TotiRebornFeatures?.action)void window.TotiRebornFeatures.action(a,target);
 }
});
document.addEventListener('submit',event=>{
 const form=event.target,kind=form.id;
 if(!kind)return;
 event.preventDefault();
 if(kind==='create-room-form')void createRoom(form);
 else if(kind==='chat-form')void roomChat(form);
 else if(window.TotiRebornFeatures?.submit)void window.TotiRebornFeatures.submit(kind,form);
});
document.addEventListener('input',event=>{
 if(event.target.matches('[data-input="search"]')){s.search=event.target.value;const p=el('.rooms');if(p){const found=s.rooms.filter(r=>!r.is_private&&String(r.title||'').toLocaleLowerCase().includes(s.search.toLocaleLowerCase()));p.outerHTML=found.length?roomTiles(found):empty('ماكو نتائج','جرّب اسم ثاني.');}}
});
window.addEventListener('totichat-phase2-auth',onAuthChange);
window.addEventListener('online',()=>{if(live())void loadRoute(s.screen);});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&live())void loadRoute(s.screen);});
window.TotiReborn={state:s,auth,render,open,sheet,closeSheet,esc,avatar,header,empty,menuRow,notify,fail,endpoint,rpc,money,validId,imageBlob,roomTiles,loadRoute,readRooms,readWallet,roomPhoto,enterRoom,refreshRoom,readAuthority,disconnectVoice,showCreate};
void boot();
})();