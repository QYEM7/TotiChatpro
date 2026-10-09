/* TotiChat VIP 1–15 • Royal frontend-only gallery.
   All badges and privileges are local visual specifications.
   Does not modify balances, ownership, room sessions or any backend.
*/
(function () {
'use strict';
const e=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const tiers=[
 ['الوعل الملكي','✦','أول شارة ملكية','شارة VIP مميزة بجانب الاسم','deer','#daaa81'],
 ['الصقر البلاتيني','❖','فقاعة التحية','فقاعة دردشة بتوقيع ملكي ناعم','falcon','#ded7fd'],
 ['الذئب الذهبي','◆','إطار الصورة الذهبي','إطار ذهبي حول الصورة الشخصية','wolf','#ffda83'],
 ['الفهد الزمردي','♠','بطاقة حضور الغرفة','بطاقة هوية مصغرة مميزة في الغرفة','leopard','#7bedba'],
 ['الدب الأرجواني','❀','شريط دخول خاص','شريط أنيق لإعلان الدخول إلى الغرفة','bear','#e2abff'],
 ['النمر الأزرق','✧','لوحة الاسم الملكية','Nameplate مزخرف بجانب اسم المستخدم','tiger','#93bcff'],
 ['الفينيق الوردي','♜','لمعة الرسائل','إضاءة خاصة تحيط برسائل المستخدم','phoenix','#ff9ddc'],
 ['الأسد الإمبراطوري','✹','دخول متلألئ','شرارات ملكية عند دخول الغرفة','lion','#ffd487'],
 ['اللؤلؤة الأسطورية','◈','إعلان الهدية المميز','بطاقة بصرية فاخرة باسم مرسل الهدية','pearl','#dceafe'],
 ['تاج الملوك','♛','إطار متحرك ملكي','إطار متحرك للملف والمقعد','crown','#eebd76'],
 ['أجنحة النخبة','❁','إطار رسالة النخبة','رسائل مزخرفة بأجنحة ملكية','wings','#c9baff'],
 ['تنين الأساطير','✦','تأثير دخول أسطوري','دخول مع جناحين وهالة متحركة','dragon','#edb4fd'],
 ['عرش الماس','❂','بطاقة الهوية الأسطورية','بطاقة تعريف كاملة بإطار الماس','diamond','#c0e9ff'],
 ['الإمبراطور الأعلى','♛','موكب الإمبراطور','مؤثر دخول إمبراطوري وإعلان حضور فخم','imperial','#ffe0a0'],
 ['التاج الأسمى','✺','هالة التاج الأسمى','تاج وهالة وبصمة حصرية أعلى مستوى VIP','supreme','#ffdcaa']
];
const prices=[null,15000,30000,49000,75000,120000,175000,250000,360000,490000,650000];
const emoji=['','♛','❖','◆','❀','✧','✹','♜','♛','◈','♛','❁','♜','❂','♛','✺'];
const ident=['','diamond','hex','shield','star','oct','round','shield','oct','orb','crown','wings','dragon','diamond','imperial','sun'];
const q=s=>document.querySelector(s);
let activeView='معلومات';
let effectPlaying=false;
const p=n=>Math.max(1,Math.min(15,Number(n)||5));
const modeName=t=>tiers[p(t)-1][0];
function ring(n){
 const shape=['','M60 10 98 35 92 91 60 119 28 91 22 35Z','M60 9 102 32 102 88 60 124 18 88 18 32Z','M60 8 94 22 106 64 88 105 60 123 32 105 14 64 26 22Z',
 'M60 6 74 24 99 23 101 48 113 64 98 83 96 108 74 106 60 124 46 106 24 108 22 83 7 64 19 48 21 23 46 24Z',
 'M45 9H75L104 32V95L75 124H45L16 95V32Z',
 'M60 8C87 8 104 32 104 65S87 124 60 124 16 98 16 65 33 8 60 8Z',
 'M60 7 103 39 103 88 60 123 17 88 17 39Z',
 'M60 7 76 17 96 14 98 38 111 60 99 85 96 111 73 110 60 125 47 110 24 111 21 85 9 60 22 38 24 14 44 17Z',
 'M60 9C89 9 107 36 107 67C107 95 89 121 60 124C31 121 13 95 13 67 13 36 31 9 60 9Z',
 'M60 7 83 16 100 38 105 72 88 103 60 125 32 103 15 72 20 38 37 16Z',
 'M60 7 94 21 107 55 102 93 60 126 18 93 13 55 26 21Z',
 'M60 9 91 22 108 54 99 92 60 124 21 92 12 54 29 22Z',
 'M60 9 82 21 105 60 82 107 60 124 38 107 15 60 38 21Z',
 'M60 8 92 21 113 58 101 94 60 126 19 94 7 58 28 21Z',
 'M60 6 82 18 103 21 107 46 115 65 105 87 95 110 74 108 60 127 46 108 25 110 15 87 5 65 13 46 17 21 38 18Z'];
 return shape[n];
}
function crest(n,small=false){
 n=p(n);
 const [name,, , ,kind,accent]=tiers[n-1],id='rvip'+n+(small?'s':'b');
 const arches=Array.from({length:n<5?5:n<10?7:9},(_,i)=>{
  const x=15+i*(90/(n<5?4:n<10?6:8));
  return '<circle cx="'+x.toFixed(1)+'" cy="'+(67-Math.abs(4-i%4)*2)+'" r="'+(i%2?1.8:2.5)+'" fill="#ffdeab" opacity=".9"/>';
 }).join('');
 const ornaments=Array.from({length:8},(_,i)=>{const a=i*Math.PI/4+n*.043;const x=60+46*Math.cos(a),y=67+48*Math.sin(a);
 return '<path d="M'+x.toFixed(2)+' '+(y-3).toFixed(2)+'l2.6 3-2.6 3-2.6-3z" fill="'+accent+'" stroke="#fff0d1" stroke-width=".5"/>';
 }).join('');
 const crown='<path d="M38 39 44 24 52 33 60 17 68 33 76 24 82 39 78 45 42 45Z" fill="url(#'+id+'gold)" stroke="#fff0cb" stroke-width="1.1"/><path d="M42 40H78V45H42Z" fill="#51105f" stroke="#fff0cb" stroke-width="1.1"/><circle cx="60" cy="29" r="4" fill="url(#'+id+'gem)"/>';
 const wing='<path d="M42 58Q15 26 14 54q1 17 29 25Q28 64 21 51q18 4 31 25M78 58q27-32 28-4-1 17-29 25 15-15 22-28-18 4-31 25" fill="url(#'+id+'gold)" opacity=".85" stroke="#ffe6bc" stroke-width="1"/>';
 const lion='<path d="M60 45Q38 33 38 51L32 61 39 73 40 86 60 94 80 86 81 73 88 61 82 51Q82 33 60 45ZM50 62h3m14 0h3M54 77l6 4 6-4" fill="url(#'+id+'gold)" stroke="#fff0c9" stroke-width="2"/>';
 const gem='<path d="M60 46 78 60 68 85 60 93 52 85 42 60Z" fill="url(#'+id+'gem)" stroke="#fff3db" stroke-width="2.5"/><path d="M42 60h36M60 46 53 60 60 93M60 46 67 60 60 93" fill="none" stroke="#fff6ef" stroke-width="1.25"/>';
 let motif;
 if(['falcon','phoenix','wings','dragon'].includes(kind))motif=wing+gem;
 else if(['bear','wolf','leopard','tiger','lion','deer'].includes(kind))motif=lion;
 else if(kind==='pearl')motif='<circle cx="60" cy="69" r="21" fill="url(#'+id+'gem)" stroke="#fce2b3" stroke-width="3"/><path d="M48 62q8-14 19-12" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>';
 else if(['imperial','supreme','crown'].includes(kind))motif=crown+gem+(n>=14?wing:'');
 else motif=gem;
 const spread=n>=11?wing:'';
 return '<svg class="rvip-crest" viewBox="0 0 120 142" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="شارة VIP '+n+' '+e(name)+'">'+
 '<defs><linearGradient id="'+id+'gold" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#fff6d4"/><stop offset=".28" stop-color="#fac875"/><stop offset=".6" stop-color="#8d532f"/><stop offset=".81" stop-color="#ffdc91"/><stop offset="1" stop-color="#b56d32"/></linearGradient>'+
 '<radialGradient id="'+id+'gem"><stop stop-color="#fff7ff"/><stop offset=".3" stop-color="'+accent+'"/><stop offset=".82" stop-color="#7824b0"/><stop offset="1" stop-color="#281035"/></radialGradient>'+
 '<linearGradient id="'+id+'bg" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#4c135d"/><stop offset=".6" stop-color="#180922"/><stop offset="1" stop-color="#68267a"/></linearGradient></defs>'+
 '<path d="'+ring(n)+'" fill="url(#'+id+'bg)" stroke="url(#'+id+'gold)" stroke-width="'+(n>=11?4:3)+'"/>'+
 '<path d="'+ring(n)+'" fill="none" stroke="'+accent+'" stroke-width=".9" transform="translate(60 67) scale(.88) translate(-60 -67)" opacity=".92"/>'+
 spread+
 '<circle cx="60" cy="67" r="'+(24+n%4)+'" fill="url(#'+id+'gem)" opacity=".35" stroke="url(#'+id+'gold)" stroke-width="1.2"/>'+
 motif+ornaments+arches+
 (n>=9?'<path d="M60 5 64 14 73 18 64 22 60 31 56 22 47 18 56 14Z" fill="url(#'+id+'gold)" opacity=".9"/>':'')+
 '<rect x="35" y="114" width="50" height="20" rx="10" fill="#2c0d37" stroke="url(#'+id+'gold)" stroke-width="2"/>'+
 '<text x="60" y="128.7" font-family="Arial,sans-serif" font-weight="900" font-size="'+(n>=10?13:14)+'" text-anchor="middle" fill="#ffebbb">VIP '+n+'</text>'+
 '</svg>';
}
function uniqueAdvantages(n){
 const benefitRows=[
 ['شارة حصرية','هوية VIP واضحة باسمك وشارتك','♛'],
 ['توقيع الدردشة','فقاعة دردشة خاصة برسائلك','💬'],
 ['إطار البروفايل','زخرفة ملكية لصورة الحساب','🖼️'],
 ['بطاقة الغرفة','بطاقة حضور باسمك وصورتك','🎙️'],
 ['إعلان الدخول','شريط ترحيبي عند دخول الغرفة','✨'],
 ['لوحة الاسم','اسم مزخرف خاص داخل الغرفة','👑'],
 ['وهج الدردشة','توهج بنفسجي حول الرسائل','💜'],
 ['شرارات الدخول','مؤثر ترحيب متلألئ','🌟'],
 ['لافتة الهدايا','بطاقة مرسل هدية مميزة','🎁'],
 ['إطار متحرك','إطار ملكي بحركة ناعمة','💠'],
 ['رسالة النخبة','إطار رسائل مزين بالأجنحة','🪽'],
 ['دخول أسطوري','جناحان وهالة عند الدخول','🔥'],
 ['هوية أسطورية','بطاقة تعريف ماسية كاملة','💎'],
 ['موكب إمبراطوري','حدث دخول مميز للغرفة','🏰'],
 ['التاج الأسمى','هالة التاج وبصمة VIP العليا','👑']
 ];
 return benefitRows.map((r,i)=>({...{title:r[0],desc:r[1],icon:r[2]},unlocked:i<n,featured:i===n-1,index:i+1}));
}
function enterStrip(n){
 const t=tiers[n-1];return '<div class="rvip-enter-line rvip-tone-'+n+'"><span>✦</span>'+crest(n,true)+'<div><b>VIP '+n+' · '+e(t[0])+'</b><small>دخول ملكي مميز إلى الغرفة</small></div><strong>✨</strong></div>';
}
function scenario(n){
 return '<div class="rvip-scenario">'+
 '<h3>✦ معاينة المميزات داخل التطبيق</h3>'+
 '<div class="rvip-scenario-avatar"><img src="'+A+assets.avatar+'" alt="صورة مستخدم تجريبية">'+crest(n,true)+'<span>اسم المستخدم · VIP '+n+'</span></div>'+
 '<div class="rvip-scenario-chat">'+crest(n,true)+'<span>أهلاً بالأصدقاء في TotiChat ✨</span></div>'+enterStrip(n)+
 '<p>هذه معاينة محلية للزخارف والمؤثرات، وليست ترقية فعلية لحساب المستخدم.</p></div>';
}
function tierCard(n,selected){
 return '<button class="rvip-tier'+(selected===n?' selected':'')+'" data-vip15="select" data-level="'+n+'" aria-pressed="'+(selected===n)+'" aria-label="معاينة VIP '+n+'">'+
 '<span>'+crest(n,true)+'</span><b>VIP '+n+'</b><small>'+e(tiers[n-1][0])+'</small></button>';
}
function benefitCard(row){
 return '<div class="rvip-benefit'+(row.featured?' featured':'')+(row.unlocked?'':' locked')+'">'+
 '<span class="rvip-benefit-ico">'+row.icon+'</span><div><b>'+e(row.title)+'</b><small>'+e(row.desc)+'</small></div>'+
 '<span class="rvip-benefit-status">'+(row.unlocked?'✓':'🔒')+'</span></div>';
}
function purchaseUi(n){
 const price=prices[n],eligible=price!==undefined&&price!==null;
 return '<div class="rvip-buy-panel"><div class="rvip-buy-row"><div><small>رصيد المعاينة</small><b>🪙 8,200</b></div>'+
 '<div><small>اشتراك 30 يوم — توضيحي</small><b>'+(eligible?'🪙 '+price.toLocaleString('en-US'):'السعر غير معتمد')+'</b></div></div>'+
 '<div class="rvip-buy-actions"><button data-vip15="upgrade" class="rvip-upgrade">♛ '+(eligible?'معاينة طلب VIP '+n:'مراجعة المستوى')+'</button>'+
 '<button data-vip15="agents">وكلاء الشحن</button></div>'+
 '<p>لا يوجد شراء داخل التطبيق في هذه المعاينة. الشحن مستقبلاً عبر الوكلاء المعتمدين، وبعد مراجعة سياسات المتجر. الأسعار المذكورة للمستويات السابقة توضيحية وغير ملزمة.</p></div>';
}
vVIP=function(){
 const n=p(vt.vip);vt.vip=n;
 const t=tiers[n-1];
 const tabs=['معلومات','المميزات','المعاينة','الأسعار'];
 const hero='<div class="rvip-hero"><div class="rvip-hero-header"><span>✧ ROYAL VIP COLLECTION ✧</span><span>VIP 01–15</span></div>'+
 '<div class="rvip-hero-center"><div class="rvip-hero-crest">'+crest(n)+'</div><div class="rvip-hero-copy"><small>المستوى المختار</small><h2>VIP '+n+'</h2><strong>'+e(t[0])+'</strong><p>'+e(t[2])+'</p>'+
 '<span class="rvip-hero-tag">✦ '+n+' من 15 · مميزات تراكمية</span></div></div><div class="rvip-hero-footer">✦ ROYALTY · EXCLUSIVITY · TOTICHAT ✦</div></div>';
 const chooser='<div class="rvip-subheading"><h3>اختر مستوى VIP</h3><span>15 شارة ملكية فريدة</span></div>'+
 '<div class="rvip-tier-list">'+Array.from({length:15},(_,i)=>tierCard(i+1,n)).join('')+'</div>';
 let content;
 if(activeView==='المميزات'){
  content='<div class="rvip-subheading"><h3>امتيازات VIP '+n+'</h3><span>السابقة + الامتياز الجديد</span></div>'+
   '<div class="rvip-benefits">'+uniqueAdvantages(n).map(benefitCard).join('')+'</div>';
 }else if(activeView==='المعاينة'){
  content=scenario(n)+'<button class="rvip-effect-action" data-vip15="effect">✦ جرّب تأثير الدخول</button>';
 }else if(activeView==='الأسعار'){
  content='<div class="rvip-subheading"><h3>تفاصيل الاشتراك</h3><span>المستوى المختار VIP '+n+'</span></div>'+purchaseUi(n);
 }else{
  const advantages=uniqueAdvantages(n);
  content='<div class="rvip-subheading"><h3>ما الجديد في VIP '+n+'؟</h3><span>ميزة حصرية لكل مستوى</span></div>'+
   '<div class="rvip-feature-focus">'+crest(n,true)+'<div><strong>'+e(advantages[n-1].title)+'</strong><p>'+e(advantages[n-1].desc)+'</p></div></div>'+
   '<div class="rvip-subheading"><h3>المزايا المتاحة</h3><button data-vip15="tab" data-tab="المميزات">عرض جميع المزايا ❮</button></div>'+
   '<div class="rvip-benefits">'+advantages.filter(x=>x.unlocked).slice(-3).map(benefitCard).join('')+'</div>'+
   scenario(n);
 }
 return '<div class="rvip-root vip-royal" dir="rtl">'+
 '<header class="rvip-header"><button data-vip15="back" aria-label="رجوع">❯</button><div><span>♛ TotiChat</span><h1>المملكة الملكية VIP</h1></div><span class="rvip-crown">👑</span></header>'+
 hero+chooser+'<nav class="rvip-tabs" aria-label="صفحات VIP">'+tabs.map(tab=>
 '<button data-vip15="tab" data-tab="'+tab+'" class="'+(activeView===tab?'active':'')+'" aria-pressed="'+(activeView===tab)+'">'+tab+'</button>').join('')+'</nav>'+
 '<div class="rvip-content">'+content+'</div>'+
 '<p class="rvip-privacy">معاينة تصميم فقط — لا تعديل على رصيد أو صلاحيات أو بيانات الحساب أو الـBackend.</p>'+
 '<div class="rvip-navback"><button data-vip15="back">العودة إلى التطبيق</button></div></div>';
};
function centerSelectedVIP(){
 const selected=q('.rvip-tier.selected');
 if(!selected)return;
 requestAnimationFrame(()=>selected.scrollIntoView({block:'nearest',inline:'center',behavior:'instant'}));
}
function details(n) {
 const row=tiers[n-1],b=uniqueAdvantages(n)[n-1];
 showSheet('<div class="rvip-detail" dir="rtl">'+head('تفاصيل VIP '+n)+
 '<div class="rvip-detail-crest">'+crest(n)+'</div>'+
 '<h3>VIP '+n+' · '+e(row[0])+'</h3><div class="rvip-feature-focus">'+crest(n,true)+'<div><strong>'+e(b.title)+'</strong><p>'+e(b.desc)+'</p></div></div>'+
 '<p>الاشتراك والرصيد بيانات توضيحية. لا تنفذ المعاينة أي عملية مالية.</p>'+
 '<button class="rvip-upgrade" data-vip15="dismiss">فهمت</button></div>');
}
document.addEventListener('click',function(event){
 const btn=event.target.closest('[data-vip15]');if(!btn)return;
 event.preventDefault();event.stopImmediatePropagation();
 const action=btn.dataset.vip15,n=p(btn.dataset.level);
 if(action==='select'){vt.vip=n;render();centerSelectedVIP();}
 else if(action==='tab'){activeView=btn.dataset.tab;render();centerSelectedVIP();}
 else if(action==='back'){back();}
 else if(action==='effect'){
  if(effectPlaying)return;
  const root=q('.rvip-root');if(!root)return;
  effectPlaying=true;root.classList.add('rvip-effect-running');
  const overlay=document.createElement('div');overlay.className='rvip-effect-overlay';
  overlay.innerHTML='<div>'+crest(p(vt.vip))+'<h2>✧ VIP '+p(vt.vip)+' ✧</h2><span>هنا يبدأ المجد الملكي</span></div>';
  root.appendChild(overlay);
  setTimeout(()=>{overlay.remove();root.classList.remove('rvip-effect-running');effectPlaying=false;},2000);
 }
 else if(action==='upgrade'){details(p(vt.vip));}
 else if(action==='agents'){go('rechargePreview');}
 else if(action==='dismiss'){closeSheet();}
},true);
const preview=new URLSearchParams(location.search);
if(preview.get('view')==='royal-vip'){
 vt.vip=p(preview.get('vip')||5);
 go('vip');
 centerSelectedVIP();
}
window.TotiChatVIPPreview=Object.freeze({
 total:15,
 names:tiers.map(x=>x[0]),
 benefits:tiers.map((x,i)=>({level:i+1,title:uniqueAdvantages(i+1)[i].title})),
 renderCrest:crest
});
})();