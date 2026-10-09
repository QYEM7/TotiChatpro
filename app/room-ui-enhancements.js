/* TotiChat room UI completion: frontend-only preview; no API/database calls. */
(function(){
'use strict';
const q=(s,root=document)=>root.querySelector(s);
const overlay=q('#overlay');
const params=new URLSearchParams(location.search);
const ownerPreview=params.get('owner')!=='0';
const savedKey='totichat.room-ui-preview.v1';
const defaults={name:'ليالي TotiChat',note:'أهلاً بكم في غرفتنا الصوتية',seats:15,photo:'',moderators:[0,1,2]};
let settings={...defaults};
try{const raw=JSON.parse(localStorage.getItem(savedKey)||'null');if(raw&&typeof raw==='object')settings={...defaults,...raw};}catch(_){}
let photoDraft='',selected=new Set(),friendSearch='',gameTab='solo',gameView='library';
let xo=[],turn='X',gameOver=false,score=0,questionIndex=0;
const questions=[
 {q:'ما هو الكوكب الأقرب للشمس؟',a:['الأرض','عطارد','المشتري'],correct:1},
 {q:'كم عدد أضلاع المثلث؟',a:['3','4','5'],correct:0},
 {q:'ما هي عاصمة العراق؟',a:['البصرة','بغداد','الموصل'],correct:1},
 {q:'كم عدد أيام الأسبوع؟',a:['5','7','9'],correct:1}
];
const E=s=>String(s==null?'':s).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[ch]));
const roomPhoto=()=>settings.photo||A+assets.room1;
const personPhoto=i=>A+assets[(people[i]||people[0])[1]];
const notice='<div class="tc-preview-note">معاينة واجهات فقط — لا دعوات حقيقية أو تغييرات على الخادم أو المحفظة.</div>';
function closeFeature(){overlay.classList.remove('tc-feature-overlay');closeSheet();}
function openFeature(title,body){
 showSheet('<div class="tc-feature" dir="rtl"><div class="tc-feature-head"><button class="tc-x" data-tc="close" aria-label="إغلاق">✕</button><h2>'+title+'</h2><span class="tc-crest">✦ TotiChat</span></div>'+body+'</div>');
 overlay.classList.add('tc-feature-overlay');
}
function roomCard(){
 return '<div class="tc-room-card"><img src="'+E(roomPhoto())+'" alt="صورة الغرفة"><div><b>'+E(settings.name)+'</b><small>ID: 9728390 · 🔴 غرفة نشطة</small><p>'+E(settings.note)+'</p></div></div>';
}
function friendRows(){
 let indexes=people.map((_,i)=>i).filter(i=>people[i][0].includes(friendSearch)||(''+(4456610+i)).includes(friendSearch));
 const mount=q('#tc-friend-list');if(!mount)return;
 mount.innerHTML=indexes.length?indexes.map(i=>'<button class="tc-friend'+(selected.has(i)?' selected':'')+'" data-tc="friend" data-index="'+i+'" aria-pressed="'+selected.has(i)+'"><img src="'+E(personPhoto(i))+'" alt=""><span><b>'+E(people[i][0])+' <em>'+E(people[i][2])+'</em></b><small>ID '+(4456610+i)+' · '+(i<4?'🟢 متصل':'صديق')+'</small></span><i>'+ (selected.has(i)?'✓':'○') +'</i></button>').join(''):'<div class="tc-empty">ماكو أصدقاء مطابقين للبحث.</div>';
 const count=q('#tc-share-count');if(count)count.textContent=selected.size;
 const btn=q('#tc-send-invites');if(btn)btn.disabled=!selected.size;
}
function shareRoom(){
 friendSearch='';selected.clear();
 openFeature('مشاركة الغرفة',roomCard()+notice+
 '<label class="tc-label" for="tc-friend-search">اختَر الأصدقاء اللي تريد تدعوهم</label>'+
 '<input id="tc-friend-search" class="tc-input" placeholder="ابحث بالاسم أو ID..." autocomplete="off">'+
 '<h3 class="tc-subtitle">👥 الأصدقاء والمتصلون</h3><div id="tc-friend-list" class="tc-friends"></div>'+
 '<div class="tc-sticky"><span>المحددون: <b id="tc-share-count">0</b></span><button id="tc-send-invites" data-tc="send-invites" disabled>إرسال الدعوة للأصدقاء</button></div>');
 friendRows();
}
function modRows(){
 const el=q('#tc-mod-list');if(!el)return;
 el.innerHTML=settings.moderators.map(i=>'<div class="tc-mod-row"><img src="'+E(personPhoto(i))+'" alt=""><span>'+E(people[i][0])+' <small>'+E(people[i][2])+'</small></span><button data-tc="remove-mod" data-index="'+i+'">إزالة</button></div>').join('')||'<div class="tc-empty">لا يوجد مشرفون حالياً</div>';
 const picker=q('#tc-mod-picker');if(picker)picker.innerHTML=people.map((p,i)=>settings.moderators.includes(i)?'':'<option value="'+i+'">'+E(p[0])+'</option>').join('');
}
function settingsRoom(){
 if(!ownerPreview){showToast('إعدادات الغرفة متاحة لصاحب الغرفة فقط');return;}
 photoDraft='';
 openFeature('إعدادات الغرفة · المالك',roomCard()+notice+
 '<div class="tc-form"><label>اسم الغرفة<input id="tc-name" class="tc-input" maxlength="50" value="'+E(settings.name)+'"></label>'+
 '<label>صورة الغرفة<div class="tc-photo-row"><img id="tc-photo" src="'+E(roomPhoto())+'" alt="معاينة صورة الغرفة"><span class="tc-upload">📷 تغيير الصورة<input id="tc-photo-file" type="file" accept="image/*"></span></div></label>'+
 '<label>ملاحظة / وصف الغرفة<textarea id="tc-note" class="tc-input" maxlength="200" rows="3">'+E(settings.note)+'</textarea></label>'+
 '<label>عدد المقاعد<select id="tc-seat-count" class="tc-input">'+[6,8,10,12,15,20].map(n=>'<option value="'+n+'" '+(settings.seats===n?'selected':'')+'>'+n+' مقعد</option>').join('')+'</select></label>'+
 '<div class="tc-hint">مقاعد الغرفة الحالية تبقى محفوظة في المعاينة. تطبيق تغيير العدد الفعلي على الجلسات يحتاج ربطاً لاحقاً.</div>'+
 '<label>👑 إدارة المشرفين</label><div class="tc-mod-list" id="tc-mod-list"></div>'+
 '<div class="tc-add-mod"><select id="tc-mod-picker" class="tc-input" aria-label="اختيار مشرف"></select><button data-tc="add-mod">+ إضافة مشرف</button></div>'+
 '<button class="tc-primary" data-tc="save-settings">✓ حفظ إعدادات المعاينة</button></div>');
 modRows();
}
function saveSettings(){
 const name=(q('#tc-name')?.value||'').trim(),note=(q('#tc-note')?.value||'').trim();
 const seats=Number(q('#tc-seat-count')?.value||15);
 if(name.length<2){showToast('اسم الغرفة يجب أن يحتوي على حرفين على الأقل');return;}
 if(![6,8,10,12,15,20].includes(seats)){showToast('عدد المقاعد غير صالح');return;}
 settings={...settings,name,note,seats,photo:photoDraft||settings.photo};
 try{localStorage.setItem(savedKey,JSON.stringify(settings));}catch(_){showToast('تعذّر حفظ الصورة محلياً، حاول بصورة أصغر');}
 closeFeature();
 if(screen==='room')render();
 showToast('تم حفظ إعدادات المعاينة محلياً فقط');
}
function miniView(){
 const pill=q('.mini-room-pill');
 if(!pill)return;
 if(pill.dataset.tcReady!=='yes'){
   pill.classList.add('tc-mini-room');
   pill.dataset.tcReady='yes';
   pill.setAttribute('aria-label','العودة إلى الغرفة المصغرة');
   pill.addEventListener('pointerdown',startDrag);
   pill.addEventListener('pointermove',moveDrag);
   pill.addEventListener('pointerup',endDrag);
   pill.addEventListener('pointercancel',endDrag);
 }
 const markup='<img src="'+E(roomPhoto())+'" alt=""><span><b>'+E(settings.name)+'</b><small>🔴 داخل الغرفة · اضغط للعودة</small></span><span class="tc-restore">↗</span>';
 if(pill.dataset.tcName!==settings.name||pill.dataset.tcPhoto!==roomPhoto()){pill.dataset.tcName=settings.name;pill.dataset.tcPhoto=roomPhoto();pill.innerHTML=markup;}
}
let drag=null,blockClick=false;
function startDrag(e){
 if(e.button!==0)return;
 const rect=e.currentTarget.getBoundingClientRect();
 drag={startX:e.clientX,startY:e.clientY,left:rect.left,top:rect.top,moved:false};
 if(e.currentTarget.setPointerCapture)e.currentTarget.setPointerCapture(e.pointerId);
}
function moveDrag(e){
 if(!drag)return;
 let dx=e.clientX-drag.startX,dy=e.clientY-drag.startY;
 if(Math.abs(dx)+Math.abs(dy)>7)drag.moved=true;
 if(!drag.moved)return;
 const pill=e.currentTarget,box=pill.getBoundingClientRect();
 const left=Math.max(5,Math.min(innerWidth-box.width-5,drag.left+dx));
 const top=Math.max(45,Math.min(innerHeight-box.height-10,drag.top+dy));
 pill.style.cssText+=';left:'+left+'px;top:'+top+'px;right:auto;bottom:auto';
}
function endDrag(){if(!drag)return;blockClick=drag.moved;drag=null;if(blockClick)setTimeout(()=>{blockClick=false},280);}
function applyRoom(){
 // Keep the approved guest room settings preview intact. Once a member
 // enters a REAL server-backed room, the server's title/art must win:
 // the old preview MutationObserver must not overwrite live metadata.
 const phase2Live=!!window.TotiPhase2Rooms?.getStatus?.().activeRoomId;
 if(screen==='room'&&!phase2Live){
   const title=q('.roomidentity b');if(title&&title.textContent!==settings.name)title.textContent=settings.name;
   const pic=q('.roomidentity img');if(pic&&pic.getAttribute('src')!==roomPhoto())pic.src=roomPhoto();
 }
 miniView();
}
const app=q('#app');if(app)new MutationObserver(()=>applyRoom()).observe(app,{childList:true,subtree:true});
function games(){
 gameView='library';
 renderGames();
}
function renderGames(){
 const strip='<div class="tc-room-strip"><img src="'+E(roomPhoto())+'" alt=""><span><b>'+E(settings.name)+'</b><small>🎙️ أنت مستمر داخل الغرفة</small></span></div>';
 let body=strip+notice;
 if(gameView==='library'){
 const list=gameTab==='solo'?
 [['xo','⭕','XO ضد الكمبيوتر','العب الآن'],['quiz','❓','Trivia الفردية','العب الآن'],['puzzle','🧩','Puzzle','قريباً'],['dice','🎲','Dice','قريباً'],['draw','🎨','Draw & Guess','قريباً'],['spy','🎭','Who’s the Spy','قريباً']]:
 [['ludo','🎲','Ludo','قريباً'],['xo','⭕','XO','العب الآن'],['billiards','🎱','Billiards','قريباً'],['quiz','❓','Trivia','العب الآن'],['draw','🎨','Draw & Guess','قريباً'],['spy','🎭','Who’s the Spy','قريباً']];
 body+='<div class="tc-tabs"><button data-tc="game-tab" data-mode="solo" class="'+(gameTab==='solo'?'active':'')+'">👤 ألعاب فردية</button><button data-tc="game-tab" data-mode="multi" class="'+(gameTab==='multi'?'active':'')+'">👥 ألعاب جماعية</button></div>'+
 '<div class="tc-game-grid">'+list.map(g=>'<button data-tc="'+(g[3]==='قريباً'?'game-soon':'start-game')+'" data-game="'+g[0]+'" class="tc-game-card"><span class="tc-game-icon">'+g[1]+'</span><b>'+g[2]+'</b><small>'+g[3]+'</small></button>').join('')+'</div>'+
 (gameTab==='multi'?'<div class="tc-hint">الألعاب الجماعية تعمل محلياً لشخصين على نفس الجهاز في هذه المعاينة. دعوات ومزامنة الأجهزة لاحقاً.</div>':'');
 }else if(gameView==='xo'){
 const result=gameOver?'<b>انتهت الجولة</b>':'<b>الدور: '+turn+'</b>';
 body+='<div class="tc-game-nav"><button data-tc="games-back">‹ الألعاب</button><strong>XO '+(gameTab==='solo'?'ضد الكمبيوتر':'لاعبان محلياً')+'</strong></div>'+
 '<div class="tc-xo-info">'+result+'</div><div class="tc-xo">'+xo.map((x,i)=>'<button data-tc="xo-move" data-index="'+i+'">'+(x||'　')+'</button>').join('')+'</div><button class="tc-primary" data-tc="start-game" data-game="xo">جولة جديدة</button>';
 }else{
 const item=questions[questionIndex%questions.length];
 body+='<div class="tc-game-nav"><button data-tc="games-back">‹ الألعاب</button><strong>تحدي الأسئلة</strong></div>'+
 '<p class="tc-question">السؤال '+(questionIndex+1)+' / '+questions.length+' · النقاط: '+score+'</p>'+
 '<h3 class="tc-question">'+E(item.q)+'</h3><div class="tc-answers">'+item.a.map((a,i)=>'<button data-tc="quiz-answer" data-index="'+i+'">'+E(a)+'</button>').join('')+'</div>';
 }
 openFeature('🎮 مركز ألعاب TotiChat',body);
}
function xoWinner(){
 const lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
 for(const line of lines){if(xo[line[0]]&&xo[line[0]]===xo[line[1]]&&xo[line[1]]===xo[line[2]])return xo[line[0]];}
 return xo.every(Boolean)?'draw':null;
}
function xoMove(i){
 if(gameOver||xo[i])return;
 xo[i]=turn;
 let result=xoWinner();
 if(result){gameOver=true;showToast(result==='draw'?'تعادل':('الفائز: '+result));}
 else if(gameTab==='solo'&&turn==='X'){
   const choices=[4,0,2,6,8,1,3,5,7];
   const bot=choices.find(x=>!xo[x]);
   if(bot!==undefined){xo[bot]='O';result=xoWinner();if(result){gameOver=true;showToast(result==='draw'?'تعادل':'فاز الكمبيوتر');}}
   turn='X';
 }else turn=turn==='X'?'O':'X';
 renderGames();
}
function handleTc(el,e){
 const a=el.dataset.tc; e.preventDefault();e.stopImmediatePropagation();
 if(a==='close'){closeFeature();}
 else if(a==='friend'){const i=Number(el.dataset.index);if(selected.has(i))selected.delete(i);else selected.add(i);friendRows();}
 else if(a==='send-invites'){if(selected.size){closeFeature();showToast('تمت معاينة دعوة '+selected.size+' أصدقاء، ولم تُرسل دعوة حقيقية');}}
 else if(a==='save-settings')saveSettings();
 else if(a==='remove-mod'){settings.moderators=settings.moderators.filter(i=>i!==Number(el.dataset.index));modRows();}
 else if(a==='add-mod'){const i=Number(q('#tc-mod-picker')?.value);if(Number.isInteger(i)&&i>=0&&!settings.moderators.includes(i)){settings.moderators.push(i);modRows();}}
 else if(a==='owner-open')settingsRoom();
 else if(a==='games-open')games();
 else if(a==='game-tab'){gameTab=el.dataset.mode;renderGames();}
 else if(a==='start-game'){gameView=el.dataset.game;xo=Array(9).fill('');turn='X';gameOver=false;score=0;questionIndex=0;renderGames();}
 else if(a==='games-back'){gameView='library';renderGames();}
 else if(a==='xo-move')xoMove(Number(el.dataset.index));
 else if(a==='quiz-answer'){const picked=Number(el.dataset.index);if(picked===questions[questionIndex].correct){score++;showToast('إجابة صحيحة! 🎉');}else showToast('الإجابة الصحيحة: '+questions[questionIndex].a[questions[questionIndex].correct]);questionIndex++;if(questionIndex>=questions.length){showToast('خلصت الأسئلة: '+score+' / '+questions.length);gameView='library';}renderGames();}
 else if(a==='game-soon')showToast('هذه اللعبة ضمن خطط الإضافة، وليست جاهزة للعب بعد');
}
function enhanceRoomMenu(){
 const box=q('#sheet.room-glass');if(!box)return;
 if(ownerPreview&&!q('[data-tc="owner-open"]',box)){
  const b=document.createElement('button');
  b.className='room-action';b.dataset.tc='owner-open';
  b.innerHTML='<span class="room-action-icon">⚙️</span><span class="room-action-label">إعدادات الغرفة <small>للمالك</small></span>';
  const leave=q('[data-a="leaveRoom"]',box);box.insertBefore(b,leave);
 }
 if(!q('[data-tc="games-open"]',box)){
  const b=document.createElement('button');
  b.className='room-action';b.dataset.tc='games-open';
  b.innerHTML='<span class="room-action-icon">🎮</span><span class="room-action-label">مركز الألعاب</span>';
  const leave=q('[data-a="leaveRoom"]',box);box.insertBefore(b,leave);
 }
}
document.addEventListener('click',function(e){
 const custom=e.target.closest('[data-tc]');if(custom){handleTc(custom,e);return;}
 const original=e.target.closest('[data-a]');if(!original)return;
 const a=original.dataset.a,v=original.dataset.v||'';
 if(a==='shareRoom'){
   e.preventDefault();e.stopImmediatePropagation();closeSheet();shareRoom();
 }else if(a==='sheet'&&v==='games'){
   e.preventDefault();e.stopImmediatePropagation();closeSheet();games();
 }else if(a==='sheet'&&v==='roomExitMenu'){
   queueMicrotask(enhanceRoomMenu);
 }else if(a==='minimizeRoom'){
   e.preventDefault();e.stopImmediatePropagation();
   closeSheet();minimizedRoom=true;go('home');applyRoom();
 }else if(a==='restoreRoom'){
   if(blockClick){e.preventDefault();e.stopImmediatePropagation();blockClick=false;return;}
   e.preventDefault();e.stopImmediatePropagation();minimizedRoom=false;go('room');applyRoom();
 }else if(a==='leaveRoom'){
   closeFeature();minimizedRoom=false;
 }else if(a==='close'&&overlay.classList.contains('tc-feature-overlay')){
   e.preventDefault();e.stopImmediatePropagation();closeFeature();
 }
},true);
document.addEventListener('input',e=>{
 if(e.target.id==='tc-friend-search'){friendSearch=e.target.value.trim().toLowerCase();friendRows();}
});
document.addEventListener('change',e=>{
 if(e.target.id!=='tc-photo-file')return;
 const file=e.target.files?.[0];if(!file)return;
 if(!file.type.startsWith('image/')||file.size>5*1024*1024){showToast('اختر صورة أقل من 5 ميغابايت');return;}
 const reader=new FileReader();
 reader.onload=()=>{
 const img=new Image();
 img.onload=()=>{
  const canvas=document.createElement('canvas');canvas.width=320;canvas.height=320;
  const context=canvas.getContext('2d');const crop=Math.min(img.width,img.height);
  context.drawImage(img,(img.width-crop)/2,(img.height-crop)/2,crop,crop,0,0,320,320);
  photoDraft=canvas.toDataURL('image/jpeg',0.75);
  const preview=q('#tc-photo');if(preview)preview.src=photoDraft;
 };
 img.src=String(reader.result);
 };
 reader.readAsDataURL(file);
});
overlay.addEventListener('click',e=>{if(e.target===overlay)overlay.classList.remove('tc-feature-overlay')},true);
/* Direct review links for each finished UI flow. */
const reviewView=params.get('view');
if(reviewView==='minimized'){minimizedRoom=true;go('home');}
else if(reviewView==='share')shareRoom();
else if(reviewView==='settings')settingsRoom();
else if(reviewView==='games')games();
applyRoom();
})();