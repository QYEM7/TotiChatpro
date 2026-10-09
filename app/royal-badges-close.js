/* TotiChat Royal Badge System + unified modal close button.
 * UI only. Does not change data, wallet, APIs, rooms or backend.
 */
(function(){
'use strict';
const tierNames=['البداية الملكية','اللؤلؤ الأزرق','الأماثيست','الياقوت','الزمرد','الصفير الملكي','ذهب الشمس','القرمزي الإمبراطوري','الماس السماوي','عرش الأساطير'];
const colors=[
 ['#59e5e8','#265ee1'],['#3dc8ff','#235bb9'],['#d08bff','#6e31c1'],
 ['#ff8895','#be184d'],['#82f5bb','#078565'],['#73d0ff','#244fb8'],
 ['#ffe6a0','#c27b21'],['#ff83b2','#8b1c75'],['#d8faff','#659dd4'],
 ['#ffe8a1','#a765ee']
];
let currentGroup=4, currentMode='wealth';
const achievements=[
 {name:'أول شحن',kind:'coin',desc:'الإنجاز الأول في رصيدك',tone:6},
 {name:'7 أيام دخول',kind:'calendar',desc:'سبعة أيام من الحضور',tone:1},
 {name:'المليونير',kind:'crown',desc:'إنجاز الثروة الكبير',tone:9},
 {name:'نجم الهدايا',kind:'rose',desc:'المحبة والعطاء',tone:3},
 {name:'مرسل الهدايا',kind:'gift',desc:'إهداء الأصدقاء',tone:2},
 {name:'مستوى 20',kind:'crystal',desc:'مرحلة التقدم المميزة',tone:4},
 {name:'نجم الجاذبية',kind:'heart',desc:'التألق الاجتماعي',tone:7},
 {name:'عضو مميز',kind:'shield',desc:'عضوية النخبة',tone:8},
 {name:'موسم 2026',kind:'medal',desc:'تذكار الموسم الملكي',tone:5}
];
const escapeText=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const cross='<svg viewBox="0 0 24 24" width="20" height="20" fill="none" aria-hidden="true"><path d="M6.5 6.5 17.5 17.5M17.5 6.5 6.5 17.5" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/></svg>';
function poly(cx,cy,r,n,rotate=-Math.PI/2){
 return Array.from({length:n},(_,i)=>[cx+Math.cos(rotate+2*Math.PI*i/n)*r,cy+Math.sin(rotate+2*Math.PI*i/n)*r]).map(v=>v.map(x=>x.toFixed(2)).join(',')).join(' ');
}
function crown(scale=1){
 return '<g transform="translate(60 35) scale('+scale+') translate(-60 -35)">'+
 '<path d="M39 36 43 23 52 31 60 15 68 31 77 23 81 36 76 41 44 41Z" fill="url(#metal)" stroke="#fff1ba" stroke-width="1.1"/>'+
 '<path d="M42 39H78V44H42Z" fill="#7d3e8a" stroke="#f8cd86" stroke-width="1.2"/>'+
 '<circle cx="43" cy="23" r="2.3" fill="#fff2c6"/><circle cx="60" cy="15" r="2.5" fill="#fff2c6"/><circle cx="77" cy="23" r="2.3" fill="#fff2c6"/>'+
 '<path d="M60 27 64 33 60 39 56 33Z" fill="#d88eff"/></g>';
}
function symbol(kind){
 const styles={
 star:'<path d="M60 42 66 55 81 57 70 67 72 82 60 75 48 82 50 67 39 57 54 55Z" fill="url(#gem)" stroke="#fff0cb" stroke-width="1.7"/>',
 crown:crown(1.22).replaceAll('url(#metal)','url(#metal)'),
 coin:'<circle cx="60" cy="63" r="20" fill="url(#metal)" stroke="#fff6c9" stroke-width="2.4"/><circle cx="60" cy="63" r="15" fill="none" stroke="#9c5e22" stroke-width="1.5"/><path d="M60 52v22M53 57q15-6 16 3-3 7-16 4 0 11 15 3" stroke="#6c3974" stroke-width="3" fill="none"/>',
 calendar:'<rect x="42" y="43" width="36" height="38" rx="6" fill="url(#gem)" stroke="#fff2c3" stroke-width="2.5"/><path d="M42 54H78M51 39v9M68 39v9" stroke="#ffedbb" stroke-width="3" stroke-linecap="round"/><path d="m52 67 5 5 12-13" stroke="#fff" stroke-width="3.2" stroke-linecap="round" fill="none"/>',
 rose:'<path d="M59 57c-13-11-18 4-9 11-10-1-10-14-3-19 2-12 21-15 28-3 9 8 1 23-13 24" fill="url(#gem)" stroke="#ffe6ca" stroke-width="1.7"/><path d="M59 70 60 85M60 75q-15-12-15-1 7 8 15 6M61 76q12-12 16-2-8 8-15 7" stroke="#9df0b5" stroke-width="3" fill="none"/>',
 gift:'<rect x="42" y="55" width="37" height="28" rx="4" fill="url(#gem)" stroke="#ffdfab" stroke-width="2"/><path d="M39 53H82V61H39Z" fill="url(#metal)" stroke="#fff1bf"/><path d="M60 52V84" stroke="#ffe4b8" stroke-width="5"/><path d="M60 53q-24 0-14-12 11-7 14 12Zm0 0q24 0 14-12-11-7-14 12Z" fill="url(#gem)" stroke="#ffeecb" stroke-width="1.5"/>',
 crystal:'<path d="M60 39 83 58 72 80 60 89 48 80 37 58Z" fill="url(#gem)" stroke="#eaffff" stroke-width="2"/><path d="M37 58H83M60 39 52 58 60 89M60 39 68 58 60 89M52 58H68" stroke="#fff5ff" stroke-width="1.5" fill="none"/>',
 heart:'<path d="M60 82C47 71 38 65 38 56c0-14 17-18 22-7 6-11 23-7 23 7 0 10-9 18-23 26Z" fill="url(#gem)" stroke="#ffdfc3" stroke-width="2"/><path d="M60 50v21M51 62h18" stroke="#f9d7ff" stroke-width="1.5" opacity=".8"/>',
 shield:'<path d="M60 38 80 46 77 66Q74 79 60 87Q46 79 43 66L40 46Z" fill="url(#gem)" stroke="#fff0c5" stroke-width="2.5"/><path d="M60 44 73 49 71 64Q69 73 60 79Q51 73 49 64L47 49Z" fill="none" stroke="#eed4ff" stroke-width="1.6"/>'+crown(.58),
 medal:'<path d="M45 37h11l4 17-10 6ZM64 37h11l-10 23-5-6Z" fill="url(#gem)" stroke="#ffdb9d"/><circle cx="60" cy="67" r="19" fill="url(#metal)" stroke="#fff0cb" stroke-width="2.4"/><circle cx="60" cy="67" r="13" fill="#421357" stroke="#ffe3a2"/><path d="M60 55 64 63 73 64 66 71 68 80 60 75 52 80 54 71 47 64 56 63Z" fill="#fff0be"/>',
 wing:'<path d="M55 61Q25 25 25 50Q29 72 51 78M65 61q30-36 30-11-4 22-26 28" fill="url(#gem)" stroke="#ffe2b2" stroke-width="2.2"/>',
 sun:'<circle cx="60" cy="64" r="17" fill="url(#gem)" stroke="#fff0c5" stroke-width="3"/>'+Array.from({length:12},(_,i)=>{const a=Math.PI*i/6;return '<path d="M'+(60+20*Math.cos(a)).toFixed(2)+' '+(64+20*Math.sin(a)).toFixed(2)+' '+(60+30*Math.cos(a)).toFixed(2)+' '+(64+30*Math.sin(a)).toFixed(2)+'" stroke="#ffdc98" stroke-width="3" stroke-linecap="round"/>'}).join(''),
 fleur:'<path d="M60 41q-15 13-7 25l7 7 7-7Q75 54 60 41ZM47 58q-19-21-20-3 0 15 27 13M73 58q19-21 20-3 0 15-27 13M60 73v11M49 80H71" fill="url(#gem)" stroke="#ffe7ac" stroke-width="2"/>',
 butterfly:'<path d="M58 63Q29 23 31 57 29 75 57 68Q34 93 51 91L60 71 69 91Q86 93 63 68 91 75 89 57 91 23 62 63Z" fill="url(#gem)" stroke="#ffe7ac" stroke-width="2"/><path d="M60 58v25M60 59q-6-17-11-15M60 59q6-17 11-15" stroke="#fff0e2" stroke-width="2" fill="none"/>',
 compass:'<circle cx="60" cy="64" r="19" fill="#28103b" stroke="#fce2b3" stroke-width="2.2"/><path d="M60 40 65 60 83 64 65 69 60 88 55 69 37 64 55 60Z" fill="url(#gem)" stroke="#fff0ce" stroke-width="1.5"/>'
 };
 return styles[kind]||styles.star;
}
const levelIcons=['star','compass','butterfly','fleur','sun','shield','crystal','wing','heart','crown'];
const frames=['shield','diamond','round','hex','star','ornate','oval','oct','heart','shield'];
function badgeSvg(level,mode='wealth',kind=null,toneOverride=null){
 const tone=toneOverride!==null?toneOverride:Math.min(9,Math.floor((level-1)/10));
 const [bright,dark]=colors[tone],id='rp'+mode.charAt(0)+String(level)+'-'+(kind||'level');
 const variant=kind||levelIcons[(level-1)%10];
 const variantIndex=(level-1)%10;
 const shape=frames[variantIndex];
 const pointCount=variantIndex%3===0?8:variantIndex%3===1?6:10;
 const border={
 shield:'M60 9 98 27 95 73Q93 99 60 121Q27 99 25 73L22 27Z',
 diamond:'M60 9 106 57 60 124 14 57Z',
 round:'M60 9C90 9 111 31 111 65C111 95 90 121 60 124C30 121 9 95 9 65C9 31 30 9 60 9Z',
 hex:'M60 9 99 31 99 93 60 122 21 93 21 31Z',
 star:'M60 7 74 25 98 24 101 48 114 65 99 84 97 107 74 106 60 125 46 106 22 107 21 84 7 65 19 48 22 24 46 25Z',
 ornate:'M60 9C81 9 98 22 97 36Q109 46 105 65Q110 84 95 93C89 109 73 119 60 124C47 119 31 109 25 93Q10 84 15 65Q11 46 23 36C22 22 39 9 60 9Z',
 oval:'M60 6C92 6 103 31 103 65C103 99 87 124 60 126C33 124 17 99 17 65C17 31 28 6 60 6Z',
 oct:'M44 9H76L102 32V91L76 123H44L18 91V32Z',
 heart:'M60 120Q3 89 14 44Q26 13 60 35Q94 13 106 44Q117 89 60 120Z'
 }[shape];
 const inner='M60 19 88 34 86 76Q81 97 60 111Q39 97 34 76L32 34Z';
 const details=Array.from({length:4+(level%5)},(_,i)=>{
  const n=(i+1)*(Math.PI*2/(4+level%5))+level*.034;
  const rad=variantIndex%2===0?33:37;
  const x=60+rad*Math.cos(n),y=67+rad*Math.sin(n);
  return '<circle cx="'+x.toFixed(2)+'" cy="'+y.toFixed(2)+'" r="'+(i%2?1.2:1.85)+'" fill="#ffeab5" opacity=".87"/>';
 }).join('');
 const jeweln=Math.max(1,level%7);
 const bottomStars=Array.from({length:Math.min(5,1+Math.floor(tone/2))},(_,i)=>'<path d="M'+(42+i*9)+' 105l1.8 3.1-1.8 3.1-1.8-3.1z" fill="#f7d993" opacity=".9"/>').join('');
 const specialMarks=Array.from({length:level%4+1},(_,i)=>'<circle cx="'+(46+i*7)+'" cy="27" r="'+(1.25+i*.12)+'" fill="#fff5d2" stroke="#9b4b9e" stroke-width=".5"/>').join('');
 const centerKind=mode==='magic'&&kind===null?levelIcons[(level+2)%10]:variant;
 return '<svg class="rp-badge-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 134" role="img" aria-label="'+escapeText(kind?'شارة '+kind:'شارة المستوى '+level)+'">'+
 '<defs><linearGradient id="'+id+'-bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5c1b7b"/><stop offset=".54" stop-color="#241035"/><stop offset="1" stop-color="#0d071e"/></linearGradient>'+
 '<linearGradient id="'+id+'-m" x1="0" y1="0" x2="1" y2=".9"><stop offset="0" stop-color="#fff8d3"/><stop offset=".28" stop-color="#ecc276"/><stop offset=".48" stop-color="#956026"/><stop offset=".72" stop-color="#ffdf9b"/><stop offset="1" stop-color="#ac6e33"/></linearGradient>'+
 '<radialGradient id="'+id+'-g" cx=".31" cy=".23" r=".9"><stop offset="0" stop-color="#fffaff"/><stop offset=".18" stop-color="'+bright+'"/><stop offset=".73" stop-color="'+dark+'"/><stop offset="1" stop-color="#190d36"/></radialGradient>'+
 '<filter id="'+id+'-glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.8"/></filter></defs>'+
 '<g style="--dummy:0" transform="translate(0 0)"><path d="'+border+'" fill="#b64ce1" stroke="#f8d898" stroke-width="1" opacity=".4" filter="url(#'+id+'-glow)"/>'+
 '<path d="'+border+'" fill="url(#'+id+'-bg)" stroke="url(#'+id+'-m)" stroke-width="4"/>'+
 '<path d="'+border+'" fill="none" stroke="#f7d39d" stroke-width="1.1" opacity=".7" transform="translate(60 65) scale(.9) translate(-60 -65)"/>'+
 '<path d="'+inner+'" fill="#8a2bae" opacity=".17" stroke="url(#'+id+'-m)" stroke-width="1.1"/>'+
 '<path d="M25 42Q6 52 16 78Q26 94 40 97M95 42Q114 52 104 78Q94 94 80 97" fill="none" stroke="url(#'+id+'-m)" stroke-width="'+(1.7+tone*.12)+'" stroke-linecap="round"/>'+
 '<path d="M23 50q-7 8-3 13m77-13q7 8 3 13" fill="none" stroke="#f7e2b1" stroke-width="1.3"/>'+
 '<g><circle cx="60" cy="64" r="27" fill="url(#'+id+'-g)" opacity=".11"/>'+
 '<circle cx="60" cy="65" r="'+(22+(level%4))+'" fill="none" stroke="'+bright+'" stroke-width=".7" stroke-dasharray="'+(jeweln+2)+' 4" opacity=".75"/>'+
 '<g transform="translate(0 0)">'+symbol(centerKind)+'</g></g>'+
 '<path d="M43 96Q60 101 77 96" stroke="url(#'+id+'-m)" fill="none" stroke-width="1.6"/>'+
 details+specialMarks+bottomStars+
 '<g fill="#fff1ce"><path d="M60 5l2 4-2 4-2-4zM10 64l4 2-4 2-4-2zM110 64l4 2-4 2-4-2z" opacity=".95"/></g>'+
 '<g><rect x="41" y="111" width="38" height="16" rx="7" fill="#421653" stroke="url(#'+id+'-m)" stroke-width="1.6"/>'+
 '<text x="60" y="122.6" fill="#ffedc0" stroke="#180723" stroke-width=".25" text-anchor="middle" font-size="'+(level>9?12:13)+'" font-weight="900" font-family="Arial, sans-serif">'+(kind?'✦':level)+'</text></g>'+
 '</g></svg>'.replaceAll('url(#metal)','url(#'+id+'-m)').replaceAll('url(#gem)','url(#'+id+'-g)');
}
function levelCard(n){
 const current=45;const locked=n>current;
 return '<button class="rp-level-card'+(n===current?' rp-current':'')+(locked?' rp-locked':'')+'" type="button" data-rp="level-detail" data-level="'+n+'" aria-label="عرض شارة المستوى '+n+'">'+
 '<div class="rp-level-art">'+badgeSvg(n,currentMode)+'</div>'+
 '<strong>المستوى '+n+'</strong><span>'+(n<current?'✓ مكتمل':n===current?'✦ مستواك الحالي':'♙ لم تصل إليه بعد')+'</span>'+
 '</button>';
}
level=function(){
 const from=currentGroup*10+1,to=Math.min(100,from+9),tone=currentGroup;
 const groups=Array.from({length:10},(_,i)=>{
  const count=i*10+1;return '<button data-rp="group" data-group="'+i+'" class="'+(i===currentGroup?'active':'')+'" aria-pressed="'+(i===currentGroup)+'">'+count+'–'+(count+9)+'</button>';
 }).join('');
 const owned=badgeSvg(45);
 return page('المستوى',
 '<div class="rp-level-page" dir="rtl">'+
 '<div class="rp-level-hero"><span class="rp-level-shine">✧ ROYAL LEVEL ✧</span><div class="rp-active-badge">'+owned+'</div>'+
 '<div class="rp-level-user"><small>مستواك الحالي</small><h2>المستوى 45</h2><p>إطار ملكي مميز خاص بكل مستوى</p><div class="rp-progress-label"><span>التقدم نحو المستوى 46</span><b>62%</b></div>'+
 '<div class="rp-progress"><span style="width:62%"></span></div></div></div>'+
 '<div class="rp-level-switch" role="tablist"><button data-rp="mode" data-mode="wealth" role="tab" aria-selected="'+(currentMode==='wealth')+'" class="'+(currentMode==='wealth'?'active':'')+'">♛ الثروة</button>'+
 '<button data-rp="mode" data-mode="magic" role="tab" aria-selected="'+(currentMode==='magic')+'" class="'+(currentMode==='magic'?'active':'')+'">✧ السحر</button></div>'+
 '<h3 class="rp-heading">مجموعة '+(tone+1)+' · '+tierNames[tone]+'</h3>'+
 '<p class="rp-subcopy">100 شارة ملكية مختلفة، لكل مستوى نقوشه ورمزه الخاص. اختَر مجموعة لمشاهدة شاراتها.</p>'+
 '<div class="rp-level-groups" aria-label="مجموعات المستويات">'+groups+'</div>'+
 '<div class="rp-level-grid">'+Array.from({length:to-from+1},(_,i)=>levelCard(from+i)).join('')+'</div>'+
 '<div class="rp-level-note">✦ شارات المستويات تجريبية بصرياً. الربط بمستوى الحساب الحقيقي يتم بعد موافقتك على الـBackend.</div>'+
 '</div>');
};
honor=function(){
 return page('الشارات',
 '<div class="rp-honor-page" dir="rtl"><div class="rp-honor-hero">'+
 '<span class="rp-honor-crown">♛</span><h2>مجموعة الشارات الملكية</h2><p>إنجازات فريدة بتصميم TotiChat البنفسجي والذهبي</p>'+
 '<div class="rp-honor-stats"><b>9</b><small>شارات إنجاز متنوعة</small><span>✦ لم تُفتح بعد</span></div></div>'+
 '<h3 class="rp-heading">✧ شارات الإنجازات</h3>'+
 '<div class="rp-honor-grid">'+achievements.map((x,i)=>{
 const level=10*(x.tone+1);
 return '<button class="rp-honor-card" '+act('sheet','medal:'+i)+' aria-label="تفاصيل شارة '+escapeText(x.name)+'">'+
 '<div class="rp-honor-icon">'+badgeSvg(level,'honor',x.kind,x.tone)+'</div>'+
 '<strong>'+escapeText(x.name)+'</strong><small>'+escapeText(x.desc)+'</small>'+
 '<span class="rp-honor-status">♙ لم تُفتح بعد</span></button>';
 }).join('')+'</div>'+
 '<div class="rp-level-note">✦ تصميم الشارات متاح للمعاينة؛ حالة الفتح والإنجاز تُربط لاحقاً بالبيانات الحقيقية.</div>'+
 '</div>');
};
function closePolish(){
 const overlay=document.getElementById('overlay');
 if(!overlay||!overlay.classList.contains('show'))return;
 const sheet=document.getElementById('sheet');
 if(!sheet)return;
 let close=sheet.querySelector('button.room-glass-close,button.tc-x,button.xbtn');
 if(!close)return;
 if(close.dataset.rpClose==='1')return;
 close.dataset.rpClose='1';close.classList.add('rp-unified-close');
 close.setAttribute('type','button');close.setAttribute('aria-label','إغلاق النافذة');
 close.innerHTML=cross;
 if(sheet.classList.contains('room-glass')){
  let wrap=sheet.querySelector('.rp-room-menu-head');
  if(!wrap){
   wrap=document.createElement('div');
   wrap.className='rp-room-menu-head';
   const title=document.createElement('b');title.textContent='♛ خيارات الغرفة';wrap.appendChild(title);
   sheet.insertBefore(wrap,sheet.firstChild);
  }
  wrap.appendChild(close);
 }
}
const overlay=document.getElementById('overlay');
if(overlay){new MutationObserver(closePolish).observe(overlay,{childList:true,subtree:true,attributes:true,attributeFilter:['class']});}
function onBadgeAction(e){
 const b=e.target.closest('[data-rp]');if(!b)return;
 e.preventDefault();e.stopImmediatePropagation();
 const a=b.dataset.rp;
 if(a==='group'){
  currentGroup=Math.max(0,Math.min(9,Number(b.dataset.group)||0));render();
 }else if(a==='mode'){
  currentMode=b.dataset.mode==='magic'?'magic':'wealth';render();
 }else if(a==='level-detail'){
  const n=Number(b.dataset.level)||1;
  const status=n<45?'مكتمل':n===45?'مستواك الحالي':'لم تصل إلى هذا المستوى بعد';
  const current=badgeSvg(n,currentMode);
  showSheet('<div class="rp-badge-detail" dir="rtl"><div class="sheethead"><h3>شارة المستوى '+n+'</h3><button class="xbtn" '+act('close')+' aria-label="إغلاق">✕</button></div>'+
   '<div class="rp-detail-gem">'+current+'</div><h3>✦ '+tierNames[Math.floor((n-1)/10)]+'</h3>'+
   '<p>'+status+'</p><div class="rp-level-note">هذه معاينة للشارة المخصصة للمستوى '+n+'.</div></div>');
  closePolish();
 }
}
document.addEventListener('click',onBadgeAction,true);
closePolish();
})();