/* Additional real Staging administration modules. No simulated operations. */
(function(){
'use strict';
const $=s=>document.querySelector(s);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const uuid=v=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(v||''));
const nat=v=>Number.isSafeInteger(v)&&v>=0?v.toLocaleString('ar-IQ'):'—';
const date=v=>v?new Date(v).toLocaleString('ar-IQ'):'—';
let api=null,auth=null,current=null,notify=null,busy=false,loadSerial=0,entries=[],tickets=[],agencies=[],ticketId=null;
function configure(x){api=x.rpc;auth=x.rights;current=x.current;notify=x.toast;}
function ensure(){if(!api||!auth())throw Error('أكمل تسجيل الدخول الإداري أولاً');}
function chief(){const r=auth?.();return r?.isOwner===true||r?.isMainPartner===true;}
function owner(){return auth?.()?.isOwner===true;}
const box=(title,body,meta='')=>'<section class="surface pad mgm-surface"><div class="surface-title"><h2>'+esc(title)+'</h2><p>'+esc(meta)+'</p></div>'+body+'</section>';
const blank=(subject='السجل')=>'<p class="mgm-empty">لا توجد بيانات '+esc(subject)+' موثقة في قاعدة الاختبار.</p>';
const input=(name,label,extra='')=>'<label>'+esc(label)+'<input name="'+name+'" '+extra+' required></label>';
const status=s=>{const n=$('#mgm-status');if(n)n.textContent=String(s||'').slice(0,260);};
function lines(rows,headers){
 if(!rows.length)return blank();
 return '<div class="table-wrap"><table class="data-table"><thead><tr>'+headers.map(t=>'<th>'+esc(t[0])+'</th>').join('')+'</tr></thead><tbody>'+
 rows.map(r=>'<tr>'+headers.map(t=>'<td>'+esc(t[1](r))+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>';
}
async function get(kind,offset=0,limit=30){
 ensure();const r=await api('phase6_admin_management_page',{p_kind:kind,p_offset:offset,p_limit:limit});
 if(r.kind!==kind||r.readOnly!==true||!Array.isArray(r.rows)||!Number.isSafeInteger(r.total))throw Error('استجابة إدارة غير صالحة');
 return r;
}
function startPage(section){return current()===section;}
async function team(){
 ensure();if(!chief())throw Error('صلاحية المالك والشريك الرئيسي مطلوبة');
 const token=++loadSerial,results=await Promise.all([get('staff'),get('audit',0,12),owner()?api('phase5_support_staff_list',{p_offset:0,p_limit:50}):Promise.resolve(null)]);
 if(token!==loadSerial||!startPage('team'))return;
 const staff=results[0],audit=results[1],supportUsers=results[2],s=staff.rows;
 const roles=lines(s,[['الحساب',r=>r.user_id],['الرتبة',r=>r.role],['الصلاحيات',r=>(r.permissions||[]).join('، ')||'—'],['آخر تعديل',r=>date(r.updated_at)]]);
 const auditing=lines(audit.rows,[['المسؤول',r=>r.actor_id||'—'],['الإجراء',r=>r.action],['التاريخ',r=>date(r.created_at)]]);
 let controls='<div class="mgm-warning">عرض التقارير والإدارة الكاملة لوكالات المضيفين يقتصر على المالك والشريك الرئيسي المحدد في القاعدة. رتبة Super Admin إضافية لا تمنح هذه الصلاحية تلقائياً.</div>';
 if(owner()){
 controls+='<form id="mgm-role-form" class="mgm-form">'+
 '<h3>تعيين موظف أو تعديل صلاحياته</h3><p>فقط مستخدم مؤكَّد وموجود مسبقاً. لا تسمح القاعدة بتعيين Owner من هنا.</p>'+
 input('user_id','UUID الحساب','pattern="[0-9a-fA-F-]{36}" maxlength="36" placeholder="UUID"')+
 '<label>الدور<select name="role"><option value="admin">Admin</option><option value="super_admin">Super Admin</option><option value="db">DB</option></select></label>'+
 '<fieldset><legend>صلاحيات إضافية</legend><label><input type="checkbox" name="catalog"> إدارة الكتالوج</label><label><input type="checkbox" name="reports"> التقارير</label><label><input type="checkbox" name="users"> المستخدمون</label><label><input type="checkbox" name="host"> فتح وكالة مضيفين بتفويض</label></fieldset>'+
 '<label class="mgm-check"><input type="checkbox" name="partner"> تعيينه شريكاً رئيسياً معتمداً (Super Admin فقط)</label>'+
 '<button class="btn btn-primary" type="submit">حفظ التعيين بعد التأكيد</button></form>';
 }
 $('#page-body').innerHTML=box('الموظفون المسجلون',roles,'إجمالي '+nat(staff.total))+
 box('سجل الإجراءات الأمنية',auditing,'آخر '+nat(audit.rows.length)+' إجراء')+
 box('الضوابط والتعيين',controls)+
 (owner()?box('موظفو خدمة العملاء',(
 Array.isArray(supportUsers?.rows)?lines(supportUsers.rows,[['الحساب',r=>r.user_id],['التفويض',r=>r.enabled?'مفعّل':'موقوف'],['التاريخ',r=>date(r.updated_at)]]):blank('لموظفي الدعم'))+
 '<form id="mgm-support-staff" class="mgm-form"><h3>تفويض خدمة العملاء</h3>'+
 input('user_id','UUID الحساب المؤكد','pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
 '<label>الإجراء<select name="decision"><option value="staff_grant">إتاحة الرد على التذاكر</option><option value="staff_revoke">إيقاف الصلاحية</option></select></label>'+
 '<button class="btn btn-primary">حفظ التفويض</button></form>'):'');
}
async function agenciesPage(kind){
 ensure();if(!chief())throw Error('إدارة الوكالات للمالك والشريك الرئيسي فقط');
 const page=kind==='host'?'hosts':'recharge',type=kind==='host'?'host_agencies':'recharge_agencies';
 const token=++loadSerial;
 const [agency,registration,transfers]=await Promise.all([get(type),get('registrations'),kind==='host'?get('agency_transfers'):Promise.resolve({rows:[],total:0})]);
 if(token!==loadSerial||!startPage(page))return;
 agencies=agency.rows;
 const arows=lines(agency.rows,[['الوكالة',x=>x.name],['المعرف',x=>x.id],['المالك',x=>x.owner_id],['النسبة',x=>x.commission_percent+'%'],['الحالة',x=>x.is_active?'نشطة':'متوقفة'],['الأعضاء',x=>nat(x.member_count)]]);
 const pending=registration.rows.filter(r=>r.kind===kind&&r.status==='pending');
 let rows=pending.map(r=>'<article class="mgm-ticket"><div><strong>'+esc(r.name)+'</strong><p>'+esc(r.id)+' · '+esc(r.applicant_id)+'</p></div>'+
 '<button class="btn btn-ghost" type="button" data-mgm="approval" data-id="'+esc(r.id)+'" data-kind="'+kind+'">مراجعة الطلب</button></article>').join('');
 if(!rows)rows=blank('لطلبات الافتتاح المعلقة في هذه الصفحة');
 const finance=kind==='host'?'<div class="mgm-warning">هذا العرض لا يصرف رواتب ولا يصفر الماس؛ التارجت ونسب التسوية الشهرية تحتاج اعتمادك قبل التشغيل.</div>':'<div class="mgm-warning">عمليات إصدار الكوينز والشحن تتطلب تأكيداً مالياً موثقاً ولا تُنفّذ تلقائياً من عرض الوكالات.</div>';
 const form='<form id="mgm-agency-form" class="mgm-form" data-kind="'+kind+'"><h3>تعديل وكالة قائمة</h3>'+
 input('id','معرّف الوكالة UUID','pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
 input('name','اسم الوكالة','minlength="2" maxlength="80"')+
 input('commission_percent','العمولة (%)','type="number" min="0" max="100" step="0.01"')+
 '<p class="mgm-warning">أدخل النسبة الحقيقية المتفق عليها فقط. أي تعديل يُحفظ في سجل الإجراءات.</p>'+
 '<button type="submit" class="btn btn-primary">تعديل إعدادات الوكالة</button></form>';
 $('#page-body').innerHTML=box('الوكالات المسجلة',arows,'إجمالي '+nat(agency.total))+
 box('طلبات فتح الوكالات',rows)+
 (kind==='host'?box('طلبات انتقال المضيفين',transfers.rows.filter(x=>['pending_old','pending_new'].includes(x.status)).map(t=>
 '<article class="mgm-ticket"><div><strong>طلب انتقال '+esc(t.user_id)+'</strong>'+
 '<p>من '+esc(t.old_agency_id||'بدون وكالة')+' إلى '+esc(t.agency_id)+'</p>'+
 '<p>الحالة: '+esc(t.status)+' · السبب: '+esc(t.reason)+'</p></div>'+
 '<button class="btn btn-ghost" data-mgm="host-transfer" type="button" data-id="'+esc(t.id)+'">مراجعة استثنائية</button></article>').join('')||
 blank('لانتقالات المضيفين التي تحتاج موافقة')):'')+
 box('إدارة الوكالة',form+finance)+
 (kind==='host'?box('التسويات الشهرية', '<form id="mgm-host-month" class="mgm-form">'+
 '<label>الشهر المغلق (UTC)<input name="month" type="month" required></label>'+
 '<button class="btn btn-secondary">فحص أرباح الماس الشهرية</button></form><div id="mgm-month-result"></div>'):'');
}
async function support(){
 ensure();const route='support',token=++loadSerial;
 const r=await api('phase5_support_list',{p_scope:'all',p_offset:0,p_limit:30});
 if(token!==loadSerial||!startPage(route))return;
 if(!r.canHandle||!Array.isArray(r.rows))throw Error('الحساب لا يملك صلاحية فريق خدمة العملاء');
 tickets=r.rows;
 const rows=tickets.map(t=>'<article class="mgm-ticket"><div><strong>'+esc(t.subject)+'</strong>'+
 '<p>'+esc(t.category)+' · '+esc(t.status)+' · '+esc(t.id)+'</p>'+
 '<small>'+esc(date(t.created_at))+'</small></div>'+
 '<button data-mgm="ticket" data-id="'+esc(t.id)+'" class="btn btn-ghost">فتح المحادثة</button></article>').join('')||blank('للتذاكر');
 $('#page-body').innerHTML=box('صندوق خدمة العملاء',rows,'إجمالي '+nat(r.total))+'<div id="mgm-ticket-details"></div>';
}
async function ticket(id){
 if(!uuid(id))throw Error('معرف التذكرة غير صالح');ticketId=id;
 const result=await api('phase5_support_thread_page',{p_ticket_id:id,p_offset:0,p_limit:30});
 if(!result.canHandle||!Array.isArray(result.messages)||!result.ticket)throw Error('التذكرة غير متاحة للإدارة');
 const list=result.messages.slice().reverse().map(m=>'<div class="mgm-message"><strong>'+esc(m.author_id)+'</strong><p>'+esc(m.body)+'</p><small>'+esc(date(m.created_at))+'</small></div>').join('')||blank('للرسائل');
 $('#mgm-ticket-details').innerHTML=box('المحادثة: '+result.ticket.subject,list+
 '<form id="mgm-reply" class="mgm-form"><label>الرد للعميل<textarea name="message" maxlength="2500" minlength="2" rows="4" required></textarea></label><button class="btn btn-primary">إرسال رد حقيقي</button></form>'+
 '<form id="mgm-ticket-status" class="mgm-form"><label>حالة التذكرة<select name="status"><option value="open">مفتوحة</option><option value="in_progress">قيد المتابعة</option><option value="resolved">تم الحل</option><option value="closed">مغلقة</option></select></label><button class="btn btn-secondary">حفظ الحالة</button></form>');
 $('#mgm-ticket-details select[name="status"]').value=['open','in_progress','resolved','closed'].includes(result.ticket.status)?result.ticket.status:'open';
}
async function vip(){
 ensure();const owned=owner();
 const form='<form id="mgm-vip-check" class="mgm-form"><h3>التحقق من VIP حقيقي</h3>'+
 input('target','معرّف المستخدم','pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
 '<button class="btn btn-secondary">عرض الحالة</button></form><div id="mgm-vip-result"></div>';
 const grant=owned?'<form id="mgm-vip-change" class="mgm-form"><h3>منح أو إيقاف VIP</h3>'+
 input('target','معرّف المستخدم','pattern="[0-9a-fA-F-]{36}" maxlength="36"')+
 '<label>الإجراء<select name="action"><option value="grant">منح VIP</option><option value="revoke">سحب VIP</option></select></label>'+
 '<label>المستوى (1–10)<input name="tier" type="number" min="1" max="10" value="1" required></label>'+
 '<label>انتهاء الامتياز (اختياري للمنح)<input name="expires" type="datetime-local"></label>'+
 '<label>سبب الإجراء (10 أحرف على الأقل)<textarea name="reason" minlength="10" maxlength="300" required></textarea></label>'+
 '<button class="btn btn-primary">تأكيد القرار وتسجيله</button></form>':
 '<p class="mgm-warning">تغيير VIP محفوظ للمالك الرئيسي فقط.</p>';
 $('#page-body').innerHTML=box('الاستحقاق',form)+box('صلاحيات المنح',grant);
}
async function medals(){
 ensure();const token=++loadSerial,r=await api('phase5_medal_catalog',{});
 if(token!==loadSerial||!startPage('medals'))return;
 const rows=Array.isArray(r)?r:Array.isArray(r?.medals)?r.medals:Array.isArray(r?.rows)?r.rows:[];
 const t=lines(rows,[['المفتاح',x=>x.medal_key||x.key||'—'],['الاسم',x=>x.display_name||x.label||'—'],['الوصف',x=>x.description||'—']]);
 const add=owner()?'<form id="mgm-medal-change" class="mgm-form"><h3>إدارة منح المداليات</h3>'+
 '<label>الإجراء<select name="action"><option value="grant">منح مدالية</option><option value="revoke">سحب مدالية</option><option value="register">تسجيل نوع مدالية جديد</option></select></label>'+
 input('key','مفتاح المدالية (أحرف لاتينية وأرقام)','pattern="[a-z][a-z0-9_-]{2,39}" maxlength="40"')+
 '<label>معرف المستفيد UUID (للمنح والسحب)<input name="target" placeholder="UUID"></label>'+
 '<label>اسم المدالية الجديدة (للتسجيل)<input name="label" maxlength="60"></label>'+
 '<label>وصف المدالية الجديدة (اختياري)<input name="description" maxlength="180"></label>'+
 '<label>سبب موثّق (10 أحرف على الأقل)<textarea name="reason" minlength="10" maxlength="300" required></textarea></label>'+
 '<button class="btn btn-primary">حفظ القرار بعد التأكيد</button></form>':
 '<p class="mgm-warning">إجراءات إنشاء ومنح المداليات للمالك الرئيسي فقط.</p>';
 $('#page-body').innerHTML=box('كتالوج المداليات',t)+box('إدارة الاستحقاقات',add);
}
function formValue(form,name){return String(new FormData(form).get(name)||'').trim();}
function checkReason(v){if(v.length<10||v.length>300)throw Error('يجب كتابة سبب واضح من 10 إلى 300 حرف');}
async function executeAction(fn,confirmation){
 if(busy)return;
 if(!window.confirm(confirmation))return;
 busy=true;try{await fn();notify('تم تنفيذ العملية على Staging وحفظها في سجل النظام');}
 catch(e){notify('فشل التنفيذ: '+e.message,true);}finally{busy=false;}
}
document.addEventListener('click',e=>{
 const btn=e.target.closest('[data-mgm]');if(!btn||!api)return;
 const action=btn.dataset.mgm,id=btn.dataset.id;
 if(action==='ticket'){
  if(!startPage('support'))return;
  ticket(id).catch(err=>notify(err.message,true));return;
 }
 if(action==='host-transfer'){
  if(!chief()||!uuid(id)||!startPage('hosts'))return;
  const markup='<form id="mgm-host-exception" class="mgm-form"><h3>الموافقة الاستثنائية على نقل مضيف</h3>'+
   '<p class="mgm-warning">الأصل موافقة الوكيل القديم. الاستثناء فقط بعد التحقيق في شكوى أو توقف الوكالة أو الرفض التعسفي.</p>'+
   '<input type="hidden" name="id" value="'+esc(id)+'">'+
   '<label class="mgm-check"><input type="checkbox" name="verified" required> أؤكد مراجعة الشكوى والتحقق من مبررات الاستثناء</label>'+
   '<label>قرار التحقيق والأدلة (10 أحرف على الأقل)<textarea name="note" minlength="10" maxlength="500" required></textarea></label>'+
   '<button class="btn btn-primary">تثبيت الاستثناء في قاعدة البيانات</button></form>';
  const holder=document.createElement('section');holder.className='surface pad mgm-surface';holder.innerHTML=markup;
  $('#page-body').append(holder);holder.scrollIntoView({block:'center',behavior:'smooth'});return;
 }
 if(action==='approval'){
  const kind=btn.dataset.kind;
  if(!['host','recharge'].includes(kind)||!uuid(id)||!chief())return;
  const html='<form id="mgm-approval-form" class="mgm-form" data-kind="'+kind+'">'+
   '<h3>مراجعة طلب افتتاح وكالة</h3><p class="mgm-code">'+esc(id)+'</p>'+
   '<label>القرار<select name="decision"><option value="approve_registration">موافقة</option><option value="reject_registration">رفض</option></select></label>'+
   input('commission','نسبة عمولة معتمدة عند الموافقة','type="number" min="0" max="100" step="0.01" placeholder="أدخل النسبة المتفق عليها"')+
   '<label>تعليل القرار<textarea name="note" minlength="3" maxlength="500" required></textarea></label>'+
   '<input type="hidden" name="id" value="'+esc(id)+'">'+
   '<button class="btn btn-primary">تأكيد القرار الإداري</button></form>';
  const place=document.createElement('div');place.innerHTML=box('قرار بشأن الطلب',html);
  $('#page-body').append(place);place.scrollIntoView({block:'center',behavior:'smooth'});
 }
});
document.addEventListener('submit',e=>{
 const form=e.target;
 const known=['mgm-role-form','mgm-support-staff','mgm-host-exception','mgm-agency-form','mgm-approval-form','mgm-reply','mgm-ticket-status','mgm-vip-check','mgm-vip-change','mgm-medal-change','mgm-host-month'];
 if(!form.id||!known.includes(form.id)||!api)return;
 e.preventDefault();
 if(!form.reportValidity()||busy)return;
 void (async()=>{
  const id=form.id;
  if(id==='mgm-role-form'){
   if(!owner())throw Error('المالك الرئيسي وحده يدير صلاحيات الموظفين');
   const userId=formValue(form,'user_id'),role=formValue(form,'role');
   if(!uuid(userId)||!['admin','super_admin','db'].includes(role))throw Error('حدد حساباً ودوراً صحيحاً');
   const perms=[...form.querySelectorAll('input[type=checkbox]:checked')].map(x=>({catalog:'catalog.manage',reports:'reports.read',users:'users.manage',host:'host_agency.open'}[x.name])).filter(Boolean);
   const partner=new FormData(form).has('partner');
   if(partner&&role!=='super_admin')throw Error('الشريك الرئيسي يجب أن يحمل رتبة Super Admin');
   await executeAction(()=>api('phase3_manage_access',{p_user_id:userId,p_role:role,p_permissions:perms,p_main_partner:partner}).then(team),
    'هل توافق بصفتك المالك على تعيين الصلاحيات المحددة؟ لن تتحول رتبة الموظف إلى Owner.');
  }else if(id==='mgm-support-staff'){
   if(!owner())throw Error('تفويض الدعم خاص بالمالك');
   const target=formValue(form,'user_id'),action=formValue(form,'decision');
   if(!uuid(target)||!['staff_grant','staff_revoke'].includes(action))throw Error('معرّف أو إجراء غير صالح');
   await executeAction(()=>api('phase5_support_action',{p_action:action,
    p_data:{user_id:target},p_request_id:crypto.randomUUID()}).then(team),
    'تأكيد تغيير صلاحية فريق خدمة العملاء لهذا الحساب؟');
  }else if(id==='mgm-host-exception'){
   if(!chief())throw Error('استثناء انتقال المضيف للمالك والشريك الرئيسي فقط');
   const requestId=formValue(form,'id'),note=formValue(form,'note');
   if(!uuid(requestId)||!form.querySelector('[name=verified]')?.checked||note.length<10||note.length>500)
    throw Error('مراجعة الشكوى ومبررات الاستثناء مطلوبة');
   await executeAction(()=>api('phase4_agency_action',{p_action:'exception_transfer',
    p_data:{id:requestId,note},p_request_id:crypto.randomUUID()}).then(()=>agenciesPage('host')),
    'هل تؤكد استثناء موافقة الوكيل القديم بعد التحقيق في الشكوى؟');
  }else if(id==='mgm-agency-form'){
   if(!chief())throw Error('إدارة الوكالات محصورة بالمالك والشريك المعتمد');
   const target=formValue(form,'id'),name=formValue(form,'name'),commission=Number(formValue(form,'commission_percent'));
   if(!uuid(target)||name.length<2||name.length>80||!Number.isFinite(commission)||commission<0||commission>100)throw Error('معلومات الوكالة غير مكتملة');
   await executeAction(()=>api('phase4_agency_action',{p_action:'edit',p_data:{id:target,name,commission_percent:commission},p_request_id:crypto.randomUUID()}).then(()=>agenciesPage(form.dataset.kind)),
    'سيُعتمد اسم الوكالة ونسبة العمولة المدخلة مباشرة في Staging. متأكد من الأرقام؟');
  }else if(id==='mgm-approval-form'){
   if(!chief())throw Error('الصلاحية غير متاحة');
   const target=formValue(form,'id'),decision=formValue(form,'decision'),note=formValue(form,'note'),rawRate=formValue(form,'commission'),commission=Number(rawRate);
   if(!uuid(target)||note.length<3||note.length>500||!['approve_registration','reject_registration'].includes(decision))throw Error('طلب المراجعة غير صحيح');
   if(decision==='approve_registration'&&(!rawRate||!Number.isFinite(commission)||commission<0||commission>100))throw Error('لا تعتمد الوكالة بدون النسبة المتفق عليها');
   const data={id:target,note,...(decision==='approve_registration'?{commission_percent:commission}:{})};
   await executeAction(()=>api('phase4_agency_action',{p_action:decision,p_data:data,p_request_id:crypto.randomUUID()}).then(()=>agenciesPage(form.dataset.kind)),
    'هل تؤكد القرار بعد مراجعة الطلب والعمولة يدوياً؟');
  }else if(id==='mgm-reply'){
   const message=formValue(form,'message');
   if(!uuid(ticketId)||message.length<2||message.length>2500)throw Error('تحقق من الرد');
   await executeAction(()=>api('phase5_support_action',{p_action:'reply',p_data:{ticket_id:ticketId,message},p_request_id:crypto.randomUUID()}).then(()=>ticket(ticketId)),
    'تأكيد إرسال هذا الرد للعميل من حسابك الإداري؟');
  }else if(id==='mgm-ticket-status'){
   const v=formValue(form,'status');if(!uuid(ticketId)||!['open','in_progress','resolved','closed'].includes(v))throw Error('الحالة غير صالحة');
   await executeAction(()=>api('phase5_support_action',{p_action:'status',p_data:{ticket_id:ticketId,status:v},p_request_id:crypto.randomUUID()}).then(()=>ticket(ticketId)),
    'هل تؤكد تغيير حالة التذكرة في قاعدة البيانات؟');
  }else if(id==='mgm-vip-check'){
   const id=formValue(form,'target');if(!uuid(id))throw Error('معرّف حساب غير صالح');
   const r=await api('phase5_vip_status',{p_target:id});
   const out=$('#mgm-vip-result');if(out)out.textContent=JSON.stringify(r,null,2);
  }else if(id==='mgm-vip-change'){
   if(!owner())throw Error('المالك فقط يستطيع تعديل VIP');
   const target=formValue(form,'target'),action=formValue(form,'action'),tier=Number(formValue(form,'tier')),
    expiry=formValue(form,'expires'),reason=formValue(form,'reason');
   if(!uuid(target)||!['grant','revoke'].includes(action))throw Error('استحقاق غير صالح');
   if(action==='grant'&&(!Number.isInteger(tier)||tier<1||tier>10))throw Error('الرتبة 1 إلى 10 فقط');
   checkReason(reason);
   await executeAction(()=>api('phase5_vip_owner_action',{p_action:action,p_target:target,
    p_tier:action==='revoke'?0:tier,p_expires_at:action==='revoke'||!expiry?null:new Date(expiry).toISOString(),
    p_reason:reason,p_request_id:crypto.randomUUID()}).then(vip),
    'تأكيد '+(action==='grant'?'منح':'سحب')+' VIP لهذا الحساب؟ الإجراء يسجّل في سجل الأمان.');
  }else if(id==='mgm-medal-change'){
   if(!owner())throw Error('المالك فقط');
   const action=formValue(form,'action'),key=formValue(form,'key'),target=formValue(form,'target'),
    label=formValue(form,'label'),description=formValue(form,'description'),reason=formValue(form,'reason');
   if(!['grant','revoke','register'].includes(action)||!/^[a-z][a-z0-9_-]{2,39}$/.test(key))throw Error('مفتاح المدالية غير صالح');
   checkReason(reason);
   if(action!=='register'&&!uuid(target))throw Error('حدد UUID المستفيد');
   if(action==='register'&&(label.length<3||label.length>60))throw Error('اسم مدالية غير صالح');
   await executeAction(()=>api('phase5_medal_owner_action',{p_action:action,p_medal_key:key,
    p_target:action==='register'?null:target,p_label:action==='register'?label:null,
    p_description:action==='register'?description:null,p_reason:reason,p_request_id:crypto.randomUUID()}).then(medals),
    'هل تؤكد تسجيل قرار المدالية الحقيقية؟');
  }else if(id==='mgm-host-month'){
   if(!chief())throw Error('صلاحية مراجعة شهرية غير متاحة');
   const month=formValue(form,'month');
   if(!/^20[2-9]\d-(0[1-9]|1[0-2])$/.test(month))throw Error('اختر شهر صحيح');
   const r=await api('phase5_host_month_preflight',{p_month:month+'-01',p_offset:0,p_limit:25});
   const out=$('#mgm-month-result');
   if(out)out.innerHTML='<div class="mgm-warning">المراجعة قرائية فقط. لا يوجد صرف ولا تصفير.</div>'+
    lines(Array.isArray(r.entries)?r.entries:[],[['الوكالة',x=>x.agency_id],['المضيف',x=>x.user_id],
      ['ماس الأرباح',x=>x.earned_diamonds],['المتبقي',x=>x.remaining_diamonds]]);
  }
 })().catch(err=>notify(err.message,true));
},true);
window.TotiAdminManagement=Object.freeze({configure,team,agencies:agenciesPage,support,vip,medals});
})();
