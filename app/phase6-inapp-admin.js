/* TotiChat Phase 6 — authorized unified administration inside the ordinary app.
   Staging only. This module neither creates roles nor modifies the approved HTML.
   Every privileged query and action is independently authorized by server RPCs. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const qs=(s,root=document)=>root.querySelector(s);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const rpc=(name,body={})=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
const uid=()=>auth.state().signedIn?auth.state().user?.id||'':'';
const chief=r=>r?.isOwner===true||r?.isMainPartner===true;
const owner=r=>r?.isOwner===true;
const authorized=r=>!!r&&(chief(r)||['admin','super_admin','db'].includes(r.role)||
  r.canManageCatalogs===true||r.canReadReports===true||r.canSupport===true);
let rights=null,account='',serial=0,requestSerial=0,opened=false,view='overview',offset=0,search='',reading=false,mutation=false,pendingMutation=null;
const nav=[
 ['overview','الرئيسية','▦','home'],
 ['users','المستخدمون','♙','chief'],
 ['rooms','الغرف الصوتية','◉','chief'],
 ['staff','الموظفون والصلاحيات','♧','chief'],
 ['host_agencies','وكالات المضيفين','⌂','chief'],
 ['recharge_agencies','وكالات الشحن','◇','owner'],
 ['registrations','طلبات الوكالات','▣','chief'],
 ['agency_transfers','طلبات النقل','⇄','chief'],
 ['audit','سجل الإجراءات','☷','chief'],
 ['finance_integrity','مطابقة سجلات المالية','▥','chief'],
 ['host_month','مراجعة الماس الشهرية','◈','chief'],
 ['catalog','الهدايا والمتجر','✧','catalog'],
 ['reports','التقارير','▥','reports'],
 ['global_gift','إعلانات الهدايا','★','chief'],
 ['open_agency','فتح وكالة مضيفين','＋','db_open'],
 ['support','صندوق خدمة العملاء','☏','support'],
 ['vip','VIP والامتيازات','♛','owner'],
 ['medals','الميداليات والشارات','✿','owner'],
 ['special_id','المعرّف المميز','▧','owner'],
 ['banners','البنرات (قراءة)','▤','chief'],
 ['settlement','التسوية الشهرية','◈','chief_pending']
];
const actionMap={catalog:'data-admin-open',reports:'data-reports-open',global_gift:'data-tc-global-gift-admin',
 open_agency:'data-tc-host-approval',support:'data-support-open',
 finance_integrity:'data-finance-inspect',host_month:'data-tc-host-month',special_id:'data-tc-special-id-open'};
function can(key,r=rights){
 if(!authorized(r))return false;
 if(key==='home')return true;
 if(key==='chief'||key==='chief_pending')return chief(r);
 if(key==='owner'||key==='owner_pending')return owner(r);
 if(key==='catalog')return chief(r)||r.canManageCatalogs===true;
 if(key==='reports')return chief(r)||r.canReadReports===true;
 if(key==='support')return r.canSupport===true;
 if(key==='db_open')return r.role==='db'&&Array.isArray(r.permissions)&&r.permissions.includes('host_agency.open');
 return false;
}
function permitted(){return nav.filter(item=>can(item[3]));}
function readable(){return ['users','rooms','staff','host_agencies','recharge_agencies','registrations','agency_transfers','audit','banners'].includes(view);}
function validIdentity(n=account){return !!n&&uid()===n;}
function roleLabel(r){
 if(r?.isOwner)return 'المالك الرئيسي';
 if(r?.isMainPartner)return 'الشريك الرئيسي';
 return ({super_admin:'Super Admin',admin:'Admin',db:'DB',user:'موظف خدمة العملاء'})[r?.role]||'موظف إدارة';
}
function concealLegacyEntries(){
 // Scope consolidation ONLY to Profile rows; leave active modal controls intact.
 const panel=qs('#app .me-more');if(!panel)return;
 for(const n of panel.querySelectorAll('[data-finance-inspect],[data-tc-host-month],[data-tc-medal-owner],[data-tc-special-id-open],[data-admin-open],[data-reports-open],[data-tc-global-gift-admin],[data-tc-host-approval]'))n.remove();
}
function removeEntry(){qs('[data-tcac-entry]')?.remove();}
function exit(){
 opened=false;requestSerial++;
 qs('#tcac-root')?.remove();
 document.documentElement.classList.remove('tcac-open');
}
function clear(){
 serial++;account='';rights=null;mutation=false;pendingMutation=null;removeEntry();exit();
}
async function verify(){
 const id=uid(),stamp=++serial;
 if(!id){clear();return null;}
 const results=await Promise.allSettled([rpc('phase3_admin_session'),rpc('phase6_admin_support_access')]);
 if(stamp!==serial||uid()!==id)return null;
 const admin=results[0].status==='fulfilled'&&results[0].value&&typeof results[0].value==='object'
  ?results[0].value:null;
 const canSupport=results[1].status==='fulfilled'&&results[1].value?.canHandle===true;
 // An unavailable authority service cannot be treated as permission.
 if(!admin&&!canSupport){rights=null;removeEntry();exit();return null;}
 const role={...(admin||{role:'user',permissions:[]}),canSupport};
 rights=authorized(role)?role:null;
 account=id;
 if(!rights){removeEntry();exit();}
 return rights;
}
function row(){
 const b=document.createElement('button');b.type='button';b.className='tcac-entry';
 b.setAttribute('data-tcac-entry','');
 b.setAttribute('aria-label','الدخول إلى مركز الإدارة');
 const badge=document.createElement('span');badge.className='tcac-entry-icon';badge.textContent='◆';
 const label=document.createElement('span');label.className='tcac-entry-text';
 const title=document.createElement('b');title.textContent='مركز الإدارة';
 const desc=document.createElement('small');desc.textContent='لوحة التحكم الخاصة بالصلاحيات الممنوحة';
 label.append(title,desc);
 const arrow=document.createElement('span');arrow.className='tcac-entry-arrow';arrow.textContent='‹';
 b.append(badge,label,arrow);
 return b;
}
async function onProfile(){
 concealLegacyEntries();
 if(!uid()){clear();return;}
 const id=uid(),s=serial;
 // Called by the existing Profile render hook; avoid adding an admin entry on Home.
 if(typeof screen!=='string'||screen!=='me')return;
 if(!rights||account!==id){await verify();}
 else if(s!==serial)return;
 if(!validIdentity(id)||typeof screen!=='string'||screen!=='me')return;
 const panel=qs('#app .me-more');if(!panel)return;
 if(!rights){removeEntry();return;}
 if(!panel.querySelector('[data-tcac-entry]'))panel.appendChild(row());
}
function status(message){const n=qs('#tcac-status');if(n)n.textContent=message||'';}
function shell(){
 exit();opened=true;view='overview';offset=0;search='';
 const root=document.createElement('section');root.id='tcac-root';root.className='tcac-root';
 root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');
 root.setAttribute('aria-label','مركز الإدارة');
 root.dir='rtl';
 root.innerHTML='<div class="tcac-shell"><header class="tcac-header">'+
   '<button type="button" class="tcac-back" data-tcac="exit" aria-label="العودة إلى ملفي">➜</button>'+
   '<div class="tcac-brand"><b>TotiChat</b><small>مركز الإدارة</small></div>'+
   '<button class="tcac-refresh" type="button" data-tcac="refresh" aria-label="تحديث">⟳</button></header>'+
   '<section class="tcac-hero"><small>لوحة إدارة موحدة · بيانات حقيقية</small>'+
   '<h2 id="tcac-title">مرحباً بك في مركز الإدارة</h2>'+
   '<span id="tcac-role"></span></section>'+
   '<main id="tcac-content" class="tcac-content"></main>'+
   '<p id="tcac-status" class="tcac-status" role="status" aria-live="polite"></p>'+
   '<footer class="tcac-bottom">'+
   '<button type="button" data-tcac="home">الرئيسية</button>'+
   '<button type="button" data-tcac="modules">الأقسام</button>'+
   '<button type="button" data-tcac="exit">العودة إلى TotiChat</button>'+
   '</footer></div>';
 document.body.appendChild(root);
 document.documentElement.classList.add('tcac-open');
 qs('#tcac-role').textContent=roleLabel(rights);
 draw();
 qs('.tcac-back')?.focus();
}
function card(item){
 return '<button class="tcac-card" type="button" data-tcac-view="'+esc(item[0])+'">'+
 '<span class="tcac-icon" aria-hidden="true">'+esc(item[2])+'</span><b>'+esc(item[1])+'</b>'+
 '<small>'+(item[3].endsWith('pending')?'قيد استكمال الربط':'حسب صلاحيتك')+'</small></button>';
}
function draw(){
 const c=qs('#tcac-content');if(!c||!opened)return;
 const item=nav.find(x=>x[0]===view);
 qs('#tcac-title').textContent=view==='overview'?'مركز التحكم':item?.[1]||'مركز الإدارة';
 if(view==='overview'){
  c.innerHTML='<div class="tcac-notice">تظهر هنا فقط الأقسام التي منحك الخادم صلاحية الوصول إليها. لا تُعرض إحصائيات تجريبية.</div>'+
  '<h3>أقسامك</h3><div class="tcac-grid">'+permitted().filter(i=>i[0]!=='overview').map(card).join('')+'</div>'+
  '<div class="tcac-notice">الإجراءات الحساسة تتطلب تحققاً مستقلاً من الخادم، وليس مجرد ظهور الزر.</div>';
  if(permitted().length===1)c.innerHTML+='<p class="tcac-empty">هذا الحساب إداري، لكن لا توجد وظائف مفوّضة إضافية حالياً.</p>';
  status('تم التحقق من صلاحية حسابك.');
  return;
 }
 if(!item||!can(item[3])){view='overview';draw();return;}
 if(readable()){
  c.innerHTML='<form id="tcac-search" class="tcac-search" autocomplete="off">'+
   '<label for="tcac-query">البحث في السجلات</label>'+
   '<input id="tcac-query" name="query" maxlength="60" value="'+esc(search)+'" placeholder="اكتب الاسم (للمستخدمين والغرف)">'+
   '<button type="submit">بحث / تحديث</button></form>'+
   '<div id="tcac-data" role="region" aria-live="polite"></div>'+
   '<div class="tcac-pager"><button data-tcac="prev" type="button">السابق</button>'+
   '<span id="tcac-page">—</span><button type="button" data-tcac="next">التالي</button></div>';
  const inp=qs('#tcac-query');if(inp&&view!=='users'&&view!=='rooms'){inp.disabled=true;inp.placeholder='التصفية غير متاحة لهذا القسم';}
  void loadPage();
  return;
 }
 if(view==='vip'||view==='medals'){void entitlementScreen();return;}
 if(actionMap[view]){
  c.innerHTML='<div class="tcac-module"><h3>'+esc(item[1])+'</h3>'+
    '<p>يفتح هذا القسم الوظيفة الحقيقية الموجودة مسبقاً داخل TotiChat، باستخدام نفس جلسة تسجيل الدخول وصلاحيات الخادم.</p>'+
    '<button type="button" class="tcac-primary" data-tcac-run="'+esc(view)+'">فتح الوظيفة</button></div>';
  status('الوظيفة متصلة بالقسم الحالي حسب الصلاحيات.');
  return;
 }
 const reasons={vip:'تتوفر عمليات VIP في لوحة Staging المستقلة حالياً؛ يجري نقلها بأمان إلى التطبيق.',
 medals:'تتوفر إدارة الميداليات في اللوحة المستقلة؛ يحتاج دمجها داخل التطبيق إلى اختبار صلاحيات المالك.',
 banners:'إدارة البنرات المتصلة بالمخزن تحتاج نقل واجهتها مع التحقق من صلاحيات رفع الصور.',
 settlement:'التسوية المالية والدفع والتصفير غير مفعلة؛ الموجود مراجعة شهرية قرائية فقط.'};
 c.innerHTML='<div class="tcac-module"><h3>'+esc(item[1])+'</h3><p>'+
 esc(reasons[view]||'الوظيفة قيد الدمج ولا يوجد تنفيذ وهمي.')+'</p>'+
 '<p class="tcac-notice">لا توجد أزرار وهمية أو صلاحيات مفترضة.</p></div>';
 status('لا يمكن تنفيذ هذا القسم قبل استكمال الربط واختباره.');
}

function input(label,name,attributes=''){
 return '<label class="tcac-field">'+label+'<input name="'+name+'" '+attributes+'></label>';
}
function reasonInput(){
 return '<label class="tcac-field">سبب إداري موثّق<textarea name="reason" minlength="10" maxlength="300" required></textarea></label>';
}
function entitlementForm(){
 if(view==='vip'){
  return '<div class="tcac-module"><h3>التحقق من استحقاق VIP</h3>'+
   '<form id="tcac-vip-check">'+input('معرّف الحساب','target','required pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
   '<button class="tcac-primary" type="submit">عرض الحالة الفعلية</button></form>'+
   '<div id="tcac-vip-state" role="status"></div>'+
   '<h3>إجراء المالك الرئيسي</h3><form id="tcac-vip-write">'+
   input('معرّف المستفيد','target','required pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
   '<label class="tcac-field">الإجراء<select name="action"><option value="grant">منح VIP</option><option value="revoke">سحب VIP</option></select></label>'+
   input('مستوى VIP من 1 إلى 10','tier','type="number" min="1" max="10" value="1" required')+
   input('تاريخ انتهاء المنح (اختياري)','expires','type="datetime-local"')+
   reasonInput()+'<button class="tcac-primary" type="submit">تأكيد الإجراء</button></form>'+
   '<p class="tcac-notice">التعديلات موثقة في الخادم، ولا تمثل بيع VIP أو تحصيل أموال.</p></div>';
 }
 return '<div class="tcac-module"><h3>المداليات المسجلة</h3>'+
 '<div id="tcac-medal-catalog" role="status">جارٍ تحميل البيانات الفعلية…</div>'+
 '<h3>إدارة الميداليات — المالك فقط</h3><form id="tcac-medal-write">'+
 '<label class="tcac-field">الإجراء<select name="action"><option value="grant">منح مدالية</option><option value="revoke">سحب مدالية</option><option value="register">تسجيل مدالية جديدة</option></select></label>'+
 input('مفتاح المدالية','key','required pattern="[a-z][a-z0-9_-]{2,39}" maxlength="40"')+
 input('UUID المستفيد (عند المنح والسحب)','target','pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
 input('اسم المدالية الجديدة (عند التسجيل)','label','maxlength="60"')+
 input('الوصف (اختياري)','description','maxlength="180"')+
 reasonInput()+'<button class="tcac-primary" type="submit">حفظ القرار الموثق</button></form></div>';
}
async function entitlementScreen(){
 if(!opened||!owner(rights)||!['vip','medals'].includes(view))return;
 const current=view,id=uid(),stamp=++requestSerial;
 const place=qs('#tcac-content');
 if(!place)return;
 place.innerHTML=entitlementForm();
 if(current==='vip'){status('عرض البيانات الحقيقية وإجراء المالك فقط.');return;}
 try{
  const result=await rpc('phase5_medal_catalog');
  if(!opened||uid()!==id||view!==current||stamp!==requestSerial)return;
  const rows=Array.isArray(result)?result:Array.isArray(result?.medals)?result.medals:Array.isArray(result?.rows)?result.rows:null;
  if(!rows)throw Error('استجابة غير صالحة');
  const target=qs('#tcac-medal-catalog');
  if(target)target.innerHTML=rows.length?rows.map(m=>
   '<article class="tcac-record"><b>'+esc(m.display_name||m.label||m.medal_key||m.key)+'</b>'+
   '<p>'+esc(m.medal_key||m.key||'')+'</p></article>').join(''):
   '<p class="tcac-empty">لا توجد ميداليات موثقة بعد.</p>';
  status('سجلات المداليات من قاعدة Staging.');
 }catch(e){
  if(opened&&uid()===id&&view===current){const target=qs('#tcac-medal-catalog');if(target)target.textContent='خطأ قراءة: '+String(e.message).slice(0,180);}
 }
}
async function entitlementSubmit(form){
 if(mutation)return;
 const id=uid(),current=view,authz=await verify();
 if(!opened||!authz||!owner(authz)||uid()!==id||!['vip','medals'].includes(current))return;
 const data=new FormData(form),get=k=>String(data.get(k)||'').trim();
 const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
 const reason=get('reason'),key=get('key'),action=get('action');
 if(reason.length<10||reason.length>300)throw Error('السبب يجب أن يحتوي 10–300 حرف');
 let fn,params,signature,confirmation;
 if(form.id==='tcac-vip-check'){
  const user=get('target');if(!uuid.test(user))throw Error('UUID غير صالح');
  const result=await rpc('phase5_vip_status',{p_target:user});
  if(opened&&uid()===id&&view===current){
   const n=qs('#tcac-vip-state');if(n)n.textContent=result?.active?'VIP'+result.tier+' فعّال — ينتهي: '+(result.expiresAt||'غير محدد'):'لا يوجد VIP فعّال';
  }
  return;
 }
 if(form.id==='tcac-vip-write'){
  const user=get('target'),tier=Number(get('tier')),expires=get('expires');
  if(!uuid.test(user)||!['grant','revoke'].includes(action))throw Error('مدخلات VIP غير صالحة');
  if(action==='grant'&&(!Number.isInteger(tier)||tier<1||tier>10))throw Error('حدد مستوى VIP بين 1 و10');
  let expiration=null;
  if(action==='grant'&&expires){
   const dt=new Date(expires);if(!Number.isFinite(dt.getTime())||dt.getTime()<=Date.now())throw Error('انتهاء المنح يجب أن يكون في المستقبل');
   expiration=dt.toISOString();
  }
  fn='phase5_vip_owner_action';
  params={p_action:action,p_target:user,p_tier:action==='revoke'?0:tier,
   p_expires_at:expiration,p_reason:reason};
  confirmation='تأكيد '+(action==='grant'?'منح':'سحب')+' VIP لهذا الحساب؟';
 }else if(form.id==='tcac-medal-write'){
  if(!/^[a-z][a-z0-9_-]{2,39}$/.test(key)||!['grant','revoke','register'].includes(action))throw Error('مفتاح أو إجراء غير صالح');
  const target=get('target'),label=get('label');
  if(action!=='register'&&!uuid.test(target))throw Error('UUID المستفيد غير صالح');
  if(action==='register'&&(label.length<3||label.length>60))throw Error('اسم المدالية يجب أن يحتوي 3–60 حرف');
  fn='phase5_medal_owner_action';
  params={p_action:action,p_medal_key:key,p_target:action==='register'?null:target,
   p_label:action==='register'?label:null,p_description:action==='register'?get('description'):null,p_reason:reason};
  confirmation='تأكيد قرار المدالية وحفظه في سجل الأمان؟';
 }else return;
 signature=JSON.stringify([id,fn,params]);
 if(!pendingMutation||pendingMutation.signature!==signature)
  pendingMutation={signature,id:crypto.randomUUID()};
 if(!window.confirm(confirmation))return;
 const button=form.querySelector('button[type="submit"]');
 mutation=true;if(button)button.disabled=true;
 try{
  const result=await rpc(fn,{...params,p_request_id:pendingMutation.id});
  if(!result||typeof result!=='object')throw Error('الخادم لم يؤكد العملية');
  pendingMutation=null;
  if(opened&&uid()===id&&view===current){
   status('تم حفظ القرار الحقيقي في Supabase Staging.');
   if(current==='medals')void entitlementScreen();
  }
 }finally{
  mutation=false;
  if(button?.isConnected)button.disabled=false;
 }
}

async function loadPage(){
 if(!opened||!readable()||reading)return;
 const r=rights,item=nav.find(x=>x[0]===view);
 if(!r||!item||!can(item[3])){exit();return;}
 const id=uid(),start=++requestSerial,kind=view,p=offset;
 const node=qs('#tcac-data');if(!node)return;
 node.textContent='جارٍ تحميل السجلات الفعلية…';status('');
 reading=true;
 try{
  const directory=kind==='users'||kind==='rooms';
  const banner=kind==='banners';
  const result=await rpc(banner?'phase6_admin_banner_list':directory?'phase6_admin_directory':'phase6_admin_management_page',
    banner?{p_offset:p,p_limit:20}:directory?{p_kind:kind,p_query:search,p_offset:p,p_limit:20}:{p_kind:kind,p_offset:p,p_limit:20});
  if(!opened||start!==requestSerial||uid()!==id||view!==kind)return;
  if((!banner&&(result?.readOnly!==true||result?.kind!==kind))||!Array.isArray(result.rows)||
     !Number.isSafeInteger(result.total)||result.total<0)throw Error('استجابة غير صالحة');
  if(!result.rows.length){
   node.innerHTML='<p class="tcac-empty">لا توجد سجلات موثّقة في هذا القسم.</p>';
  }else{
   const fields={
    users:[['display_name','الاسم'],['id','معرّف المستخدم'],['created_at','تاريخ الإنشاء']],
    rooms:[['title','الغرفة'],['owner_id','المالك'],['member_records','سجلات العضوية']],
    staff:[['user_id','الحساب'],['role','الرتبة'],['permissions','الصلاحيات']],
    host_agencies:[['name','الوكالة'],['owner_id','الوكيل'],['member_count','الأعضاء']],
    recharge_agencies:[['name','الوكالة'],['owner_id','الوكيل'],['is_active','مفعلة']],
    registrations:[['name','الطلب'],['kind','النوع'],['status','الحالة']],
    agency_transfers:[['user_id','المضيف'],['agency_id','الوكالة المطلوبة'],['status','الحالة']],
    audit:[['actor_id','المسؤول'],['action','الإجراء'],['created_at','التاريخ']],
    banners:[['title','عنوان البنر'],['status','الحالة'],['sort_order','الترتيب'],['starts_at','بداية العرض'],['ends_at','نهاية العرض']]
   }[kind]||[];
   node.innerHTML=result.rows.map(row=>'<article class="tcac-record">'+fields.map(([key,label])=>
    '<div><span>'+esc(label)+'</span><strong>'+esc(Array.isArray(row[key])?row[key].join('، '):
     typeof row[key]==='boolean'?(row[key]?'نعم':'لا'):row[key]??'—')+'</strong></div>').join('')+
    '</article>').join('');
  }
  qs('#tcac-page').textContent='النتائج '+(result.total?String(p+1)+'–'+String(p+result.rows.length):'0')+' من '+result.total;
  const prev=qs('[data-tcac="prev"]'),next=qs('[data-tcac="next"]');
  if(prev)prev.disabled=p===0;
  if(next)next.disabled=p+result.rows.length>=result.total||!result.rows.length;
  status(banner?'بنرات فعلية، عرض فقط. رفع الصور والتحرير ما زالا قيد الدمج.':'بيانات مقروءة فقط من Supabase Staging.');
 }catch(e){
  if(opened&&start===requestSerial&&uid()===id){
   node.textContent='تعذر جلب البيانات: '+String(e.message).slice(0,180);
   status('لم تتم أي عملية تعديل.');
  }
 }finally{reading=false;}
}
async function visit(next){
 if(!opened)return;
 const check=await verify();
 if(!opened||!check)return;
 const item=nav.find(x=>x[0]===next);
 if(!item||!can(item[3])){status('لا تملك صلاحية فتح هذا القسم.');return;}
 ++requestSerial;reading=false;view=next;offset=0;search='';draw();
}
async function run(key){
 if(!opened)return;
 const fresh=await verify(),item=nav.find(x=>x[0]===key);
 if(!fresh||!item||!can(item[3])||!actionMap[key]){status('تم رفض العملية لأن صلاحيتك غير متاحة.');return;}
 exit(); // Close our overlay BEFORE invoking the existing working sheet.
 const trigger=document.createElement('button');trigger.type='button';
 trigger.setAttribute(actionMap[key],'');
 trigger.hidden=true;document.body.appendChild(trigger);
 try{trigger.click();}finally{trigger.remove();}
}
document.addEventListener('click',e=>{
 const entry=e.target.closest('[data-tcac-entry]');
 if(entry){e.preventDefault();void (async()=>{const ok=await verify();if(!ok)return;shell();})().catch(()=>clear());return;}
 const btn=e.target.closest('#tcac-root [data-tcac],#tcac-root [data-tcac-view],#tcac-root [data-tcac-run]');
 if(!btn)return;
 e.preventDefault();e.stopPropagation();
 if(btn.hasAttribute('data-tcac-view')){void visit(btn.dataset.tcacView);return;}
 if(btn.hasAttribute('data-tcac-run')){void run(btn.dataset.tcacRun);return;}
 const action=btn.dataset.tcac;
 if(action==='exit'){exit();return;}
 if(action==='home'||action==='modules'){void visit('overview');return;}
 if(action==='refresh'){if(readable()){reading=false;requestSerial++;void loadPage();}else void visit(view);return;}
 if(action==='prev'||action==='next'){if(reading)return;offset=Math.max(0,offset+(action==='prev'?-20:20));void loadPage();}
},true);
document.addEventListener('submit',e=>{
 if(['tcac-vip-check','tcac-vip-write','tcac-medal-write'].includes(e.target?.id)){
  e.preventDefault();e.stopImmediatePropagation();
  if(!e.target.reportValidity())return;
  void entitlementSubmit(e.target).catch(error=>status('تعذر تنفيذ العملية: '+String(error.message).slice(0,180)));
  return;
 }
 if(e.target?.id!=='tcac-search')return;
 e.preventDefault();e.stopImmediatePropagation();
 search=(new FormData(e.target).get('query')||'').toString().trim().slice(0,60);
 if(!['users','rooms'].includes(view))search='';
 offset=0;reading=false;requestSerial++;void loadPage();
},true);
document.addEventListener('keydown',e=>{
 if(!opened)return;
 if(e.key==='Escape'){e.preventDefault();exit();}
 // Trap focus inside administration; don't expose underlying TotiChat controls.
 if(e.key==='Tab'){
  const root=qs('#tcac-root');
  const nodes=[...root.querySelectorAll('button:not(:disabled),input:not(:disabled)')];
  if(!nodes.length)return;
  const first=nodes[0],last=nodes[nodes.length-1];
  if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}
  else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}
 }
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const id=uid();
 if(!id||id!==account){clear();if(id&&typeof screen==='string'&&screen==='me')void onProfile();}
 else if(opened){void verify();}
},true);
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&opened)void verify();});
window.TotiInAppAdmin=Object.freeze({onProfile,exit});
concealLegacyEntries();
if(uid()&&typeof screen==='string'&&screen==='me')void onProfile();
})();