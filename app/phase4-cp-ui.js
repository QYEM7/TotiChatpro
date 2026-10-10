/* Bilateral relationships use validated database RPCs and real profile lookup. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
let busy=false,pending=null;
const status=text=>{const node=document.querySelector('[data-cp-status]');if(node)node.textContent=text;};
async function action(partner,type,operation){
 const owner=auth.state().user?.id;
 const signature=JSON.stringify([owner,partner,type,operation]);
 if(!pending||pending.signature!==signature)pending={signature,key:crypto.randomUUID()};
 const result=await auth.requestData('/rest/v1/rpc/phase4_cp_action',{method:'POST',body:{p_partner_id:partner,p_type_id:type,p_action:operation,p_request_id:pending.key}});
 if(owner!==auth.state().user?.id)return;
 if(!result?.id)throw Error('لم يؤكد الخادم تحديث العلاقة');pending=null;render();showToast('تم تحديث العلاقة');
}
async function run(button,task){if(busy)return;busy=true;button.disabled=true;const owner=auth.state().user?.id;status('جارٍ التنفيذ…');try{await task();}catch(e){if(owner===auth.state().user?.id)status(String(e.message).slice(0,160));}finally{busy=false;if(button.isConnected)button.disabled=false;}}
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-cp-search],[data-cp-request]'))return;
 event.preventDefault();event.stopImmediatePropagation();if(!form.reportValidity())return;
 const values=new FormData(form),owner=auth.state().user?.id;
 void run(form.querySelector('button'),async()=>{
  if(form.matches('[data-cp-search]')){
   const query=String(values.get('query')).trim().replace(/[%_*]/g,'');if(!query)throw Error('أدخل اسم الشريك');
   const rows=await auth.requestData('/rest/v1/profiles?select=id,display_name&id=neq.'+encodeURIComponent(owner)+'&display_name=ilike.'+encodeURIComponent('*'+query+'*')+'&limit=20');
   if(owner!==auth.state().user?.id)return;
   const select=document.querySelector('[data-cp-request] select[name="partner"]');if(!select)return;select.replaceChildren();
   const placeholder=document.createElement('option');placeholder.value='';placeholder.textContent=rows.length?'اختر الشريك':'لا توجد نتائج';select.appendChild(placeholder);
   for(const row of rows){const option=document.createElement('option');option.value=row.id;option.textContent=row.display_name+' · '+row.id.slice(0,8);select.appendChild(option);}
   status(rows.length?'تأكد من هوية الشريك؛ يلزم قبوله لإتمام العلاقة':'لم يُعثر على مستخدم مطابق');
  }else{if(!confirm('إرسال طلب علاقة إلى الشريك المحدد؟'))return;await action(values.get('partner'),values.get('type'),'request');}
 });
},true);
window.addEventListener('click',event=>{
 const button=event.target.closest('[data-cp-action]');if(!button)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(!confirm('تأكيد '+({accept:'قبول الطلب',reject:'رفض الطلب',end:'إنهاء العلاقة أو إلغاء الطلب'}[button.dataset.cpAction])+'؟'))return;
 void run(button,()=>action(button.dataset.partner,button.dataset.type,button.dataset.cpAction));
},true);
window.addEventListener('totichat-phase2-auth',()=>{pending=null;});
})();
