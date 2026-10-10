/* T42: real authenticated support tickets. No demo threads or wallet/agency approval paths. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth)return;
const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/phase5_support_'+name,{method:'POST',body});
const $=s=>document.querySelector(s);
const categories={general:'استفسار عام',technical:'مشكلة تقنية',account:'الحساب',recharge:'الشحن',host_agency:'طلب وكالة مضيفين',host_transfer:'شكوى انتقال مضيف'};
const names={open:'مفتوحة',in_progress:'قيد المعالجة',waiting_user:'بانتظار المستخدم',resolved:'تم الحل',closed:'مغلقة'};
let generation=0,owner=null,scope='mine',page=0,canHandle=false,isOwner=false,busy=false,selected=null,pending=null;
const alive=(g,u)=>g===generation&&auth.state().signedIn&&auth.state().user?.id===u;
function notify(msg){const n=$('[data-t42-status]');if(n)n.textContent=msg;}
function reset(){generation++;owner=null;scope='mine';page=0;selected=null;canHandle=false;isOwner=false;pending=null;$('#t42-support-sheet')?.remove();}
function markup(){
 return '<section dir="rtl" id="t42-support-sheet" class="tc-phase2-account-sheet">'+
 '<h3>الدعم الفني الرسمي · TotiChat</h3><p>كل الرسائل تُحفظ في حسابك الحقيقي. طلب وكالة المضيفين أو الشكوى هنا لا يفتح وكالة ولا ينقل مضيفاً تلقائياً.</p>'+
 '<p role="status" data-t42-status>جارٍ الاتصال بالخادم…</p>'+
 '<div data-t42-content></div><button type="button" class="primary" data-t42="reload">تحديث</button>'+
 '<button type="button" class="primary" data-a="close">إغلاق</button></section>';
}
async function open(){
 if(!auth.state().signedIn)return;
 reset();owner=auth.state().user?.id;const uid=owner,openGeneration=generation;showSheet(markup(),true);
 // Presentation-only Owner check; phase5_support_action independently verifies Owner on the server.
 try{const a=await auth.requestData('/rest/v1/rpc/phase3_admin_session',{method:'POST',body:{}});
  if(owner!==uid||generation!==openGeneration||!auth.state().signedIn)return;
  isOwner=a?.isOwner===true;
 }catch{if(owner!==uid||generation!==openGeneration)return;isOwner=false;}
 if(owner===uid&&generation===openGeneration)await load();
}
function ticketView(t){
 return '<article><button type="button" data-t42="thread" data-id="'+esc(t.id)+'" class="primary">'+esc(t.subject)+'</button>'+
 '<p>'+esc(categories[t.category]||t.category)+' · '+esc(names[t.status]||t.status)+'</p>'+
 '<small>'+esc(new Date(t.updated_at).toLocaleString('ar-IQ'))+'</small></article>';
}
async function load(){
 if(!owner)return;
 const g=++generation,u=owner;notify('جارٍ تحميل التذاكر…');
 try{
  const result=await rpc('list',{p_scope:scope,p_offset:page*20,p_limit:20});
  if(!alive(g,u))return;
  if(!Array.isArray(result.rows)||typeof result.canHandle!=='boolean')throw Error('استجابة الدعم غير صالحة');
  canHandle=result.canHandle;selected=null;
  const n=$('[data-t42-content]');if(!n)return;
  n.innerHTML='<div class="visual-tab"><button type="button" data-t42="scope" data-scope="mine">تذاكري</button>'+
  (canHandle?'<button type="button" data-t42="scope" data-scope="all">صندوق الدعم</button>':'')+'</div>'+
  '<h4>'+(scope==='mine'?'تذاكري':'التذاكر الواردة')+' ('+esc(result.total)+')</h4>'+
  result.rows.map(ticketView).join('')+
  (!result.rows.length?'<p>ماكو تذاكر بهذا القسم.</p>':'')+
  '<button type="button" data-t42="previous" '+(page===0?'disabled':'')+'>السابق</button>'+
  '<button type="button" data-t42="next" '+((page+1)*20>=result.total?'disabled':'')+'>التالي</button>'+
  (scope==='mine'?'<form data-t42-form="create"><h4>تذكرة جديدة</h4>'+
  '<label>القسم<select name="category">'+Object.keys(categories).map(k=>'<option value="'+k+'">'+categories[k]+'</option>').join('')+'</select></label>'+
  '<label>العنوان<input name="subject" minlength="5" maxlength="120" required></label>'+
  '<label>شرح الطلب<textarea name="message" minlength="2" maxlength="2500" required></textarea></label>'+
  '<button class="primary" type="submit">إرسال التذكرة</button></form>':'')+
  (isOwner?'<form data-t42-form="staff"><h4>صلاحيات موظفي الدعم · Owner فقط</h4>'+ 
   '<p>هذه الصلاحية للدعم والتذاكر فقط؛ لا تسمح بفتح وكالات أو شحن محافظ.</p>'+ 
   '<label>معرّف حساب الموظف (UUID)<input type="text" name="user_id" required pattern="[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" maxlength="36"></label>'+ 
   '<label>الإجراء<select name="decision"><option value="staff_grant">منح صلاحية الدعم</option><option value="staff_revoke">سحب صلاحية الدعم</option></select></label>'+ 
   '<button type="submit" class="primary">حفظ صلاحية الموظف</button></form>':'')+
  '<div data-t42-thread></div>';
  notify('تم تحميل البيانات الحقيقية من الخادم');
 }catch(e){if(alive(g,u))notify('تعذّر تحميل خدمة الدعم: '+e.message);}
}
async function thread(id){
 const g=++generation,u=owner;
 notify('جارٍ فتح تفاصيل التذكرة…');
 try{
  const data=await rpc('thread',{p_ticket_id:id});
  if(!alive(g,u)||!data.ticket||!Array.isArray(data.messages))return;
  selected=data.ticket;
  const n=$('[data-t42-thread]');if(!n)return;
  n.innerHTML='<h4>'+esc(data.ticket.subject)+'</h4><p>الحالة: '+esc(names[data.ticket.status]||data.ticket.status)+'</p>'+
  data.messages.map(m=>'<article><strong>'+(m.author_id===data.ticket.creator_id?'صاحب التذكرة':'الدعم الفني')+'</strong>'+
     '<p style="white-space:pre-wrap;overflow-wrap:anywhere">'+esc(m.body)+'</p>'+
     '<small>'+esc(new Date(m.created_at).toLocaleString('ar-IQ'))+'</small></article>').join('')+
  (data.ticket.status!=='closed'?'<form data-t42-form="reply"><label>الرد<textarea name="message" minlength="2" maxlength="2500" required></textarea></label>'+
  '<button type="submit" class="primary">إرسال الرد</button></form>':'<p>هذه التذكرة مغلقة.</p>')+
  (data.canHandle?'<form data-t42-form="status"><label>حالة التذكرة<select name="status">'+
   ['open','in_progress','resolved','closed'].map(s=>'<option value="'+s+'"'+(data.ticket.status===s?' selected':'')+'>'+names[s]+'</option>').join('')+
   '</select></label><button class="primary" type="submit">حفظ الحالة</button></form>':'');
  notify('الرسائل المحفوظة في قاعدة البيانات');
 }catch(e){if(alive(g,u))notify('تعذّر فتح التذكرة: '+e.message);}
}
async function action(kind,data){
 const u=owner,signature=JSON.stringify([u,kind,data]);
 if(!pending||pending.signature!==signature)pending={signature,key:crypto.randomUUID()};
 const response=await rpc('action',{p_action:kind,p_data:data,p_request_id:pending.key});
 if(!auth.state().signedIn||auth.state().user?.id!==u)return;
 if(!response?.id)throw Error('الخادم لم يؤكد حفظ العملية');
 pending=null;
 const id=response.id;
 await load();
 if(kind==='create'||kind==='reply'||kind==='status'){
   await thread(id);
 }
 notify('تم حفظ العملية في قاعدة البيانات');
}
window.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-t42],[data-support-open]');
 if(!b)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(b.hasAttribute('data-support-open')){void open();return;}
 if(busy||!owner)return;
 const op=b.dataset.t42;
 if(op==='scope'){scope=b.dataset.scope==='all'&&canHandle?'all':'mine';page=0;void load();return;}
 if(op==='previous'||op==='next'){page=Math.max(0,page+(op==='next'?1:-1));void load();return;}
 if(op==='reload'){void load();return;}
 if(op==='thread'&&b.dataset.id){void thread(b.dataset.id);}
},true);
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-t42-form]'))return;
 event.preventDefault();event.stopImmediatePropagation();
 if(!form.reportValidity()||busy||!owner)return;
 const actionType=form.dataset.t42Form;
 const values=Object.fromEntries(new FormData(form));
 if(actionType!=='create'&&actionType!=='staff'&&!selected){notify('اختر تذكرة أولاً');return;}
 const data=actionType==='create'?values:
  actionType==='staff'?{user_id:String(values.user_id||'').trim()}:
  actionType==='reply'?{ticket_id:selected.id,message:values.message}:
  {ticket_id:selected.id,status:values.status};
 if(actionType==='status'&&!canHandle){notify('هذه العملية للإدارة فقط');return;}
 if(actionType==='staff'&&!isOwner){notify('تعيين موظفي الدعم للمالك فقط');return;}
 if(actionType==='status'&&!confirm('تأكيد تغيير حالة التذكرة؟'))return;
 if(actionType==='staff'&&!confirm(values.decision==='staff_grant'?'تأكيد إعطاء صلاحية الدعم للحساب المحدد؟':'تأكيد سحب صلاحية الدعم عن الحساب المحدد؟'))return;
 busy=true;const b=form.querySelector('button[type="submit"]');if(b)b.disabled=true;
 void action(actionType==='staff'?values.decision:actionType,data).catch(e=>notify('تعذّر حفظ العملية: '+e.message))
 .finally(()=>{busy=false;if(b?.isConnected)b.disabled=false;});
},true);
window.addEventListener('totichat-phase2-auth',()=>{if(owner&&owner!==auth.state().user?.id)reset();});
window.TotiSupport=Object.freeze({open});
})();