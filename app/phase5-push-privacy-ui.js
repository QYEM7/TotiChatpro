/* TotiChat staging-only: real push consent, never pretend Android push is configured. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const rpc=(n,b)=>auth.requestData('/rest/v1/rpc/'+n,{method:'POST',body:b});
let user='',epoch=0,requestId=0,busy=false,current=null;
const signed=()=>auth.state().signedIn===true&&auth.state().user?.id===user;
const showing=()=>!!$('#tc-push-privacy')&&!!$('#overlay')?.classList.contains('show');
function message(s){const n=$('[data-push-message]');if(n)n.textContent=String(s||'').slice(0,220);}
function sync(){
 const id=auth.state().signedIn===true?auth.state().user?.id||'':'';
 if(id===user)return;
 user=id;epoch++;requestId++;busy=false;current=null;
 if(showing()&&typeof closeSheet==='function')closeSheet();
}
function entry(){
 sync();
 if(!signed()||screen!=='me')return;
 const panel=$('#app .me-more');
 if(!panel||panel.querySelector('[data-push-open]'))return;
 const b=document.createElement('button');b.type='button';b.dataset.pushOpen='';
 b.setAttribute('aria-label','إدارة خصوصية إشعارات الهاتف');
 for(const [value,cls] of [['🛡️','more-icon'],['خصوصية إشعارات الهاتف',''],['‹','chev']]){
  const s=document.createElement('span');s.textContent=value;if(cls)s.className=cls;b.appendChild(s);
 }
 panel.appendChild(b);
}
function paint(){
 if(!signed()||!showing())return;
 const s=$('[data-push-state]'),d=$('[data-push-delivery]'),
  devices=$('[data-push-devices]'),yes=$('[data-push-enable]'),no=$('[data-push-disable]');
 if(s)s.textContent=current?(current.pushEnabled?'الموافقة محفوظة بحسابك':'الموافقة غير مفعّلة'):'لم نتأكد بعد من حسابك';
 if(d)d.textContent=current?.deliveryConfigured===true?
  'الخادم يشير إلى تهيئة التسليم؛ يلزم اختبار جهازك':
  'خدمة إرسال إشعارات الهاتف غير مهيأة. لن تصل إشعارات خارج التطبيق.';
 if(devices)devices.textContent=current?'أجهزة حسابك المسجلة: '+current.devices.length:'حالة الأجهزة غير متاحة';
 if(yes)yes.disabled=busy||!current||current.pushEnabled;
 if(no)no.disabled=busy||!current||!current.pushEnabled;
}
function valid(data,id){
 return !!(data&&data.userId===id&&typeof data.pushEnabled==='boolean'&&
  typeof data.deliveryConfigured==='boolean'&&Array.isArray(data.devices)&&
  data.devices.length<=5&&data.devices.every(d=>d&&
   typeof d.device_id==='string'&&/^[0-9a-f-]{36}$/i.test(d.device_id)&&
   !Object.prototype.hasOwnProperty.call(d,'token_value')&&
   !Object.prototype.hasOwnProperty.call(d,'token_digest')));
}
async function refresh(){
 if(!signed()||!showing()||busy)return;
 const id=user,stamp=epoch,seq=++requestId;
 message('جارٍ قراءة تفضيلاتك من الخادم…');
 try{
  const value=await rpc('phase5_push_status',{});
  if(stamp!==epoch||seq!==requestId||!signed()||!showing())return;
  if(!valid(value,id))throw Error('رد الخادم غير صالح');
  current=value;paint();message('');
 }catch(e){
  if(stamp!==epoch||seq!==requestId||!signed()||!showing())return;
  current=null;paint();
  message('تعذر جلب حالة الإشعارات: '+String(e.message||'خطأ اتصال').slice(0,100));
 }
}
async function consent(enabled){
 if(!signed()||!showing()||busy||!current||current.pushEnabled===enabled)return;
 if(enabled&&typeof confirm==='function'&&!confirm(
  'تريد حفظ الموافقة على إشعارات الهاتف مستقبلاً؟ لا يوجد إرسال FCM حالي ولا تسجيل جهاز تلقائي.'))return;
 const id=user,stamp=epoch;
 busy=true;requestId++;paint();message('جارٍ حفظ خيارك…');
 try{
  const result=await rpc('phase5_push_opt_in',{p_enabled:enabled});
  if(stamp!==epoch||!signed()||!showing())return;
  if(!result||result.userId!==id||result.pushEnabled!==enabled)
   throw Error('الخادم لم يؤكد التغيير');
  current={...current,pushEnabled:enabled,devices:enabled?current.devices:[],
   deliveryConfigured:result.deliveryConfigured===true};
  message('تم حفظ الخيار على الخادم');paint();
 }catch(e){
  if(stamp===epoch&&signed()&&showing())
   message('تعذر حفظ الموافقة: '+String(e.message||'خطأ اتصال').slice(0,95));
 }finally{
  if(stamp===epoch){busy=false;paint();}
 }
}
function open(){
 sync();if(!signed()||typeof showSheet!=='function')return;
 current=null;requestId++;
 showSheet('<section id="tc-push-privacy" dir="rtl" class="tc-phase2-account-sheet" aria-label="خصوصية إشعارات الهاتف">'+
  '<h3>🛡️ خصوصية إشعارات الهاتف</h3>'+
  '<p>تفضيل حقيقي محفوظ في حسابك. لا يتم إرسال إشعارات ولا تسجيل رمز هاتف تلقائياً.</p>'+
  '<p data-push-state>جارٍ جلب الحالة…</p><p data-push-delivery></p><p data-push-devices></p>'+
  '<p data-push-message role="status" aria-live="polite"></p>'+
  '<button type="button" class="primary" data-push-enable disabled>الموافقة على الإشعارات مستقبلاً</button>'+
  '<button type="button" data-push-disable disabled>إلغاء الموافقة وحذف رموز أجهزتي</button>'+
  '<button type="button" data-push-refresh>تحديث</button>'+
  '<button type="button" data-a="close">إغلاق</button></section>',true);
 void refresh();
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);entry();return result;};
document.addEventListener('click',e=>{
 const b=e.target?.closest?.('[data-push-open],[data-push-enable],[data-push-disable],[data-push-refresh]');
 if(!b)return;
 e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
 if(b.hasAttribute('data-push-open')){open();return;}
 if(!signed()||!showing())return;
 if(b.hasAttribute('data-push-enable'))void consent(true);
 if(b.hasAttribute('data-push-disable'))void consent(false);
 if(b.hasAttribute('data-push-refresh'))void refresh();
},true);
window.addEventListener('totichat-phase2-auth',()=>{sync();entry();});
window.TotiPushPrivacy=Object.freeze({open,refresh});
queueMicrotask(entry);
})();
