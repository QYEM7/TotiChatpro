/* TotiChat Admin — independent browser application (STAGING only).
   No fake financial numbers, no service-role credentials, no production writes.
   All authority-sensitive operations are authorized again inside Postgres RPCs. */
(function(){
'use strict';
const API='https://rziaedugbdwefbefcxjt.supabase.co';
const KEY='sb_publishable_vVYku5VtyohuiGgehC3EdA_rSDGOUKB';
const BUCKET='totichat-admin-banners';
const $=q=>document.querySelector(q);
const safe=x=>String(x??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const fmt=n=>(Number.isSafeInteger(n)&&n>=0)?n.toLocaleString('ar-IQ'):'—';
const icons={overview:'◫',banners:'▣',users:'♙',rooms:'◉',hosts:'⌂',recharge:'◇',treasury:'▤',vip:'♛',medals:'✿',catalog:'✧',support:'☏',reports:'▥',team:'♧',settings:'⚙'};
function svgIcon(key){
 const paths={
  overview:'<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/>',
  banners:'<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
  users:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
  rooms:'<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 10v4m6-4v4M7 7h10M7 17h10"/>',
  hosts:'<path d="m3 10 9-7 9 7"/><path d="M5 9v11h14V9M9 20v-7h6v7"/>',
  recharge:'<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20M6 15h4"/>',
  treasury:'<path d="M3 7h18M5 7V4h14v3M5 7v12h14V7M9 12h6M9 16h6"/>',
  vip:'<path d="m2 7 5 4 5-7 5 7 5-4-2 13H4L2 7Z"/>',
  medals:'<circle cx="12" cy="17" r="4"/><path d="m6 2 3 9 3-3 3 3 3-9M12 15v4m-2-2h4"/>',
  catalog:'<path d="M3 9h18v12H3zM3 9l3-6h12l3 6M9 9v12M15 9v12"/>',
  support:'<path d="M3 12a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-2v-7h4M3 14h4v7H5a2 2 0 0 1-2-2z"/>',
  reports:'<path d="M4 20V4m0 16h17M8 17v-6m5 6V7m5 10v-9"/>',
  team:'<circle cx="12" cy="8" r="4"/><path d="M5 21v-2a7 7 0 0 1 14 0v2M18 4l2 2-2 2"/>',
  settings:'<circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M4.93 4.93l2.12 2.12m9.9 9.9 2.12 2.12M2 12h3m14 0h3M4.93 19.07l2.12-2.12m9.9-9.9 2.12-2.12"/>'
 };
 return '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+
 (paths[key]||paths.overview)+'</svg>';
}

const nav=[
 ['overview','الرئيسية','عام'],['banners','إدارة البنرات','محتوى'],['users','المستخدمون','إدارة التطبيق'],
 ['rooms','الغرف الصوتية','إدارة التطبيق'],['hosts','وكالات المضيفين','الوكالات والمالية'],
 ['recharge','وكالات الشحن','الوكالات والمالية'],['treasury','الخزينة والتدقيق','الوكالات والمالية'],
 ['vip','VIP والمستويات','الامتيازات'],['medals','المداليات','الامتيازات'],['catalog','الهدايا والمتجر','المحتوى والمتابعة'],
 ['support','خدمة العملاء','المحتوى والمتابعة'],['reports','التقارير','المحتوى والمتابعة'],
 ['team','الرتب والصلاحيات','النظام'],['settings','إعدادات النظام','النظام']
];
const names=Object.fromEntries(nav.map(x=>[x[0],x[1]]));
let session=null,rights=null,current='overview',loading=false,banners=[],bannerTotal=0,bannerOffset=0;
let editingId=null,previewBlob=null,previewUrl=null,toastTimer=null,epoch=0,writeBusy=false,detailOffset=0,directoryOffset=0,directoryQuery='';
function setError(text){$('#login-error').textContent=String(text||'').slice(0,320);}
function toast(msg,failed=false){
 const el=$('#toast');el.textContent=String(msg||'').slice(0,260);
 el.style.background=failed?'#a4564b':'#234d3b';el.classList.add('visible');
 clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('visible'),3800);
}
function throwFor(resp,body){
 if(resp.ok)return;
 const message=body?.msg||body?.message||body?.error_description||body?.error||('HTTP '+resp.status);
 throw Error(String(message).slice(0,280));
}
async function publicFetch(path,body){
 const r=await fetch(API+path,{method:'POST',headers:{'apikey':KEY,'Content-Type':'application/json'},body:JSON.stringify(body)});
 const data=await r.json().catch(()=>({}));throwFor(r,data);return data;
}
async function refreshToken(){
 if(!session?.refresh_token)throw Error('انتهت الجلسة. يرجى تسجيل الدخول مجدداً.');
 const next=await publicFetch('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token});
 if(!next.access_token)throw Error('تعذر تجديد الجلسة');
 session=Object.assign({},session,next,{user:next.user||session.user,_obtainedAt:Date.now()});return session.access_token;
}
async function authed(path,opts={},retried=false){
 if(!session?.access_token)throw Error('الرجاء تسجيل الدخول.');
 if(Date.now()>sessionExpiry()-60000&&!retried)await refreshToken();
 const method=opts.method||'POST';
 const headers={'apikey':KEY,'Authorization':'Bearer '+session.access_token};
 let body;
 if(opts.blob){headers['Content-Type']='image/webp';headers['cache-control']='3600';headers['x-upsert']='false';body=opts.blob;}
 else if(opts.body!==undefined){headers['Content-Type']='application/json';body=JSON.stringify(opts.body);}
 const response=await fetch(API+path,{method,headers,body});
 if(response.status===401&&!retried){await refreshToken();return authed(path,opts,true);}
 const data=await response.json().catch(()=>({}));
 throwFor(response,data);return data;
}
function sessionExpiry(){
 if(!session)return 0;
 if(session.expires_at)return session.expires_at*1000;
 return session._obtainedAt+(session.expires_in||3600)*1000;
}
function setSession(s){
 if(!s?.access_token||!s?.refresh_token)throw Error('لم يتم التحقق من جلسة الدخول');
 session=Object.assign({},s,{_obtainedAt:Date.now()});
}
const rpc=(name,body={})=>authed('/rest/v1/rpc/'+name,{body});
const signed=()=>!!session&&!!rights;
const isChief=()=>rights?.isOwner===true||rights?.isMainPartner===true;
const canReports=()=>isChief()||rights?.canReadReports===true;
const canCatalogs=()=>isChief()||rights?.canManageCatalogs===true;
window.TotiAdminManagement?.configure({rpc,rights:()=>rights,current:()=>current,toast});
function allowed(id){
 if(!rights)return false;
 if(id==='banners'||id==='treasury'||id==='team'||id==='settings'||id==='users'||id==='rooms')return isChief();
 if(id==='hosts')return rights.canManageHostAgencies===true;
 if(id==='recharge')return rights.canManageRechargeAgencies===true;
 if(id==='reports'||id==='overview')return canReports()||canCatalogs();
 if(id==='catalog'||id==='medals'||id==='vip')return canCatalogs();
 if(id==='support')return rights.canSupport===true;
 return isChief()||['admin','super_admin'].includes(rights.role);
}
function showGuest(){
 epoch++;rights=null;session=null;$('#auth-screen').classList.remove('hidden');$('#dashboard').classList.add('hidden');$('#dashboard').classList.remove('nav-open');
}
async function establish(s){
 setSession(s);let r;
 try{r=await rpc('phase3_admin_session',{});}
 catch(e){session=null;throw Error('تعذر التحقق من صلاحية الإدارة: '+e.message);}
 if(!r||typeof r!=='object'||typeof r.role!=='string')throw Error('استجابة الصلاحيات غير صالحة');
 let canSupport=false;
 try{const supportStatus=await rpc('phase6_admin_support_access',{});canSupport=supportStatus?.canHandle===true;}catch(_){canSupport=false;}
 if(!(r.isOwner===true||r.isMainPartner===true||['admin','super_admin','db'].includes(r.role)||r.canManageCatalogs===true||r.canReadReports===true||canSupport)){
  session=null;throw Error('هذا الحساب لا يمتلك صلاحية الدخول إلى لوحة الإدارة');
 }
 rights={...r,canSupport};epoch++;
 $('#auth-screen').classList.add('hidden');$('#dashboard').classList.remove('hidden');
 $('#account-role').textContent=r.isOwner?'المالك الرئيسي':r.isMainPartner?'الشريك الرئيسي':r.role;
 $('#account-email').textContent=s.user?.email||$('#email').value||'حساب موثّق';
 buildNav();const firstAllowed=nav.find(item=>allowed(item[0]))?.[0];
 if(!firstAllowed){showGuest();throw Error('لا يوجد قسم مصرح به لهذا الحساب');}
 const requested=location.hash.slice(2);
 navigate(allowed(requested)?requested:firstAllowed);
}
async function signOut(){
 const access=session?.access_token;showGuest();setError('');
 if(access){fetch(API+'/auth/v1/logout',{method:'POST',headers:{apikey:KEY,Authorization:'Bearer '+access}}).catch(()=>{});}
}
function toBase64Url(bytes){
 let raw='';bytes.forEach(b=>raw+=String.fromCharCode(b));
 return btoa(raw).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}
async function oauthStart(){
 const bytes=crypto.getRandomValues(new Uint8Array(48));
 const verifier=toBase64Url(bytes);
 sessionStorage.setItem('tc_dashboard_pkce',verifier);
 const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier));
 const challenge=toBase64Url(new Uint8Array(digest));
 const redirect=location.origin+location.pathname;
 const url=new URL(API+'/auth/v1/authorize');
 url.searchParams.set('provider','github');
 url.searchParams.set('redirect_to',redirect);
 url.searchParams.set('code_challenge',challenge);
 url.searchParams.set('code_challenge_method','s256');
 location.assign(url.toString());
}
async function oauthFinish(){
 const query=new URLSearchParams(location.search),code=query.get('code'),failure=query.get('error_description');
 if(!code&&!failure)return;
 history.replaceState({},'',location.pathname+location.hash);
 if(failure){setError(failure);return;}
 const verifier=sessionStorage.getItem('tc_dashboard_pkce');
 sessionStorage.removeItem('tc_dashboard_pkce');
 if(!verifier){setError('جلسة تسجيل الدخول غير مكتملة. حاول مرة ثانية.');return;}
 try{
  const data=await publicFetch('/auth/v1/token?grant_type=pkce',{auth_code:code,code_verifier:verifier});
  await establish(data);
 }catch(e){showGuest();setError(e.message);}
}
function buildNav(){
 const container=$('#side-nav');container.replaceChildren();let group='';
 nav.filter(item=>allowed(item[0])).forEach(item=>{
  if(item[2]!==group){group=item[2];const h=document.createElement('div');h.className='nav-heading';h.textContent=group;container.append(h);}
  const b=document.createElement('button');b.type='button';b.className='nav-link';b.dataset.route=item[0];
  const ico=document.createElement('span');ico.className='nav-icon';ico.innerHTML=svgIcon(item[0]);
  const name=document.createElement('span');name.textContent=item[1];
  b.append(ico,name);container.append(b);
 });
}
function setHeading(title,description,actions=''){
 $('#crumb').textContent=title;
 $('#page-heading').innerHTML='<div class="heading-row"><div><p class="eyebrow">TOTICHAT / ADMIN CONSOLE</p><h1>'+safe(title)+'</h1><p>'+safe(description)+'</p></div><div class="heading-actions"><span class="today">'+new Intl.DateTimeFormat('ar-IQ',{day:'numeric',month:'long',year:'numeric'}).format(new Date())+'</span>'+actions+'</div></div>';
}
function stateNote(text,failed=false){return '<div class="status-note'+(failed?' status-error':'')+'">'+safe(text)+'</div>';}
function empty(title,desc){return '<div class="empty-state"><span class="empty-symbol">▧</span><strong>'+safe(title)+'</strong><p>'+safe(desc)+'</p></div>';}
function loadingHtml(){return '<div class="surface pad">'+empty('جارٍ جلب البيانات الحقيقية','لا نعرض أرقاماً وهمية أثناء التحميل.')+'<div class="page-spinner" style="margin:-90px auto 90px"></div></div>';}
function navigate(route){
 if(!signed()||!allowed(route))return;
 current=route;history.replaceState({},'',location.pathname+'#/'+route);
 $('#dashboard').classList.remove('nav-open');
 document.querySelectorAll('.nav-link').forEach(b=>b.classList.toggle('active',b.dataset.route===route));
 $('#main').scrollTop=0;detailOffset=0;directoryOffset=0;directoryQuery='';
 const actions=route==='banners'?'<button class="btn btn-primary" data-action="new-banner">＋ إضافة بنر</button>':'';
 const subtitles={
 overview:'كل ما يهمك لإدارة TotiChat في مكان واحد — أرقام موثّقة فقط.',
 banners:'ارفع ونسّق صور البنرات الثابتة، وتحكم بوقت عرضها ومسار النقر.',
 users:'إدارة الحسابات والصلاحيات والتحقق من حالتها.',
 rooms:'مراقبة الغرف والإشراف والمخالفات.',
 hosts:'إدارة وكالات المضيفين ومراجعة تقارير الماس.',
 recharge:'متابعة طلبات الشحن ووكلاء الشحن.',
 treasury:'مطابقة القيود المالية الموثّقة دون تعديل الأرصدة.',
 vip:'التحقق من امتيازات VIP وحالة المستخدم.',
 medals:'قواعد المداليات والامتيازات الفعلية.',
 catalog:'كتالوج الهدايا ومتجر التطبيق.',
 support:'صندوق خدمة العملاء والطلبات.',
 reports:'تقارير الخزينة والمعاملات الحقيقية.',
 team:'إدارة الصلاحيات وتوزيع المسؤوليات.',
 settings:'حالة الربط والأمان وإعدادات البيئة.'
 };
 setHeading(names[route],subtitles[route],actions);
 const render={
 overview:overview,banners:bannersPage,users:usersPage,rooms:roomsPage,
 hosts:hostsPage,recharge:rechargePage,treasury:treasuryPage,
 vip:vipPage,medals:medalsPage,catalog:catalogPage,support:supportPage,
 reports:reportsPage,team:teamPage,settings:settingsPage
 };
 $('#page-body').innerHTML=loadingHtml();
 void Promise.resolve(render[route]()).catch(e=>{
  if(current===route)$('#page-body').innerHTML='<div class="surface pad">'+stateNote('تعذر جلب البيانات من Staging: '+e.message,true)+'</div>';
 });
}
function buildCard(label,val,icon,subtitle){
 return '<article class="surface metric-card"><div class="metric-icon">'+icon+'</div><label>'+safe(label)+'</label><strong>'+safe(val)+'</strong><small>'+safe(subtitle||'بيانات Staging الحقيقية')+'</small></article>';
}
async function readReport(offset=0){
 const to=new Date(),from=new Date(to.getTime()-30*86400000);
 return rpc('phase4_admin_report',{p_from:from.toISOString(),p_to:to.toISOString(),p_status:null,p_offset:offset,p_limit:50});
}
async function overview(){
 const stamp=epoch,route=current;
 let report=null,reportErr='',ban=null;
 try{if(canReports())report=await readReport();else reportErr='حسابك لا يملك صلاحية قراءة التقارير';}
 catch(e){reportErr=e.message;}
 try{if(isChief())ban=await rpc('phase6_admin_banner_list',{p_offset:0,p_limit:5});}catch(_){}
 if(stamp!==epoch||route!==current)return;
 const s=report?.summary||{};
 const nums=[
  ['المستخدمون',fmt(s.users),'♙','عدد الحسابات المسجلة'],
  ['إجمالي الكوينز',fmt(s.coins),'◇','الرصيد المسجل وليس الإيراد النقدي'],
  ['إجمالي الماس',fmt(s.diamonds),'◈','الرصيد المسجل للمستخدمين'],
  ['المعاملات بالشهر',fmt(report?.total),'▤','آخر 30 يوماً']
 ];
 let html='<div class="metric-grid">'+nums.map(x=>buildCard(...x)).join('')+'</div>';
 if(reportErr)html+=stateNote('تعذر قراءة إحصائيات الإدارة: '+reportErr,true);
 html+='<div class="section-grid"><section class="surface pad"><div class="surface-title"><h2>الوصول السريع</h2><p>الأقسام المتاحة حسب صلاحيتك</p></div><div class="quick-grid">'+
  [['banners','إدارة البنرات','الصور والجدولة'],['treasury','مطابقة السجلات','قيود المالية'],['hosts','وكالات المضيفين','التقارير الشهرية'],
   ['catalog','الكتالوجات','الهدايا والمتجر'],['reports','تقارير المعاملات','أرقام فعلية'],['team','الصلاحيات','توزيع المسؤوليات']]
 .filter(x=>allowed(x[0])).map(x=>'<button class="quick-link" data-route="'+x[0]+'"><span class="quick-ico">'+svgIcon(x[0])+'</span><span><strong>'+safe(x[1])+'</strong><small>'+safe(x[2])+'</small></span></button>').join('')+
  '</div></section><section class="surface pad"><div class="surface-title"><h2>حالة بيئة الإدارة</h2><p>وضع التشغيل الحالي</p></div><dl class="detail-list">'+
  '<div class="detail-row"><dt>البيئة</dt><dd>Supabase Staging</dd></div>'+
  '<div class="detail-row"><dt>الحساب</dt><dd>'+safe(rights.isOwner?'المالك الرئيسي':rights.isMainPartner?'الشريك الرئيسي':rights.role)+'</dd></div>'+
  '<div class="detail-row"><dt>البنرات المسجلة</dt><dd>'+fmt(ban?.total)+'</dd></div>'+
  '<div class="detail-row"><dt>حالة النشر</dt><dd>غير منشور</dd></div></dl></section></div>';
 html+='<div class="surface pad"><div class="surface-title"><h2>آخر المعاملات</h2><button class="text-button" data-route="reports">عرض التقارير ←</button></div>'+
  (Array.isArray(report?.rows)&&report.rows.length?table(['المعرّف','العملية','الحالة','التاريخ'],report.rows.slice(0,6).map(x=>[x.id,x.operation,x.status,x.created_at])):empty('لا توجد معاملات مؤكدة في الفترة','لا ننشئ معاملات أو أرصدة افتراضية لملء اللوحة.'))+'</div>';
 $('#page-body').innerHTML=html;
}
function table(head,rows){
 return '<div class="table-wrap"><table class="data-table"><thead><tr>'+head.map(x=>'<th>'+safe(x)+'</th>').join('')+'</tr></thead><tbody>'+
 rows.map(r=>'<tr>'+r.map(x=>'<td>'+safe(x)+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>';
}
async function bannersPage(){
 if(!isChief())throw Error('تتطلب إدارة البنرات صلاحية المالك أو الشريك الرئيسي.');
 const stamp=epoch,route=current;
 const result=await rpc('phase6_admin_banner_list',{p_offset:bannerOffset,p_limit:30});
 if(stamp!==epoch||route!==current)return;
 if(!Array.isArray(result.rows)||!Number.isSafeInteger(result.total))throw Error('نتيجة البنرات غير صالحة');
 banners=result.rows;bannerTotal=result.total;
 const published=banners.filter(x=>x.status==='published').length;
 let html='<section class="banner-intro"><div><p class="eyebrow">BANNER STUDIO</p><h2>مساحة إبداعية. بدون هدر في التخزين.</h2><p>الصور الثابتة فقط. نقبل JPG وPNG وWebP ثم نحولها تلقائياً إلى WebP مضغوط بحجم لا يتجاوز 500KB. لا GIF ولا فيديو.</p></div><div class="banner-graphic"><span>▧ ✦ ▧</span></div></section>';
 html+='<div class="control-strip"><div class="search-field">⌕ <input type="search" id="banner-search" placeholder="بحث عن بنر..." aria-label="بحث عن بنر"></div><div class="muted">إجمالي '+fmt(bannerTotal)+' بنر · '+fmt(published)+' منشور في هذه الصفحة</div></div>';
 html+='<section class="surface"><div class="table-wrap"><table class="data-table"><thead><tr><th>البنر</th><th>الحالة</th><th>الترتيب</th><th>الوجهة</th><th>الجدولة</th><th>الإجراءات</th></tr></thead><tbody id="banner-rows">'+
  banners.map(b=>bannerRow(b)).join('')+'</tbody></table></div>'+
  (!banners.length?empty('لا توجد بنرات محفوظة','ارفع أول صورة بنر من زر إضافة بنر في الأعلى.'):'')+
  '</section><div class="control-strip" style="margin-top:15px"><span class="muted">صفحة '+(1+Math.floor(bannerOffset/30))+'</span><div><button class="btn btn-secondary" data-action="banner-prev" '+(bannerOffset===0?'disabled':'')+'>السابق</button> <button class="btn btn-secondary" data-action="banner-next" '+(bannerOffset+30>=bannerTotal?'disabled':'')+'>التالي</button></div></div>';
 $('#page-body').innerHTML=html;
}
function bannerRow(b){
 const status={'published':'منشور','draft':'مسودة','archived':'مؤرشف'}[b.status]||'غير معروف';
 const url=typeof b.image_url==='string'&&b.image_url.startsWith(API+'/storage/v1/object/public/'+BUCKET+'/')?safe(b.image_url):'';
 const kind=b.link_kind==='screen'?(b.link_target||'شاشة'): 'بدون رابط';
 const period=(b.starts_at?new Date(b.starts_at).toLocaleDateString('ar-IQ'):'فوري')+' ← '+(b.ends_at?new Date(b.ends_at).toLocaleDateString('ar-IQ'):'مستمر');
 return '<tr data-banner-name="'+safe(String(b.title).toLowerCase())+'"><td><div class="banner-cell">'+(url?'<img src="'+url+'" class="thumb" loading="lazy" alt="">':'<div class="thumb"></div>')+
 '<span><strong>'+safe(b.title)+'</strong><small class="mono">'+safe(b.id.slice(0,8))+'</small></span></div></td><td><span class="tag tag-'+safe(b.status)+'">'+safe(status)+'</span></td><td>'+safe(b.sort_order)+'</td><td>'+safe(kind)+'</td><td>'+safe(period)+'</td>'+
 '<td><button class="text-button" data-action="edit-banner" data-id="'+safe(b.id)+'">تعديل</button>'+
 (b.status==='published'?'<button class="text-button" data-action="archive-banner" data-id="'+safe(b.id)+'">إيقاف</button>':
 '<button class="text-button" data-action="publish-banner" data-id="'+safe(b.id)+'">نشر</button>')+
 '<button class="text-button danger" data-action="delete-banner" data-id="'+safe(b.id)+'">حذف</button></td></tr>';
}
function blobPreview(blob){
 if(previewUrl)URL.revokeObjectURL(previewUrl);
 previewUrl=URL.createObjectURL(blob);
 $('#banner-preview').innerHTML='<img src="'+safe(previewUrl)+'" alt="معاينة قص البنر قبل الرفع">';
}
async function optimizeImage(file){
 if(!file||!['image/png','image/jpeg','image/webp'].includes(file.type))throw Error('اختر JPG أو PNG أو WebP فقط. الصور المتحركة مرفوضة.');
 if(file.size>20*1024*1024)throw Error('الصورة الأصلية أكبر من 20MB');
 const bitmap=await createImageBitmap(file);
 if(bitmap.width<400||bitmap.height<150){bitmap.close();throw Error('أبعاد الصورة صغيرة جداً');}
 try{
  let width=1440;
  for(let scale=0;scale<5;scale++,width=Math.round(width*.8)){
   const height=Math.round(width/3),canvas=document.createElement('canvas');
   canvas.width=width;canvas.height=height;
   const ctx=canvas.getContext('2d');if(!ctx)throw Error('معالجة الصور غير مدعومة في الجهاز');
   const sourceAspect=bitmap.width/bitmap.height;
   let sx=0,sy=0,sw=bitmap.width,sh=bitmap.height;
   if(sourceAspect>3){sw=bitmap.height*3;sx=(bitmap.width-sw)/2;}
   else{sh=bitmap.width/3;sy=(bitmap.height-sh)/2;}
   ctx.drawImage(bitmap,sx,sy,sw,sh,0,0,width,height);
   for(const quality of [.86,.73,.61,.49,.39]){
    const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',quality));
    if(blob?.type==='image/webp'&&blob.size>0&&blob.size<=512000)return blob;
   }
  }
  throw Error('لم نتمكن من ضغط الصورة إلى 500KB بجودة مقبولة.');
 }finally{bitmap.close();}
}
function originalPath(b){
 const base=API+'/storage/v1/object/public/'+BUCKET+'/';
 if(!b?.image_url?.startsWith(base))return null;
 const path=b.image_url.slice(base.length);
 return /^[0-9a-f-]{36}\/[0-9a-f-]{36}\.webp$/i.test(path)?path:null;
}
function previewReset(){
 if(previewUrl)URL.revokeObjectURL(previewUrl);
 previewUrl=null;previewBlob=null;$('#banner-preview').innerHTML='<span>المعاينة تظهر هنا بعد اختيار صورة</span>';
}
function openBanner(id=null){
 const form=$('#banner-form');form.reset();previewReset();editingId=id;
 const b=id?banners.find(x=>x.id===id):null;
 if(id&&!b){toast('البنر غير موجود في الصفحة الحالية',true);return;}
 $('#banner-dialog-title').textContent=b?'تعديل البنر':'إضافة بنر جديد';
 $('#banner-form-message').textContent='';
 if(b){
  $('#banner-title').value=b.title;$('#banner-status').value=b.status;
  $('#banner-order').value=b.sort_order;$('#banner-link-kind').value=b.link_kind;
  $('#banner-link-target').value=b.link_target||'';
  $('#banner-starts').value=toLocalInput(b.starts_at);
  $('#banner-ends').value=toLocalInput(b.ends_at);
  const url=originalPath(b)?safe(b.image_url):'';
  $('#banner-preview').innerHTML=url?'<img src="'+url+'" alt="البنر الحالي">':'<span>الصورة الحالية غير صالحة</span>';
 }
 $('#banner-dialog').showModal();
}
function toLocalInput(t){
 if(!t)return '';
 const d=new Date(t);if(!Number.isFinite(d.getTime()))return '';
 const local=new Date(d.getTime()-d.getTimezoneOffset()*60000);
 return local.toISOString().slice(0,16);
}
function toIso(t){if(!t)return null;const d=new Date(t);if(!Number.isFinite(d.getTime()))throw Error('وقت غير صحيح');return d.toISOString();}
async function uploadBanner(blob){
 if(!session?.user?.id)throw Error('يجب التحقق من هوية الحساب لرفع البنر');
 const uid=session.user.id;
 if(!/^[0-9a-f-]{36}$/i.test(uid))throw Error('معرّف المستخدم غير صالح');
 const path=uid+'/'+crypto.randomUUID()+'.webp';
 await authed('/storage/v1/object/'+BUCKET+'/'+path,{blob});
 return path;
}
async function cleanupUnusedImage(path){
 if(!path||!/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.webp$/i.test(path))return false;
 await authed('/storage/v1/object/'+BUCKET,{method:'DELETE',body:{prefixes:[path]}});
 return true;
}
async function saveBanner(event){
 event.preventDefault();if(writeBusy)return;
 const form=$('#banner-form'),vals=new FormData(form);
 const b=editingId?banners.find(x=>x.id===editingId):null;
 if(editingId&&!b){$('#banner-form-message').textContent='اختفى البنر من الصفحة';return;}
 const title=String(vals.get('title')||'').trim(),sort=Number(vals.get('sort_order'));
 const kind=String(vals.get('link_kind')||'none'),target=kind==='screen'?String(vals.get('link_target')||''):null;
 const status=String(vals.get('status')||'draft');
 if(!title||title.length>120||!Number.isSafeInteger(sort)||sort<0||sort>10000||
   (kind==='screen'&&!target)){ $('#banner-form-message').textContent='أكمل الحقول بشكل صحيح';return;}
 let path=originalPath(b),newPath=null;
 const payload={title,image_path:path,link_kind:kind,link_target:target,
  status,sort_order:sort,starts_at:toIso(vals.get('starts_at')),ends_at:toIso(vals.get('ends_at'))};
 if(payload.starts_at&&payload.ends_at&&payload.starts_at>=payload.ends_at){
  $('#banner-form-message').textContent='تاريخ النهاية يجب أن يلي البداية';return;
 }
 if(!previewBlob&&!path){$('#banner-form-message').textContent='اختر صورة بنر أولاً';return;}
 writeBusy=true;$('#save-banner').disabled=true;
 $('#banner-form-message').textContent='جارٍ حفظ البنر الحقيقي…';
 try{
  if(previewBlob){newPath=await uploadBanner(previewBlob);payload.image_path=newPath;}
  const response=await rpc('phase6_admin_banner_action',{p_action:b?'update':'create',
    p_id:b?b.id:null,p_data:payload,p_request_id:crypto.randomUUID()});
  if(!response?.id)throw Error('لم يؤكد الخادم حفظ البنر');
  $('#banner-dialog').close();previewReset();
  let oldCleanupError='';
  if(newPath&&path&&path!==newPath){
   try{await cleanupUnusedImage(path);}catch(error){oldCleanupError=error.message;}
  }
  toast(oldCleanupError?'تم حفظ البنر، لكن تنظيف صورته السابقة يحتاج مراجعة.':'تم حفظ البنر بنجاح على Staging',!!oldCleanupError);
  await bannersPage();
 }catch(e){$('#banner-form-message').textContent='تعذر الحفظ: '+e.message;
  if(newPath){try{await cleanupUnusedImage(newPath);}catch(_){toast('قد توجد صورة جديدة غير مرتبطة تحتاج تنظيفاً إدارياً.',true);}}
 }finally{writeBusy=false;$('#save-banner').disabled=false;}
}
async function quickBanner(id,action){
 if(writeBusy)return;
 const b=banners.find(x=>x.id===id);if(!b)return;
 if(action==='delete'&&b.status==='published'){toast('أوقف البنر أولاً قبل حذفه',true);return;}
 if(!confirm(action==='delete'?'حذف البنر نهائياً من القائمة؟ الصورة تبقى لحين تنظيف التخزين.':'تأكيد تغيير حالة ظهور البنر؟'))return;
 const path=originalPath(b);if(!path){toast('مسار صورة البنر غير صالح',true);return;}
 const data=action==='delete'?{}:{title:b.title,image_path:path,link_kind:b.link_kind,
  link_target:b.link_target,status:action==='publish'?'published':'archived',
  sort_order:b.sort_order,starts_at:b.starts_at,ends_at:b.ends_at};
 writeBusy=true;
 try{
  const r=await rpc('phase6_admin_banner_action',{p_action:action==='delete'?'delete':'update',
   p_id:id,p_data:data,p_request_id:crypto.randomUUID()});
  if(!r?.id)throw Error('لم يؤكد الخادم العملية');
  let cleanupFailure=false;
  if(action==='delete'){
   try{await cleanupUnusedImage(path);}catch(_){cleanupFailure=true;}
  }
  toast(cleanupFailure?'تم حذف البنر، لكن الصورة تحتاج تنظيفاً لاحقاً.':'تم تسجيل تغيير البنر',cleanupFailure);
  await bannersPage();
 }catch(e){toast('تعذّر تغيير البنر: '+e.message,true);}finally{writeBusy=false;}
}
async function reportSection(){
 const r=await readReport(detailOffset);
 if(!Array.isArray(r.rows))throw Error('تقرير غير صالح');
 return '<div class="surface pad"><div class="surface-title"><h2>الملخص الحقيقي لآخر 30 يوم</h2><p>من Supabase Staging</p></div>'+
 '<div class="metric-grid">'+[
  ['المستخدمون',fmt(r.summary?.users),'♙','إجمالي الحسابات'],
  ['هدايا الفترة',fmt(r.summary?.gift_count),'✧','هدايا موثّقة'],
  ['مبلغ الهدايا',fmt(r.summary?.gift_amount),'◇','قيمة مسجّلة'],
  ['المعاملات',fmt(r.total),'▤','آخر 30 يوماً']
 ].map(x=>buildCard(...x)).join('')+'</div>'+
 (r.rows.length?table(['العملية','الحالة','التاريخ','المرجع'],r.rows.map(x=>[x.operation,x.status,x.created_at,x.id])):
 empty('لا توجد معاملات ضمن الفترة','هذا فراغ حقيقي ببيئة الاختبار، وليس فشلاً في الواجهة.'))+
 '<div class="control-strip" style="margin-top:15px"><button class="btn btn-secondary" data-action="report-prev" '+(detailOffset===0?'disabled':'')+'>السابق</button><button class="btn btn-secondary" data-action="report-next" '+(detailOffset+50>=r.total?'disabled':'')+'>التالي</button></div></div>';
}
async function reportsPage(){if(!canReports())throw Error('لا تملك صلاحية التقارير');const content=await reportSection();if(current==='reports')$('#page-body').innerHTML=content;}
async function treasuryPage(){
 const result=await rpc('phase5_finance_integrity_preflight',{});
 if(current!=='treasury')return;
 if(result.isReadOnly!==true)throw Error('تقرير غير قرائي');
 const keys=[['giftEventsChecked','الهدايا المفحوصة'],['giftIntegrityIssues','اختلافات الهدايا'],['redemptionsChecked','تحويلات الماس'],['redemptionIntegrityIssues','اختلافات التحويلات'],['walletsChecked','المحافظ المفحوصة'],['walletsNeedingDiamondReconciliation','محافظ تحتاج مطابقة']];
 let html='<div class="metric-grid">'+keys.slice(0,4).map(x=>buildCard(x[1],fmt(result[x[0]]),'▤','فحص قرائي فقط')).join('')+'</div>';
 html+='<div class="surface pad"><div class="surface-title"><h2>نتيجة المطابقة</h2><span class="tag tag-draft">للمراجعة فقط</span></div>';
 html+='<dl class="detail-list">'+keys.slice(4).map(x=>'<div class="detail-row"><dt>'+x[1]+'</dt><dd>'+fmt(result[x[0]])+'</dd></div>').join('')+'</dl>';
 html+=stateNote('لا يتم صرف رواتب أو تحويل عملات أو تصفير الماس من هذه الصفحة.')+'</div>';
 html+='<div class="surface pad" style="margin-top:18px"><div class="surface-title"><h2>تحديد العمليات المخالفة</h2></div><div class="admin-form-row"><label>نوع المخالفة<select id="audit-kind"><option value="gift">الهدايا</option><option value="redemption">تحويل الماس</option><option value="wallet">المحافظ</option></select></label><button class="btn btn-primary" data-action="load-issues">عرض المخالفات الفعلية</button></div><div id="audit-issues"></div></div>';
 $('#page-body').innerHTML=html;
}
async function fetchIssues(){
 const kind=$('#audit-kind')?.value;if(!['gift','redemption','wallet'].includes(kind))return;
 const holder=$('#audit-issues');holder.innerHTML=loadingHtml();
 try{
  const r=await rpc('phase5_finance_integrity_issues',{p_kind:kind,p_limit:25,p_offset:0});
  if(r.isReadOnly!==true||!Array.isArray(r.items))throw Error('فشل توثيق تفاصيل الخلل');
  holder.innerHTML=r.items.length?table(['مرجع','تفاصيل مثبتة من الخادم'],
   r.items.map(x=>[x.operation_id||x.user_id||'—',JSON.stringify(x).slice(0,600)])):
   empty('لا توجد اختلافات في الفحص','إذا ظهرت مشكلة مستقبلاً فستظهر هنا من الخادم.');
 }catch(e){holder.innerHTML=stateNote('تعذر قراءة التفاصيل: '+e.message,true);}
}
async function liveObject(name,params={}){
 const data=await rpc(name,params);
 if(current!==liveObject.route)return;
 return data;
}
function prettyData(data){
 if(data===null||data===undefined)return empty('لا توجد بيانات','استجابة الخادم فارغة.');
 const item=Array.isArray(data)?data:typeof data==='object'?Object.entries(data):[['القيمة',String(data)]];
 const rows=Array.isArray(data)&&data.length&&typeof data[0]==='object'?data.map(x=>[JSON.stringify(x).slice(0,350)]):item.map(([k,v])=>[k,typeof v==='object'?JSON.stringify(v).slice(0,500):String(v)]);
 return table(Array.isArray(data)&&data.length&&typeof data[0]==='object'?['البيانات القادمة من الخادم']:['الحقل','القيمة'],rows.slice(0,60));
}
async function simpleModule(route,rpcName,body,warning){
 const data=await rpc(rpcName,body);
 if(current!==route)return;
 $('#page-body').innerHTML='<div class="surface pad"><div class="surface-title"><h2>البيانات المرتبطة بالنظام</h2><p>قراءة من Staging</p></div>'+prettyData(data)+
 (warning?'<div class="admin-alert">'+safe(warning)+'</div>':'')+'</div>';
}
async function hostsPage(){return window.TotiAdminManagement.agencies('host');}
async function rechargePage(){return window.TotiAdminManagement.agencies('recharge');}
async function supportPage(){return window.TotiAdminManagement.support();}
async function catalogPage(){
 const key='gift_catalog';
 const data=await rpc('phase3_catalog_list',{p_table:key,p_offset:0,p_limit:50});
 if(current!=='catalog')return;
 if(!Array.isArray(data.rows))throw Error('بيانات كتالوج غير صالحة');
 $('#page-body').innerHTML='<div class="surface pad"><div class="surface-title"><h2>كتالوج الهدايا الحقيقي</h2><p>'+fmt(data.total)+' عنصر · عرض أول 50</p></div>'+
 (data.rows.length?table(['المعرّف','الاسم','السعر','الحالة'],
 data.rows.map(x=>[x.id,x.name,x.price,x.is_active?'فعّال':'متوقف'])):
 empty('الكتالوج فارغ حالياً','لا يتم اختراع هدايا للعرض.'))+
 '<div class="admin-alert">تعديل الكتالوجات الحساسة سيتطلب تدقيق نماذج الإدخال والصلاحيات قبل تفعيل أدوات الكتابة في الموقع.</div></div>';
}
async function vipPage(){return window.TotiAdminManagement.vip();}
async function medalsPage(){return window.TotiAdminManagement.medals();}
function notConnected(name,needed){
 $('#page-body').innerHTML='<div class="surface pad">'+empty('هيكل '+name+' مجهّز',
  'لم نربط إجراء كتابة أو قراءة إدارية لهذا القسم بعد، ولن نستخدم بيانات وهمية أو نعطي صلاحيات غير موجودة.')+
  '<div class="admin-alert">المطلوب للربط: '+safe(needed)+'</div></div>';
}
async function directoryPage(kind){
 const route=current,stamp=epoch;
 if(!isChief())throw Error('مراجعة قائمة المستخدمين والغرف تتطلب المالك أو الشريك الرئيسي.');
 const result=await rpc('phase6_admin_directory',{p_kind:kind,p_query:directoryQuery,
  p_offset:directoryOffset,p_limit:30});
 if(stamp!==epoch||route!==current)return;
 if(result?.readOnly!==true||result.kind!==kind||!Array.isArray(result.rows)||
   !Number.isSafeInteger(result.total))throw Error('استجابة الدليل غير صالحة');
 let html='<section class="surface pad"><div class="surface-title"><h2>'+
  (kind==='users'?'سجل الحسابات الفعلية':'دليل الغرف المسجلة')+'</h2>'+
  '<p>'+fmt(result.total)+' سجل</p></div>'+
  '<div class="control-strip"><form id="directory-search-form" class="admin-form-row">'+
  '<label>البحث بالاسم<input id="directory-search" type="search" maxlength="60" value="'+safe(directoryQuery)+'" placeholder="ابحث في '+(kind==='users'?'المستخدمين':'الغرف')+'"></label>'+
  '<button class="btn btn-primary" type="submit">بحث</button></form></div>';
 if(kind==='users'){
  html+=result.rows.length?table(['المستخدم','المعرّف','تاريخ الإنشاء'],
    result.rows.map(x=>[x.display_name,x.id,new Date(x.created_at).toLocaleDateString('ar-IQ')])):
   empty('لا يوجد حساب مطابق','قاعدة البيانات لم تُرجع مستخدمين لهذا البحث.');
 }else{
  html+=result.rows.length?table(['الغرفة','المالك','الخصوصية','سجلات العضوية','تاريخ الإنشاء'],
   result.rows.map(x=>[x.title,x.owner_id,x.is_private?'خاصة':'عامة',
    fmt(x.member_records),new Date(x.created_at).toLocaleDateString('ar-IQ')])):
   empty('لا توجد غرف مطابقة','لا نعرض غرفاً أو مستخدمين وهميين.');
 }
 html+='<div class="control-strip" style="margin-top:16px"><div>'+
  '<button class="btn btn-secondary" data-action="dir-prev" '+(directoryOffset===0?'disabled':'')+'>السابق</button> '+
  '<button class="btn btn-secondary" data-action="dir-next" '+(directoryOffset+30>=result.total?'disabled':'')+'>التالي</button></div>'+
  '<span class="muted">صفحة '+(1+Math.floor(directoryOffset/30))+'</span></div>'+
  '<div class="admin-alert">هذه قائمة إدارية للقراءة فقط. إجراءات الحظر والطرد والتوثيق تُفعّل بعد تدقيق الصلاحيات والتسجيل الأمني.</div></section>';
 $('#page-body').innerHTML=html;
}
async function usersPage(){await directoryPage('users');}
async function roomsPage(){await directoryPage('rooms');}
async function teamPage(){return window.TotiAdminManagement.team();}
async function settingsPage(){
 $('#page-body').innerHTML='<div class="surface pad"><div class="surface-title"><h2>الربط والأمان</h2></div><dl class="detail-list">'+
 [['Supabase Project','rziaedugbdwefbefcxjt'],['Environment','Staging — لا إنتاج'],['مصدر الصلاحيات','phase3_admin_session RPC'],['خزن البنرات','totichat-admin-banners (WebP ≤ 500KB)'],['جلسات الإدارة','تبقى بالذاكرة فقط وتُفقد عند تحديث الصفحة'],['البناء والنشر','غير منفذ']].map(x=>'<div class="detail-row"><dt>'+safe(x[0])+'</dt><dd>'+safe(x[1])+'</dd></div>').join('')+
 '</dl><div class="admin-alert">أي إعدادات OAuth redirect على النطاق النهائي تتطلب إدراج الرابط لدى Supabase Auth قبل تسجيل دخول GitHub من الموقع المستقل.</div></div>';
}
document.addEventListener('click',async event=>{
 const route=event.target.closest('[data-route]');
 if(route){navigate(route.dataset.route);return;}
 const button=event.target.closest('[data-action]');
 if(!button)return;
 const action=button.dataset.action,id=button.dataset.id||null;
 try{
  if(action==='new-banner')openBanner();
  if(action==='edit-banner')openBanner(id);
  if(['archive-banner','publish-banner','delete-banner'].includes(action))await quickBanner(id,action.replace('-banner',''));
  if(action==='banner-next'){bannerOffset+=30;await bannersPage();}
  if(action==='banner-prev'){bannerOffset=Math.max(0,bannerOffset-30);await bannersPage();}
  if(action==='report-next'){detailOffset+=50;await reportsPage();}
  if(action==='report-prev'){detailOffset=Math.max(0,detailOffset-50);await reportsPage();}
  if(action==='load-issues')await fetchIssues();
  if(action==='dir-next'){directoryOffset+=30;await directoryPage(current==='users'?'users':'rooms');}
  if(action==='dir-prev'){directoryOffset=Math.max(0,directoryOffset-30);await directoryPage(current==='users'?'users':'rooms');}
 }catch(e){toast(e.message,true);}
});
$('#login-form').addEventListener('submit',async e=>{
 e.preventDefault();const button=$('#login-submit');button.disabled=true;setError('جارٍ التحقق من الحساب والصلاحيات…');
 try{
  const vals=new FormData(e.target);
  const data=await publicFetch('/auth/v1/token?grant_type=password',{
   email:String(vals.get('email')),password:String(vals.get('password'))});
  await establish(data);setError('');
 }catch(error){showGuest();setError(error.message);}
 finally{button.disabled=false;}
});
$('#github-login').addEventListener('click',()=>oauthStart().catch(e=>setError(e.message)));
$('#logout').addEventListener('click',()=>void signOut());
$('#refresh-btn').addEventListener('click',()=>{if(signed())navigate(current);});
$('#menu-toggle').addEventListener('click',()=>$('#dashboard').classList.toggle('nav-open'));
$('#sidebar-backdrop').addEventListener('click',()=>$('#dashboard').classList.remove('nav-open'));
$('#close-banner').addEventListener('click',()=>$('#banner-dialog').close());
$('#cancel-banner').addEventListener('click',()=>$('#banner-dialog').close());
$('#banner-image').addEventListener('change',async e=>{
 const file=e.target.files[0];previewReset();
 if(!file)return;
 $('#banner-form-message').textContent='جارٍ ضغط الصورة…';
 try{
  previewBlob=await optimizeImage(file);
  blobPreview(previewBlob);
  $('#banner-form-message').textContent='حجم WebP النهائي: '+Math.ceil(previewBlob.size/1024)+'KB';
 }catch(err){previewReset();e.target.value='';$('#banner-form-message').textContent=err.message;}
});
$('#banner-form').addEventListener('submit',e=>void saveBanner(e));
$('#banner-dialog').addEventListener('close',()=>previewReset());
$('#banner-link-kind').addEventListener('change',()=>{
 const screen=$('#banner-link-kind').value==='screen';
 $('#banner-link-target').disabled=!screen;
 if(!screen)$('#banner-link-target').value='';
});
$('#page-body').addEventListener('input',e=>{
 if(e.target.id==='banner-search'){
  const query=e.target.value.trim().toLowerCase();
  document.querySelectorAll('#banner-rows tr').forEach(row=>{row.hidden=!row.dataset.bannerName.includes(query);});
 }
});
$('#page-body').addEventListener('submit',async e=>{
 if(e.target.id==='directory-search-form'){
  e.preventDefault();directoryQuery=$('#directory-search').value.trim();directoryOffset=0;
  void directoryPage(current==='users'?'users':'rooms').catch(err=>toast(err.message,true));return;
 }
 if(e.target.id!=='vip-lookup')return;
 e.preventDefault();const id=$('#vip-user').value.trim(),out=$('#vip-result');
 if(!/^[0-9a-f-]{36}$/i.test(id)){out.textContent='معرّف UUID غير صالح';return;}
 out.textContent='جارٍ قراءة الاستحقاق…';
 try{const data=await rpc('phase5_vip_status',{p_target:id});out.innerHTML=prettyData(data);}
 catch(err){out.textContent='فشل التحقق: '+err.message;}
});
window.addEventListener('hashchange',()=>{if(signed()){const page=location.hash.slice(2);if(allowed(page))navigate(page);}});
window.addEventListener('beforeunload',()=>{if(previewUrl)URL.revokeObjectURL(previewUrl);});
void oauthFinish();
})();
