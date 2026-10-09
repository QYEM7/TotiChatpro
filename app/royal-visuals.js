/* TotiChat Royal reference UI: approved 4-screen frontend-only enhancement. */
(function(){
'use strict';
const $=(s,r=document)=>r.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const imgs=key=>A+assets[key];
const roomItems=[
{name:'TotiChat Lounge',art:'room1',face:'female',count:'1.2K',desc:'هنا يجتمع الصوت الجميل ✨',tags:['موسيقى','دردشة'],type:'popular'},
{name:"Khaled’s Room",art:'male',face:'male',count:'986',desc:'أجواء طرب لا تنتهي',tags:['طرب','دردشة'],type:'music'},
{name:'Sara Live',art:'female',face:'female',count:'742',desc:'كل ليلة حكاية جديدة 💜',tags:['دردشة','غناء'],type:'friends'},
{name:'Omar Vibes',art:'prince',face:'prince',count:'620',desc:'موسيقى و أصدقاء',tags:['موسيقى','VIP'],type:'music'},
{name:'Naya World',art:'syrian',face:'syrian',count:'514',desc:'طاقة إيجابية دائماً 💖',tags:['دردشة','تعارف'],type:'friends'},
{name:'Ziad Room',art:'room3',face:'male',count:'438',desc:'أصوات من القلب ✨',tags:['موسيقى','دردشة'],type:'popular'}
];
function roomCard(r,i){
 return '<button class="royal-room-tile" data-a="go" data-v="room" data-royal-category="'+r.type+'" aria-label="ادخل '+esc(r.name)+'">'+
 '<img class="royal-tile-photo" src="'+esc(imgs(r.art))+'" alt="">'+
 '<span class="royal-tile-top"><b>● مباشر</b><small>♟ '+esc(r.count)+'</small></span>'+
 '<span class="royal-tile-detail"><strong>👑 '+esc(r.name)+'</strong><span>'+esc(r.desc)+'</span><span class="royal-tags">'+r.tags.map(x=>'<i>♡ '+esc(x)+'</i>').join('')+'</span></span></button>';
}
function royalHome(){
 const cat=[['🔥','الأكثر رواجاً','popular'],['👑','غرف VIP','vip'],['💗','تعارف','friends'],['♫','موسيقى','music'],['🎮','ألعاب','games'],['🌐','دولي','world'],['▦','جميع الفئات','all']];
 const near=[['room4','312'],['room3','288'],['room5','265'],['room2','198']];
 return '<div class="royal-home" dir="rtl"><div class="royal-home-haze"></div>'+
 '<header class="royal-topbar"><div class="royal-brand">👑 <strong>TotiChat</strong></div>'+
 '<div class="royal-top-actions"><button data-a="go" data-v="vip" aria-label="VIP" class="royal-vip-chip">👑 VIP</button><button data-royal="search" aria-label="بحث">⌕</button><button data-royal="friends" aria-label="الأصدقاء">♟</button><button data-royal="notify" aria-label="الإشعارات">♧<i></i></button></div></header>'+
 '<main class="royal-home-main">'+
 '<button class="royal-hero" data-royal="hero" aria-label="تفاصيل الغرفة المميزة"><img src="'+esc(imgs('room5'))+'" alt="ليلة ساحرة في TotiChat">'+
 '<span class="royal-hero-shine"></span><span class="royal-hero-text"><b>هنا يجتمع<br>الصوت الجميل</b><small>⋆ كوّن صداقات حول العالم ⋆</small></span>'+
 '<span class="royal-hero-pips"><i></i><i></i><i></i><i></i></span></button>'+
 '<nav class="royal-category-row" aria-label="تصنيفات TotiChat">'+cat.map(x=>'<button data-royal="category" data-cat="'+x[2]+'" class="royal-cat"><span class="royal-cat-icon">'+x[0]+'</span><small>'+x[1]+'</small></button>').join('')+'</nav>'+
 '<button class="royal-vip-promo" data-a="go" data-v="vip"><span class="royal-vip-emblem">👑<b>VIP</b></span><span class="royal-vip-promo-copy"><b>أصبح عضو VIP</b><small>مزايا حصرية وتجربة أكثر تميزاً</small></span><span class="royal-gold-cta">اكتشف الآن ❮</span></button>'+
 '<div class="royal-section-label"><h2>🔥 الغرف المميزة</h2><button data-royal="view-all">عرض الكل ❮</button></div>'+
 '<div class="royal-room-gallery">'+roomItems.map(roomCard).join('')+'</div>'+
 '<div class="royal-section-label"><h2>👑 غرف قريبة منك</h2><button data-royal="view-all">عرض الكل ❮</button></div>'+
 '<div class="royal-near">'+near.map(x=>'<button data-a="go" data-v="room" class="royal-near-tile"><img src="'+esc(imgs(x[0]))+'" alt=""><span>🟢 '+x[1]+'</span></button>').join('')+'</div>'+
 '<div class="royal-official"><p>📣 الإعلانات الرسمية</p>'+window.TotiBannerData.renderBanner()+'</div>'+
 '</main>'+
 (minimizedRoom?'<button class="mini-room-pill tc-mini-room royal-mini-room" data-a="restoreRoom" aria-label="العودة إلى الغرفة المصغرة">🎙️ الغرفة المصغرة</button>':'')+
 '<nav class="royal-nav"><button data-a="go" data-v="home" class="selected"><span>⌂</span><small>الرئيسية</small></button>'+
 '<button data-a="go" data-v="discoverPreview"><span>◎</span><small>اكتشف</small></button>'+
 '<button class="royal-create" data-royal="create-room" aria-label="إنشاء غرفة"><span>＋</span><small>إنشاء غرفة</small></button>'+
 '<button data-a="go" data-v="messages"><span>☏</span><small>الرسائل</small></button>'+
 '<button data-a="go" data-v="me"><span>♙</span><small>حسابي</small></button></nav></div>';
}
function decorate(){
 const overlay=$('#overlay');
 const f=$('.tc-feature',overlay);
 if(!f||f.dataset.royalEnhanced==='yes')return;
 f.dataset.royalEnhanced='yes';
 const h=f.querySelector('.tc-feature-head h2')?.textContent||'';
 const mode=h.includes('مشاركة')?'share':h.includes('إعدادات')?'settings':h.includes('ألعاب')?'games':null;
 if(!mode)return;
 f.classList.add('royal-feature','royal-feature-'+mode);
 overlay.classList.add('royal-mode-'+mode);
 const title=f.querySelector('.tc-feature-head');
 if(title){
 const english={share:'Share Room',settings:'Room Settings',games:'Games Center'}[mode];
 const lead={share:'دع أصدقاءك للانضمام إلى الغرفة',settings:'Manage and customize your room',games:'Play, Connect, Have More Fun Together'}[mode];
 title.insertAdjacentHTML('afterend','<div class="royal-feature-title"><span class="royal-feature-emblem">'+({share:'➤',settings:'♛',games:'🎮'}[mode])+'</span><div><h2>'+english+'</h2><p>'+lead+'</p></div></div>');
 }
 const card=f.querySelector('.tc-room-card');
 if(card){
   card.classList.add('royal-profile-card');
   card.insertAdjacentHTML('beforeend','<span class="royal-room-status">'+(mode==='settings'?'👑 Owner':'🔴 Live Voice Room')+'</span>');
 }
 if(mode==='settings'){
   const form=f.querySelector('.tc-form');
   if(form){
     const n=$('#tc-seat-count',form);
     if(n){
       const chips='<div class="royal-seat-chips">'+[6,8,10,12,15].map(i=>'<button data-royal="seat-select" data-count="'+i+'" class="'+(Number(n.value)===i?'selected':'')+'">'+i+'</button>').join('')+'</div>';
       n.insertAdjacentHTML('afterend',chips);n.classList.add('royal-screen-reader');
     }
   }
 }
 if(mode==='share'){
   const friends=f.querySelector('.tc-subtitle');
   if(friends){friends.innerHTML='🟢 Online Friends <small>الأصدقاء المتصلون</small>';}
   const chosen=f.querySelector('.tc-sticky span');
   if(chosen)chosen.insertAdjacentHTML('beforeend',' <span class="royal-selected-faces"><img src="'+esc(imgs('female'))+'" alt=""><img src="'+esc(imgs('male'))+'" alt=""></span>');
 }
 if(mode==='games'){
   f.querySelector('.tc-room-strip')?.classList.add('royal-live-strip');
   const strip=f.querySelector('.tc-room-strip');
   if(strip)strip.insertAdjacentHTML('beforebegin','<div class="royal-games-ticker">🔥 ✨ ملكة الليل sent Royal Castle to سارة　👑 x1</div>');
 }
}
const originalRender=render;
render=function(){originalRender();if(screen==='home'&&homeTab==='حفلة'){const app=$('#app');app.innerHTML=royalHome();document.body.classList.add('royal-home-body');}else document.body.classList.remove('royal-home-body');};
const overlay=$('#overlay');
const observer=new MutationObserver(()=>decorate());
if(overlay)observer.observe(overlay,{childList:true,subtree:true});
function handle(e){
 const el=e.target.closest('[data-royal]');if(!el)return;
 e.preventDefault();e.stopImmediatePropagation();
 const a=el.dataset.royal;
 if(a==='category'){
  const cat=el.dataset.cat;
  if(cat==='games'){go('room');queueMicrotask(()=>sheet('games'));return;}
  if(cat==='vip'){go('vip');return;}
  if(cat==='world'){sheet('countries');return;}
  const tiles=document.querySelectorAll('.royal-room-tile');
  tiles.forEach(t=>t.hidden=(cat!=='all'&&cat!=='popular'&&t.dataset.royalCategory!==cat));
  document.querySelectorAll('.royal-cat').forEach(x=>x.classList.toggle('active',x===el));
  document.querySelector('.royal-section-label')?.scrollIntoView({behavior:'smooth',block:'start'});
 }else if(a==='search')sheet('search');
 else if(a==='friends')go('friendsPreview');
 else if(a==='notify')go('notificationsPreview');
 else if(a==='view-all'){document.querySelectorAll('.royal-room-tile').forEach(x=>x.hidden=false);showToast('جميع الغرف في المعاينة البصرية');}
 else if(a==='hero')go('room');
 else if(a==='create-room'){
  showSheet('<div class="royal-feature royal-create-sheet" dir="rtl"><div class="tc-feature-head"><button data-royal="close" class="tc-x">✕</button><h2>👑 إنشاء غرفة</h2></div><div class="royal-feature-title"><h2>Create Room</h2></div><label class="tc-label">اسم الغرفة<input class="tc-input" id="royal-new-room-name" value="غرفتي في TotiChat" maxlength="50"></label><p class="tc-preview-note">معاينة أمامية فقط. لا تُنشأ غرفة حقيقية.</p><button class="tc-primary" data-royal="preview-create-room">معاينة الغرفة</button></div>');
  overlay.classList.add('tc-feature-overlay','royal-mode-settings');
 }else if(a==='close'){closeSheet();overlay.classList.remove('royal-mode-settings');}
 else if(a==='preview-create-room'){closeSheet();overlay.classList.remove('royal-mode-settings');go('room');}
 else if(a==='seat-select'){
  const n=Number(el.dataset.count);const select=$('#tc-seat-count');
  if(!select)return;
  if(!Array.from(select.options).some(o=>Number(o.value)===n)){const opt=document.createElement('option');opt.value=String(n);opt.text=String(n);select.add(opt);}
  select.value=String(n);
  document.querySelectorAll('.royal-seat-chips button').forEach(x=>x.classList.toggle('selected',x===el));
  if(n<15)showToast('هذا التغيير معاينة فقط؛ المقاعد المشغولة تبقى محفوظة');
 }
}
window.addEventListener('click',handle,true);
const startUrl=new URLSearchParams(location.search);
if(startUrl.get('view')==='royal-home'){minimizedRoom=false;screen='home';}
render();
})();