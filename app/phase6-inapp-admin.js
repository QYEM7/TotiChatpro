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
let rights=null,account='',serial=0,requestSerial=0,opened=false,view='overview',offset=0,search='',reading=false;
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
 ['catalog','الهدايا والمتجر','✧','catalog'],
 ['reports','التقارير','▥','reports'],
 ['global_gift','إعلانات الهدايا','★','chief'],
 ['open_agency','فتح وكالة مضيفين','＋','db_open'],
 ['support','صندوق خدمة العملاء','☏','support'],
 ['vip','VIP والامتيازات','♛','owner_pending'],
 ['medals','الميداليات والشارات','✿','owner_pending'],
 ['banners','البنرات','▤','chief_pending'],
 ['settlement','التسوية الشهرية','◈','chief_pending']
];
const actionMap={catalog:'data-admin-open',reports:'data-reports-open',global_gift:'data-tc-global-gift-admin',
 open_agency:'data-tc-host-approval',support:'data-support-open'};
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
function readable(){return ['users','rooms','staff','host_agencies','recharge_agencies','registrations','agency_transfers','audit'].includes(view);}
function validIdentity(n=account){return !!n&&uid()===n;}
function roleLabel(r){
 if(r?.isOwner)return 'المالك الرئيسي';
 if(r?.isMainPartner)return 'الشريك الرئيسي';
 return ({super_admin:'Super Admin',admin:'Admin',db:'DB',user:'موظف خدمة العملاء'})[r?.role]||'موظف إدارة';
}
function removeEntry(){qs('[data-tcac-entry]')?.remove();}
function exit(){
 opened=false;requestSerial++;
 qs('#tcac-root')?.remove();
 document.documentElement.classList.remove('tcac-open');
}
function clear(){
 serial++;account='';rights=null;removeEntry();exit();
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
  const result=await rpc(directory?'phase6_admin_directory':'phase6_admin_management_page',
    directory?{p_kind:kind,p_query:search,p_offset:p,p_limit:20}:{p_kind:kind,p_offset:p,p_limit:20});
  if(!opened||start!==requestSerial||uid()!==id||view!==kind)return;
  if(result?.readOnly!==true||result?.kind!==kind||!Array.isArray(result.rows)||
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
    audit:[['actor_id','المسؤول'],['action','الإجراء'],['created_at','التاريخ']]
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
  status('بيانات مقروءة فقط من Supabase Staging.');
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
if(uid()&&typeof screen==='string'&&screen==='me')void onProfile();
})();