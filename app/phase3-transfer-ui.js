/* Real transfer form. Wallet balances remain read-only in the display module. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
function hydrate(){
 if(screen!=='wallet'||!auth.state().signedIn)return;
 const hero=document.querySelector('#app .visual-hero'),container=hero?.parentElement;
 if(!container||container.querySelector('[data-wallet-transfer]'))return;

  const transfer=document.createElement('section');transfer.className='tc-wallet-transfer';transfer.dataset.walletTransfer='';
  transfer.innerHTML='<h3>تحويل العملات</h3><form data-wallet-search><label>اسم المستلم<input name="query" maxlength="40" required></label><button class="primary">بحث</button></form><form data-wallet-transfer-form><label>المستلم<select name="recipient" required><option value="">ابحث عن مستلم أولاً</option></select></label><label>عدد العملات<input name="amount" type="number" min="1" max="9007199254740991" step="1" required></label><button class="primary">تأكيد التحويل</button></form><p data-wallet-transfer-status role="status"></p>';
  container.appendChild(transfer);
}
let transferBusy=false,pendingTransfer=null;
function transferStatus(text){const node=document.querySelector('[data-wallet-transfer-status]');if(node)node.textContent=text;}
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-wallet-search],[data-wallet-transfer-form]'))return;
 event.preventDefault();event.stopImmediatePropagation();if(transferBusy||!form.reportValidity())return;
 const user=auth.state().user?.id;if(!user)return;
 const button=form.querySelector('button'),values=new FormData(form);
 transferBusy=true;button.disabled=true;transferStatus('جارٍ التنفيذ…');
 void (async()=>{
  if(form.matches('[data-wallet-search]')){
   const query=String(values.get('query')).trim().replace(/[%_*]/g,'');if(!query)throw Error('أدخل اسم المستلم');
   const rows=await auth.requestData('/rest/v1/profiles?select=id,display_name&id=neq.'+encodeURIComponent(user)+'&display_name=ilike.'+encodeURIComponent('*'+query+'*')+'&order=display_name&limit=20');
   if(auth.state().user?.id!==user)return;
   const select=document.querySelector('[data-wallet-transfer-form] select');if(!select)return;select.replaceChildren();
   const placeholder=document.createElement('option');placeholder.value='';placeholder.textContent=rows.length?'اختر المستلم':'لا توجد نتائج';select.appendChild(placeholder);
   for(const row of rows){const option=document.createElement('option');option.value=row.id;option.textContent=row.display_name+' · '+row.id.slice(0,8);select.appendChild(option);}
   transferStatus(rows.length?'تحقق من هوية المستلم قبل التحويل':'لم يعثر الخادم على مستخدم مطابق');
  }else{
   const recipient=String(values.get('recipient')),amount=Number(values.get('amount'));
   if(!/^[0-9a-f-]{36}$/i.test(recipient)||!Number.isSafeInteger(amount)||amount<=0)throw Error('المستلم أو المبلغ غير صالح');
   const signature=JSON.stringify([user,recipient,amount]);
   if(!pendingTransfer||pendingTransfer.signature!==signature){
    if(!confirm('تحويل '+amount.toLocaleString('en-US')+' عملة إلى '+form.querySelector('select').selectedOptions[0].textContent+'؟')){transferStatus('أُلغي التحويل');return;}
    pendingTransfer={signature,key:crypto.randomUUID()};
   }
   const result=await auth.requestData('/rest/v1/rpc/phase3_transfer_coins',{method:'POST',body:{p_recipient_id:recipient,p_amount:amount,p_request_id:pendingTransfer.key}});
   if(auth.state().user?.id!==user)return;
   if(result?.status!=='completed')throw Error('لم يؤكد الخادم إتمام التحويل');
   pendingTransfer=null;form.reset();transferStatus('تم التحويل · '+result.id);void window.TotiPhase2Wallet?.refresh?.();
  }
 })().catch(e=>{if(auth.state().user?.id===user)transferStatus(String(e.message).slice(0,160));}).finally(()=>{transferBusy=false;if(button.isConnected)button.disabled=false;});
},true);

const before=render;
render=function(){const result=before.apply(this,arguments);hydrate();return result;};
window.addEventListener('totichat-phase2-auth',()=>{pendingTransfer=null;document.querySelector('[data-wallet-transfer]')?.remove();hydrate();});
})();
