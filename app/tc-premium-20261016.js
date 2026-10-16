/* TotiChat live UX pass: real discovery, accessible vector navigation and verified empty states.
 * Read-only room directory; no fake people, balance writes or microphone modifications. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!window.TotiLiveMode?.enabled||!auth||typeof window.render!=='function')return;
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const icon={home:'<path d="m3 10 9-7 9 7v10H3z"/><path d="M9 20v-7h6v7"/>',
 discoverPreview:'<circle cx="12" cy="12" r="9"/><path d="m15 9-2 5-4 1 2-5z"/>',
 messages:'<path d="M4 4h16v12H8l-4 4z"/><path d="M8 9h8M8 12h5"/>',
 CREATE:'<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>'};
const vector=k=>'<svg class="tc-vector-icon" aria-hidden="true" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'+icon[k]+'</svg>';
let rows=null,loading=false,error='',search='',account='',seq=0;
const signed=()=>!!auth.state().signedIn;
function navIcons(){
 for(const btn of document.querySelectorAll('#app .tc-unified-nav button')){
  const k=btn.dataset.royal==='create-room'?'CREATE':btn.dataset.v;
  const span=btn.querySelector('span');
  if(!span||!icon[k])continue;
  span.innerHTML=vector(k);
 }
}
function layout(){
 if(screen!=='discoverPreview'||!signed())return;
 const nav=document.querySelector('#app .tc-unified-nav')?.outerHTML||'';
 const content='<section class="tc-explore" dir="rtl" aria-label="اكتشف الغرف الحقيقية">'+
 '<header class="tc-explore-hero"><img src="../assets/images/toti_falcon_logo_1790422919580.jpg" alt="TotiChat">'+
 '<div><h2>اكتشف عالم TotiChat</h2><p>غرف صوتية حقيقية وأصدقاء جدد. اختر الغرفة المناسبة لك.</p></div></header>'+
 '<label class="tc-explore-search"><input type="search" data-tc-room-search aria-label="ابحث عن غرفة حقيقية" placeholder="ابحث باسم الغرفة…" maxlength="60" autocomplete="off" value="'+esc(search)+'"></label>'+
 '<div class="tc-explore-label"><strong>الغرف المتاحة</strong><button type="button" data-tc-room-refresh>تحديث</button></div>'+
 '<div class="tc-explore-list" data-tc-room-results aria-live="polite"></div></section>';
 if(typeof page==='function'){
  document.getElementById('app').innerHTML=page('اكتشف الغرف',content);
  const standardNav=document.querySelector('#app nav.bottom');
  if(nav&&standardNav)standardNav.outerHTML=nav;
  navIcons();
 }
 paint();
 if(rows===null&&!loading)void load();
}
function paint(){
 const box=document.querySelector('#app [data-tc-room-results]');
 if(!box||screen!=='discoverPreview')return;
 if(loading&&rows===null){box.innerHTML='<p class="tc-explore-state" role="status">جارٍ تحميل الغرف الحقيقية…</p>';return;}
 if(error&&rows===null){
  box.innerHTML='<p class="tc-explore-state" role="alert">'+esc('تعذّر الاتصال بالغرف: '+error)+'</p>';
  return;
 }
 const found=(rows||[]).filter(r=>r&&uuid.test(r.id)&&typeof r.title==='string'&&
  r.title.toLocaleLowerCase().includes(search.toLocaleLowerCase())&&!r.is_private);
 box.innerHTML=found.length?found.map(r=>
  '<button type="button" class="tc-explore-room" data-phase2="open-room" data-room="'+esc(r.id)+'" aria-label="دخول الغرفة '+esc(r.title)+'">'+
  '<span class="tc-explore-room-art" aria-hidden="true">🎙️</span>'+
  '<strong>'+esc(r.title)+'</strong><small>● غرفة عامة · اضغط للدخول</small></button>').join(''):
  '<p class="tc-explore-state" role="status">'+(error?'تعذّر التحديث؛ النتائج السابقة ظاهرة إن وجدت. ':
  search?'ما لگينا غرفة تطابق البحث.':'ماكو غرف عامة متاحة حالياً. تگدر تنشئ أول غرفة من زر +.')+'</p>';
}
async function load(force=false){
 const id=auth.state().user?.id||'';
 if(!id||!signed()||loading)return;
 if(!force&&rows!==null)return;
 const n=++seq;loading=true;error='';
 paint();
 try{
  const data=await auth.requestData('/rest/v1/rooms?select=id,title,is_private,created_at&is_private=eq.false&order=created_at.desc&limit=100');
  if(n!==seq||auth.state().user?.id!==id)return;
  if(!Array.isArray(data))throw Error('Invalid room directory response');
  rows=data.filter(r=>uuid.test(r?.id)&&typeof r.title==='string');
 }catch(e){if(n===seq&&auth.state().user?.id===id)error=String(e?.message||'خطأ بالشبكة').slice(0,110);}
 finally{if(n===seq){loading=false;paint();}}
}
const previousRender=render;
render=function(){
 const result=previousRender.apply(this,arguments);
 document.body.classList.add('tc-real-mode');
 if(screen==='discoverPreview'&&signed())layout();
 else navIcons();
 return result;
};
document.addEventListener('input',event=>{
 if(!event.target.matches('[data-tc-room-search]'))return;
 search=String(event.target.value||'').slice(0,60);paint();
});
document.addEventListener('click',event=>{
 const button=event.target.closest?.('[data-tc-room-refresh]');
 if(button&&screen==='discoverPreview'){
  event.preventDefault();event.stopPropagation();rows=null;void load(true);
 }
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const id=auth.state().user?.id||'';
 if(id!==account){account=id;rows=null;error='';search='';loading=false;seq++;}
});
window.addEventListener('online',()=>{if(screen==='discoverPreview'&&signed())void load(true);});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&screen==='discoverPreview'&&signed())void load(true);});
document.body.classList.add('tc-real-mode');
navIcons();
})();
