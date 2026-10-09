/* TotiChat: royalty-wide visual completion. No API or backend mutations. */
(function(){
'use strict';
const $=(sel,root=document)=>root.querySelector(sel);
const $$=(sel,root=document)=>Array.from(root.querySelectorAll(sel));
const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const img=key=>'<img src="'+A+assets[key]+'" alt="" loading="lazy">';
const pureNote='<p class="rf-local-note">✦ هذه واجهة تجريبية؛ البيانات والتفاعلات محلية ولا تُرسل إلى الخادم.</p>';
const previousMore=vMore;
let currentMusic=[],currentTrack=-1,playing=false,player=null,openedMusicDB=null;
function decoratedHero(name,caption,icon='👑',key='room5'){
return '<div class="rf-hero"><div class="rf-hero-art">'+img(key)+'</div><div class="rf-hero-copy"><span>'+icon+'</span><h2>'+name+'</h2><p>'+caption+'</p></div></div>';
}
function tileGrid(items){
return '<div class="rf-tile-grid">'+items.map(x=>'<button class="rf-tile" data-a="go" data-v="'+x[2]+'"><span class="rf-tile-icon">'+x[0]+'</span><b>'+x[1]+'</b><small>استكشف ❮</small></button>').join('')+'</div>';
}
const premiumModules={
missionsPreview:{
 title:'مركز المهام',icon:'🎯',caption:'أنجز المهام وحقق إنجازاتك',art:'hero',
 cards:[['🌟','مهام يومية','room'],['💎','مكافآت المستوى','level'],['🏆','لوحة المتصدرين','ranks'],['👥','تحديات الأصدقاء','friendsPreview']]
},
treasurePreview:{
 title:'البحث عن الكنز',icon:'🗝️',caption:'مغامرات وتحديات وكنوز في TotiChat',art:'room5',
 cards:[['🎁','الجوائز','welcomePreview'],['⚔️','التحديات','missionsPreview'],['👑','مكافآت VIP','vip'],['🪙','محفظتي','wallet']]
},
notificationsPreview:{
 title:'الإشعارات',icon:'🔔',caption:'الأصدقاء والهدايا والأحداث المهمة',art:'hero3',
 cards:[['🎁','الهدايا','giftsPreview'],['👥','الأصدقاء','friendsPreview'],['📣','الإعلانات','discoverPreview'],['👑','VIP والمستوى','vip']]
}
};
function modulePage(id){
 const m=premiumModules[id];
 return page(m.title,decoratedHero(m.title,m.caption,m.icon,m.art)+pureNote+
 '<div class="rf-section-title">✧ الأقسام والخدمات</div>'+tileGrid(m.cards)+
 '<div class="rf-promo">'+img('room1')+'<span><b>غرف TotiChat الملكية</b><small>استمتع بالتواصل والتفاعل مع الأصدقاء</small></span><button data-a="go" data-v="room">دخول ❮</button></div>');
}
function roomAdmin(){
 const ops=[['⚙️','إعدادات الغرفة','rf-room-settings'],['👑','المشرفون','rf-room-settings'],['🎤','المقاعد والمايكات','rf-room-seats'],
 ['🔒','الخصوصية','rf-room-settings'],['👥','الأعضاء','rf-room-members'],['🎵','الموسيقى','rf-room-music'],
 ['🎮','الألعاب','rf-room-games'],['🎁','الهدايا','rf-room-gifts']];
 return page('إدارة الغرفة',decoratedHero('لوحة صاحب الغرفة','تحكم بمظهر الغرفة وأعضائها ومشرفيها','♛','room1')+pureNote+
 '<div class="rf-section-title">لوحة أدوات المالك</div><div class="rf-tile-grid">'+
 ops.map(x=>'<button class="rf-tile" data-rf="'+x[2]+'"><span class="rf-tile-icon">'+x[0]+'</span><b>'+x[1]+'</b><small>فتح ›</small></button>').join('')+'</div>');
}
function gamesPage(){
 return page('مركز الألعاب',decoratedHero('Games Center','ألعب وحدك أو مع أصدقائك داخل الغرفة','🎮','room5')+pureNote+
 '<div class="rf-game-door">'+[['🎲','Ludo'],['⭕','XO'],['🎱','Billiards'],['❓','Trivia']].map(x=>'<div><strong>'+x[0]+'</strong><b>'+x[1]+'</b></div>').join('')+'</div>'+
 '<button class="rf-primary" data-rf="rf-room-games">🎮 الدخول إلى الألعاب مع بقاء الغرفة</button>');
}
function playlistHtml(){
 return '<div class="rf-music-player"><div class="rf-player-cover">'+img('room5')+'</div><small>Music · TotiChat Room</small>'+
 '<h3 id="rf-track-title">'+(currentTrack>=0?escape(currentMusic[currentTrack].name):'اختر أغنية من القائمة')+'</h3>'+
 '<div class="rf-player-controls"><button data-rf="music-prev">⏮</button><button data-rf="music-toggle">'+(playing?'⏸':'▶')+'</button><button data-rf="music-next">⏭</button></div></div>'+
 '<div class="rf-section-title">قائمة التشغيل المحفوظة <small>'+currentMusic.length+' أغنية</small></div>'+
 '<div class="rf-playlist">'+(currentMusic.length?currentMusic.map((track,i)=>
 '<div class="rf-track '+(currentTrack===i?'rf-current':'')+'">'+
 '<button data-rf="music-select" data-track="'+i+'"><span>♫</span><b>'+escape(track.name)+'</b><small>'+(currentTrack===i&&playing?'يعمل الآن':'اختيار')+'</small></button>'+
 '<button aria-label="إزالة الأغنية" data-rf="music-delete" data-track="'+i+'">✕</button></div>').join(''):'<div class="rf-empty">🎵<p>القائمة فارغة. أضف ملفاتك الصوتية لحفظها محلياً.</p></div>')+'</div>';
}
function musicPage(){
 return page('موسيقى الغرفة',decoratedHero('Royal Music','الموسيقى والأغاني المختارة للغرفة','♫','room2')+pureNote+
 '<div class="rf-music-uploader"><label class="rf-primary" for="rf-music-file">＋ إضافة أغنية من الهاتف</label><input type="file" id="rf-music-file" accept="audio/*" multiple hidden>'+
 '<p>الأغاني تُخزن على هذا الجهاز فقط. تشغيل الصوت للجميع يحتاج ربطاً مستقبلياً.</p></div>'+
 '<div id="rf-music-content">'+playlistHtml()+'</div>');
}
vMore=function(id){
 if(id==='musicPreview')return musicPage();
 if(id==='roomAdminPreview')return roomAdmin();
 if(id==='gamesPreview')return gamesPage();
 if(premiumModules[id])return modulePage(id);
 return previousMore(id);
};
function openMusicDb(){
 if(openedMusicDB)return openedMusicDB;
 openedMusicDB=new Promise((resolve,reject)=>{
  if(!('indexedDB' in window)){reject(new Error('IndexedDB unavailable'));return;}
  const request=indexedDB.open('TotiChatRoyalPlaylist',1);
  request.onupgradeneeded=()=>{if(!request.result.objectStoreNames.contains('tracks'))request.result.createObjectStore('tracks',{keyPath:'id',autoIncrement:true});};
  request.onsuccess=()=>resolve(request.result);
  request.onerror=()=>reject(request.error);
 });
 return openedMusicDB;
}
async function songs(){
 try{
 const db=await openMusicDb();
 const tx=db.transaction('tracks','readonly');
 const req=tx.objectStore('tracks').getAll();
 const list=await new Promise((resolve,reject)=>{req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);});
 currentMusic=list.sort((a,b)=>a.id-b.id);
 refreshMusic();
 }catch(e){console.warn('Local audio preview storage:',e);}
}
function refreshMusic(){
 if(screen!=='musicPreview')return;
 const area=$('#rf-music-content');if(area)area.innerHTML=playlistHtml();
}
async function addSongs(files){
 try{
 const db=await openMusicDb();
 let added=0;
 for(const file of files){
  if(!file.type.startsWith('audio/'))continue;
  if(file.size>15*1024*1024){showToast('الحد الأقصى للملف 15 ميغابايت');continue;}
  const tx=db.transaction('tracks','readwrite');
  const item={name:file.name.replace(/\.[^.]+$/,''),file:file,createdAt:Date.now()};
  await new Promise((resolve,reject)=>{const req=tx.objectStore('tracks').add(item);req.onsuccess=resolve;req.onerror=()=>reject(req.error);});
  added++;
 }
 await songs();
 showToast(added?'انحفظت '+added+' أغنية على هذا الجهاز':'لم تُضف ملفات مدعومة');
 }catch(e){showToast('تعذر حفظ الأغاني؛ تأكد من توفر مساحة بالجهاز');}
}
function stopMusic(){
 if(player){player.pause();if(player.src?.startsWith('blob:'))URL.revokeObjectURL(player.src);player.src='';}
 playing=false;
}
async function selectSong(index){
 if(!currentMusic[index])return;
 stopMusic();currentTrack=index;
 const file=currentMusic[index].file;
 if(!file){showToast('ملف الأغنية غير متاح');refreshMusic();return;}
 player=new Audio(URL.createObjectURL(file));
 player.volume=.65;
 player.onended=()=>{playing=false;refreshMusic();};
 player.onerror=()=>{playing=false;showToast('تعذر تشغيل هذا الملف');refreshMusic();};
 try{await player.play();playing=true;}catch(e){showToast('اضغط تشغيل للسماح بتشغيل الصوت');}
 refreshMusic();
}
async function deleteSong(index){
 const track=currentMusic[index];if(!track)return;
 try{
 const db=await openMusicDb();const tx=db.transaction('tracks','readwrite');
 await new Promise((resolve,reject)=>{let req=tx.objectStore('tracks').delete(track.id);req.onsuccess=resolve;req.onerror=()=>reject(req.error);});
 if(currentTrack===index){stopMusic();currentTrack=-1;}else if(currentTrack>index)currentTrack--;
 await songs();showToast('انحذفت الأغنية من القائمة المحلية');
 }catch(e){showToast('تعذرت إزالة الأغنية');}
}
function decorateRoom(){
 const room=$('.roomview.room-v2');
 if(!room||room.dataset.rfDone==='yes')return;
 room.dataset.rfDone='yes';
 const top=$('.roomtop',room);
 const owner=document.createElement('span');
 owner.className='rf-room-owner';owner.textContent='♛ Owner';
 top?.appendChild(owner);
 const events=$('.roomevents',room);
 if(events)events.insertAdjacentHTML('beforeend','<span class="rf-room-live">● LIVE</span>');
 const ticker=$('.ticker-rail',room);
 if(ticker)ticker.insertAdjacentHTML('afterend',
 '<div class="rf-room-royal-ribbon" aria-label="هوية الغرفة الملكية"><span>✧</span><div><b>هنا يجتمع الصوت الجميل</b><small>✦ TotiChat Royal Voice ✦</small></div><span>♛</span></div>');
 const bottom=$('.roomBottom',room);
 if(bottom)bottom.setAttribute('aria-label','أدوات الغرفة: الدردشة، الهدايا، الرسائل، الألعاب والمزيد');
}
const priorRender=render;
render=function(){
 priorRender();
 const host=$('#app');
 if(!host)return;
 host.classList.add('rf-app');
 host.dataset.route=screen;
 host.classList.toggle('rf-room',screen==='room');
 host.classList.toggle('rf-royal-home',screen==='home'&&homeTab==='حفلة');
 if(screen==='room')decorateRoom();
 if(screen==='musicPreview')refreshMusic();
};
function action(e){
 const button=e.target.closest('[data-rf]');if(!button)return;
 e.preventDefault();e.stopImmediatePropagation();
 const a=button.dataset.rf,idx=Number(button.dataset.track);
 if(a==='rf-room-settings'){
  go('room');sheet('roomExitMenu');showToast('افتح إعدادات الغرفة من قائمة المالك');
 }else if(a==='rf-room-games'){go('room');const b=$('[data-a="sheet"][data-v="games"]');if(b)b.click();}
 else if(a==='rf-room-music')go('musicPreview');
 else if(a==='rf-room-members'){go('room');sheet('roomInfo');}
 else if(a==='rf-room-seats'){go('room');showToast('اضغط على أحد المقاعد لعرض خياراته');}
 else if(a==='rf-room-gifts'){go('room');sheet('gift');}
 else if(a==='music-select')selectSong(idx);
 else if(a==='music-delete')deleteSong(idx);
 else if(a==='music-prev'||a==='music-next'){
  if(!currentMusic.length)return;
  const i=(currentTrack+(a==='music-next'?1:-1)+currentMusic.length)%currentMusic.length;
  selectSong(i);
 }else if(a==='music-toggle'){
  if(currentTrack<0){selectSong(0);return;}
  if(!player){selectSong(currentTrack);return;}
  if(playing){player.pause();playing=false;refreshMusic();}
  else player.play().then(()=>{playing=true;refreshMusic()}).catch(()=>showToast('تعذر بدء تشغيل المقطع'));
 }
}
document.addEventListener('click',action,true);
document.addEventListener('change',e=>{if(e.target.id==='rf-music-file')addSongs([...e.target.files])});
songs();
render();
})();