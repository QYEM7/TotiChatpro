/* Agency review and transfers use authenticated, audited database commands. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state=null,generation=0,busy=false,pending=null,sheetOwner=null;
const rpc=(name,body={})=>auth.requestData('/rest/v1/rpc/phase4_agency_'+name,{method:'POST',body});
const status=x=>{const n=document.querySelector('[data-agency-status]');if(n)n.textContent=x;};
const button=(label,action,id)=>'<button type="button" class="primary" data-agency-action="'+action+'" data-id="'+esc(id)+'">'+label+'</button>';
function mayManage(kind){return kind==='host'?state?.authority?.canManageHostAgencies:state?.authority?.canManageRechargeAgencies;}
async function load(){
 const version=++generation,user=auth.state().user?.id;status('جارٍ تحميل الوكالات…');
 try{const result=await rpc('state');if(version!==generation||auth.state().user?.id!==user)return;if(!Array.isArray(result.agencies)||!Array.isArray(result.requests)||!Array.isArray(result.registrations))throw Error('استجابة الوكالات غير صالحة');state=result;
  const n=document.querySelector('[data-agency-body]');if(!n)return;
  const kinds={host:'مضيفين',recharge:'شحن'},labels={pending:'بانتظار مراجعة الطلب',approved:'تمت الموافقة',rejected:'مرفوض',pending_old:'بانتظار موافقة الوكيل القديم',pending_new:'بانتظار موافقة الوكيل الجديد',completed:'مكتمل'};
  const agency=id=>state.agencies.find(a=>a.id===id),myAgencies=state.agencies.filter(a=>a.owner_id===user);
  n.innerHTML='<h4>طلب فتح وكالة</h4><form data-agency-form="register"><label>النوع<select name="kind"><option value="host">مضيفين</option><option value="recharge">شحن</option></select></label><label>اسم الوكالة<input name="name" minlength="2" maxlength="80" required></label><label>وسيلة التواصل<input name="contact" minlength="3" maxlength="100" required></label><label>سبب الطلب<textarea name="reason" minlength="3" maxlength="500" required></textarea></label><button class="primary">إرسال طلب للمراجعة</button></form><h4>طلبات فتح الوكالات</h4>'+state.registrations.map(r=>'<article><b>'+esc(r.name)+' · '+kinds[r.kind]+'</b><p>'+esc(labels[r.status]||r.status)+' · '+esc(r.review_note||'')+'</p><p>'+esc(r.details?.contact)+' · '+esc(r.details?.reason)+'</p>'+(r.status==='pending'&&mayManage(r.kind)?button('مراجعة الطلب','review',r.id):'')+'</article>').join('')+(!state.registrations.length?'<p>لا توجد طلبات.</p>':'')+
   '<h4>الوكالات</h4>'+state.agencies.map(a=>'<article><b>'+esc(a.name)+' · '+kinds[a.kind]+'</b><p>'+esc(a.id)+' · '+(a.is_active?'نشطة':'مغلقة')+'</p>'+(a.owner_id===user||mayManage(a.kind)?'<p>نسبة العمولة المضبوطة: '+esc(a.commission_percent)+'%</p>':'')+(mayManage(a.kind)?button('تعديل','edit',a.id)+(a.is_active?button('إغلاق مع حفظ السجلات','close',a.id):''):'')+'</article>').join('')+(!state.agencies.length?'<p>لا توجد وكالات متاحة.</p>':'')+
   '<h4>الانضمام أو الانتقال لوكالة مضيفين</h4><form data-agency-form="join"><label>الوكالة<select name="agency_id" required><option value="">اختر وكالة نشطة</option>'+state.agencies.filter(a=>a.kind==='host'&&a.is_active).map(a=>'<option value="'+a.id+'">'+esc(a.name)+' · '+a.id.slice(0,8)+'</option>').join('')+'</select></label><label>سبب الانضمام أو الانتقال<textarea name="reason" minlength="3" maxlength="500" required></textarea></label><button class="primary">إرسال طلب</button></form>'+state.requests.map(r=>{
    const oldOwned=myAgencies.some(a=>a.id===r.old_agency_id),newOwned=myAgencies.some(a=>a.id===r.agency_id),active=['pending_old','pending_new'].includes(r.status);
    return '<article><b>'+esc(r.user_id)+' → '+esc(agency(r.agency_id)?.name||r.agency_id)+'</b><p>'+esc(labels[r.status]||r.status)+' · '+esc(r.reason)+'</p>'+(r.status==='pending_old'&&oldOwned?button('الموافقة على مغادرة الوكالة القديمة','approve_old',r.id):'')+(r.status==='pending_new'&&newOwned?button('قبول المضيف','accept_join',r.id):'')+(active&&(oldOwned||newOwned||mayManage('host'))?button('رفض الطلب','reject_join',r.id):'')+(active&&mayManage('host')?button('قرار انتقال استثنائي بعد التحقيق','exception',r.id):'')+'</article>';
   }).join('')+'<h4>الأعضاء المصرّح بعرضهم</h4>'+state.members.map(m=>'<p>'+esc(m.user_id)+' · '+esc(agency(m.agency_id)?.name||m.agency_id)+' · '+esc(m.joined_at)+'</p>').join('')+(!state.members.length?'<p>لا يوجد أعضاء مسجلون.</p>':'')+'<div data-agency-editor></div>';status('تم تحميل سجلات القاعدة الفعلية');
 }catch(e){if(version===generation&&auth.state().user?.id===user)status(e.message+'؛ اضغط تحديث للمحاولة مجدداً');}
}
function open(){sheetOwner=auth.state().user?.id;state=null;pending=null;showSheet('<section dir="rtl" class="tc-phase2-account-sheet" data-agency-sheet><h3>الوكالات والطلبات</h3><p role="status" data-agency-status></p><div data-agency-body></div><button class="primary" data-agency-action="refresh">تحديث</button><button class="primary" data-a="close">إغلاق</button></section>',true);void load();}
async function action(operation,data){
 const user=auth.state().user?.id,signature=JSON.stringify([user,operation,data]);if(!pending||pending.signature!==signature){if(!confirm('تأكيد حفظ هذه العملية في سجلات الوكالة؟'))return;pending={signature,key:crypto.randomUUID()};}
 const result=await rpc('action',{p_action:operation,p_data:data,p_request_id:pending.key});if(auth.state().user?.id!==user)return;if(!result?.id)throw Error('الخادم لم يؤكد العملية');pending=null;await load();status('تم الحفظ وتسجيل التدقيق');
}
async function run(b,task){if(busy)return;busy=true;b.disabled=true;const user=auth.state().user?.id;status('جارٍ التنفيذ…');try{await task();}catch(e){if(user===auth.state().user?.id)status(e.message);}finally{busy=false;if(b.isConnected)b.disabled=false;}}
window.addEventListener('click',e=>{
 const b=e.target.closest('[data-agencies-open],[data-agency-action]');if(!b)return;e.preventDefault();e.stopImmediatePropagation();if(b.hasAttribute('data-agencies-open')){open();return;}const op=b.dataset.agencyAction,id=b.dataset.id;if(busy)return;
 if(op==='refresh'){void load();return;}if(!state)return;
 if(['approve_old','accept_join','reject_join'].includes(op)){void run(b,()=>action(op,{id}));return;}
 const n=document.querySelector('[data-agency-editor]');if(!n)return;
 if(op==='review'){const r=state.registrations.find(r=>r.id===id);if(!r)return;n.innerHTML='<form data-agency-form="review" data-id="'+id+'"><h4>مراجعة '+esc(r.name)+'</h4><label>القرار<select name="decision"><option value="approve_registration">موافقة</option><option value="reject_registration">رفض</option></select></label><label>نسبة العمولة عند الموافقة<input name="commission_percent" type="number" min="0" max="100" step="0.01"></label><label>ملاحظة المراجعة<textarea name="note" minlength="3" maxlength="500" required></textarea></label><button class="primary">حفظ القرار</button></form>';}
 if(op==='edit'){const a=state.agencies.find(a=>a.id===id);if(!a)return;n.innerHTML='<form data-agency-form="edit" data-id="'+id+'"><label>الاسم<input name="name" value="'+esc(a.name)+'" minlength="2" maxlength="80" required></label><label>العمولة %<input type="number" name="commission_percent" value="'+esc(a.commission_percent)+'" min="0" max="100" step="0.01" required></label><button class="primary">حفظ الإعدادات</button></form>';}
 if(op==='close'||op==='exception')n.innerHTML='<form data-agency-form="'+(op==='close'?'close':'exception_transfer')+'" data-id="'+id+'"><label>'+(op==='close'?'سبب الإغلاق (السجلات تبقى محفوظة)':'قرار التحقيق وسبب استثناء موافقة الوكيل القديم')+'<textarea name="note" minlength="'+(op==='close'?3:10)+'" maxlength="500" required></textarea></label><button class="primary">حفظ القرار</button></form>';
 n.scrollIntoView({block:'nearest'});
},true);
window.addEventListener('submit',e=>{
 const form=e.target;if(!form.matches('[data-agency-form]'))return;e.preventDefault();e.stopImmediatePropagation();if(!form.reportValidity())return;
 const data=Object.fromEntries(new FormData(form)),type=form.dataset.agencyForm;let operation=type;if(form.dataset.id)data.id=form.dataset.id;
 if(type==='review'){operation=data.decision;delete data.decision;if(operation==='approve_registration'&&data.commission_percent===''){status('أدخل نسبة العمولة صراحةً قبل الموافقة');return;}}
 if(data.commission_percent!==undefined&&data.commission_percent!=='')data.commission_percent=Number(data.commission_percent);
 void run(form.querySelector('button'),()=>action(operation,data));
},true);
window.addEventListener('totichat-phase2-auth',()=>{generation++;pending=null;state=null;if(sheetOwner!==auth.state().user?.id)document.querySelector('[data-agency-sheet]')?.remove();});
})();
