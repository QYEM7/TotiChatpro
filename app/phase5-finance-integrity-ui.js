/* TotiChat Staging: financial integrity inspection, strictly read-only.
 * Owner/main-partner authorization is enforced AGAIN in Postgres.
 * No payouts, no rates, no wallet changes or demo financial data.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
let user='',epoch=0,serial=0,role=null,roleLoading=false,loading=false;
const signed=()=>auth.state().signedIn===true&&auth.state().user?.id===user;
const permitted=()=>role?.isOwner===true||role?.isMainPartner===true;
const shown=()=>!!$('#tc-finance-integrity')&&!!$('#overlay')?.classList.contains('show');
function sync(){
 const id=auth.state().signedIn===true?auth.state().user?.id||'':'';
 if(id===user)return;
 if(shown()&&typeof closeSheet==='function')closeSheet();
 user=id;epoch++;serial++;role=null;roleLoading=false;loading=false;
}
function node(tag,value){
 const el=document.createElement(tag);el.textContent=String(value??'');return el;
}
function entry(){
 if(!signed()||!permitted()||screen!=='me')return;
 const panel=$('#app .me-more');
 if(!panel||panel.querySelector('[data-finance-inspect]'))return;
 const button=document.createElement('button');
 button.type='button';button.dataset.financeInspect='';
 button.setAttribute('aria-label','فحص سلامة سجلات المالية الحقيقية');
 for(const [text,style] of [['🧾','more-icon'],['مطابقة السجلات المالية',''],['‹','chev']]){
  const span=node('span',text);if(style)span.className=style;button.append(span);
 }
 panel.append(button);
}
async function authority(){
 if(!signed()||roleLoading||role)return;
 roleLoading=true;const stamp=epoch,id=user;
 try{
  const result=await rpc('phase3_admin_session',{});
  if(stamp!==epoch||id!==user||!signed())return;
  role=result;entry();
 }catch(_){if(stamp===epoch)role=null}
 finally{if(stamp===epoch)roleLoading=false}
}
function message(s){
 const el=$('#tc-finance-integrity-message');
 if(el)el.textContent=String(s||'').slice(0,230);
}
const count=value=>Number.isSafeInteger(value)&&value>=0?
 value.toLocaleString('ar-IQ'):'غير متاح بدقة';
function renderReport(result){
 const panel=$('#tc-finance-integrity-results');
 if(!panel)return;
 panel.replaceChildren();
 const entries=[
  ['الهدايا التي فُحصت',result.giftEventsChecked],
  ['قيود الهدايا التي تحتاج مراجعة',result.giftIntegrityIssues],
  ['عمليات تحويل الماس المفحوصة',result.redemptionsChecked],
  ['قيود التحويل التي تحتاج مراجعة',result.redemptionIntegrityIssues],
  ['المحافظ المفحوصة',result.walletsChecked],
  ['محافظ تحتاج مطابقة ماس',result.walletsNeedingDiamondReconciliation]
 ];
 for(const [label,value] of entries){
  const item=node('p',label+': '+count(value));item.className='tc-finance-audit-line';
  panel.append(item);
 }
 panel.append(node('p',result.hasDetectedLedgerIssues||result.requiresManualWalletReview?
  'توجد اختلافات تحتاج مراجعة إدارية؛ لم يُعدَّل أي رصيد.':
  'لم يُكتشف اختلاف ضمن نطاق الفحص المحدود. هذا ليس تدقيقاً مالياً شاملاً.'));
 panel.append(node('p','فترة قيود الهدايا والتحويل: آخر 7 أيام. فحص تغطية المحافظ شامل.'));
}
function validate(result){
 return !!(result&&result.isReadOnly===true&&result.canZeroDiamonds===false&&
  result.paysSalaries===false&&result.hasPayrollRates===false&&
  typeof result.hasDetectedLedgerIssues==='boolean'&&
  typeof result.requiresManualWalletReview==='boolean'&&
  ['giftEventsChecked','giftIntegrityIssues','redemptionsChecked',
   'redemptionIntegrityIssues','walletsChecked',
   'walletsNeedingDiamondReconciliation'].every(
   k=>Number.isSafeInteger(result[k])&&result[k]>=0));
}
async function load(){
 if(!shown()||!signed()||!permitted()||loading)return;
 loading=true;const stamp=epoch,id=user,s=++serial;
 message('جارٍ مطابقة السجلات الحقيقية، للقراءة فقط…');
 try{
  const result=await rpc('phase5_finance_integrity_preflight',{});
  if(stamp!==epoch||s!==serial||id!==user||!signed()||!shown())return;
  if(!validate(result))throw Error('نتيجة مالية غير صالحة أو خارج دقة المتصفح');
  renderReport(result);
  message('اكتمل الفحص القرائي. لا يُجري النظام تسوية رواتب أو تصفير ماس هنا.');
 }catch(e){
  if(stamp===epoch&&s===serial&&signed()&&shown())
   message('تعذر الفحص: '+String(e.message||'خطأ اتصال').slice(0,140));
 }finally{if(stamp===epoch)loading=false}
}
function open(){
 sync();
 if(!signed()||!permitted()||typeof showSheet!=='function')return;
 showSheet('<section id="tc-finance-integrity" class="tc-finance-integrity" dir="rtl">'+
  '<h3>🧾 مطابقة سجلات TotiChat المالية</h3>'+
  '<p>صلاحية المالك وشريكه الرئيسي فقط. لا يمكن من هنا تحريك الأموال أو تصفير الماس أو صرف رواتب.</p>'+
  '<p id="tc-finance-integrity-message" role="status"></p>'+
  '<div id="tc-finance-integrity-results"></div>'+
  '<button type="button" data-finance-refresh>إعادة الفحص</button>'+
  '<button type="button" data-a="close">إغلاق</button></section>',true);
 void load();
}
function mount(){
 sync();if(!signed()||screen!=='me')return;
 entry();void authority();
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);mount();return result};
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-finance-inspect],[data-finance-refresh]');
 if(!b)return;
 event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
 if(b.hasAttribute('data-finance-inspect'))open();
 else if(shown()&&signed()&&permitted())void load();
},true);
window.addEventListener('totichat-phase2-auth',()=>{sync();if(signed())mount()});
window.TotiFinanceIntegrity=Object.freeze({isInstalled:()=>true,open});
queueMicrotask(mount);
})();
