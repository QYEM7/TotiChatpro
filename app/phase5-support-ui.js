/* T42 real support UX: existing Home/Me/VoiceRoom designs stay intact.
 * Does not open host agencies, alter money, or simulate support responses.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||typeof window.render!=='function')return;
const $=s=>document.querySelector(s);
const signed=()=>auth.state().signedIn&&!!window.TotiLiveMode?.enabled;
let busy=false,owner='',lastPage='me';
const validUUID=v=>/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v||'');
function label(status){
 return {submitted:'قيد الاستلام',in_review:'قيد المراجعة',
   needs_information:'مطلوب معلومات',resolved:'تمت المعالجة'}[status]||'غير معروف';
}
function setStatus(t){
 const el=$('[data-t42-status]');if(el){el.textContent=t;el.setAttribute('role','status');}
}
async function refresh(){
 if(!signed())return;
 const user=auth.state().user?.id;
 try{
  const result=await auth.requestData('/rest/v1/support_tickets?select=id,title,category,status,created_at&order=created_at.desc&limit=30');
  if(!Array.isArray(result)||auth.state().user?.id!==user)return;
  const host=$('[data-t42-list]');if(!host)return;
  host.replaceChildren();
  if(!result.length){
   const p=document.createElement('p');p.textContent='ما عندك تذاكر دعم بعد.';
   host.append(p);
  }
  for(const row of result){
   const div=document.createElement('div');div.className='visual-row';
   const name=document.createElement('strong');name.textContent=row.title||'طلب دعم';
   const info=document.createElement('small');info.textContent=' — '+label(row.status);
   div.append(name,info);host.append(div);
  }
  setStatus('تم تحديث طلباتك من الخادم.');
 }catch{setStatus('تعذّر قراءة تذاكر الدعم. أعد المحاولة.');}
}
function open(){
 if(!signed())return;
 showSheet('<div class="t42-support-sheet" dir="rtl">'+
 '<h3>🛟 خدمة عملاء TotiChat</h3>'+
 '<p>تقدر تقدم طلب فتح وكالة مضيفين أو شكوى، وتتابع الرد بالحساب الحقيقي.</p>'+
 '<label>نوع الطلب<select class="field" data-t42-category>'+
 '<option value="general">دعم عام</option>'+
 '<option value="host_agency_application">طلب فتح وكالة مضيفين</option>'+
 '<option value="host_transfer_appeal">اعتراض نقل مضيف</option>'+
 '<option value="abuse_report">بلاغ إساءة</option></select></label>'+
 '<label>عنوان الطلب<input class="field" maxlength="100" data-t42-title placeholder="عنوان واضح"></label>'+
 '<label>بيانات التواصل (مطلوبة لوكالة المضيفين)<input class="field" maxlength="100" data-t42-contact placeholder="وسيلة للتواصل"></label>'+
 '<label>التفاصيل<textarea class="field" maxlength="2000" rows="3" data-t42-description placeholder="اكتب التفاصيل المطلوبة"></textarea></label>'+
 '<button class="primary" type="button" data-t42="submit">إرسال طلب حقيقي</button>'+
 '<button type="button" data-t42="reload">تحديث التذاكر</button>'+
 '<p data-t42-status role="status"></p><h4>طلباتي</h4><div data-t42-list></div>'+
 '<button type="button" data-a="close">إغلاق</button></div>',true);
 void refresh();
}
async function submit(){
 if(busy||!signed())return;
 const area=$('.t42-support-sheet'),user=auth.state().user?.id;if(!area||!validUUID(user))return;
 const category=area.querySelector('[data-t42-category]')?.value;
 const title=area.querySelector('[data-t42-title]')?.value.trim()||'';
 const description=area.querySelector('[data-t42-description]')?.value.trim()||'';
 const contact=area.querySelector('[data-t42-contact]')?.value.trim()||'';
 if(title.length<3||title.length>100||description.length<10||description.length>2000||
 (category==='host_agency_application'&&(title.length<3||contact.length<3))){
  setStatus('أكمل عنوان الطلب، وشرحاً من 10 أحرف على الأقل، ووسيلة تواصل عند طلب الوكالة.');return;
 }
 const req=crypto.randomUUID();
 busy=true;setStatus('جاري إرسال الطلب إلى الخادم…');
 try{
  const data=await auth.requestData('/rest/v1/rpc/phase5_support_create',{
   method:'POST',body:{
    p_category:category,p_title:title,p_body:description,
    p_details:category==='host_agency_application'?{agency_name:title,contact}:{},
    p_request_id:req
   }
  });
  if(!data?.id||data.status!=='submitted')throw Error('الخادم لم يؤكد إرسال طلب الدعم');
  if(auth.state().user?.id!==user)return;
  setStatus('تم تسجيل التذكرة رسمياً برقم '+String(data.id).slice(0,8)+'.');
  area.querySelector('[data-t42-title]').value='';
  area.querySelector('[data-t42-description]').value='';
  area.querySelector('[data-t42-contact]').value='';
  await refresh();
 }catch(err){
  setStatus('فشل تسجيل الطلب الحقيقي: '+String(err.message||'خطأ بالخادم').slice(0,90));
 }finally{busy=false}
}
function mount(){
 if(!signed()||screen!=='me')return;
 const area=$('.me-royal')||$('#app .main');if(!area)return;
 if(area.querySelector('[data-t42="open"]'))return;
 const row=document.createElement('div');row.className='t42-support-entry';
 const b=document.createElement('button');b.type='button';b.dataset.t42='open';
 b.className='listrow';b.textContent='🛟 خدمة العملاء وطلبات الوكالات';
 row.append(b);area.append(row);
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);mount();return result;};
document.addEventListener('click',e=>{
 const btn=e.target?.closest?.('[data-t42]');if(!btn||!signed())return;
 e.preventDefault();e.stopImmediatePropagation();
 if(btn.dataset.t42==='open')open();
 else if(btn.dataset.t42==='submit')void submit();
 else if(btn.dataset.t42==='reload')void refresh();
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 if(auth.state().user?.id!==owner){owner=auth.state().user?.id||'';busy=false;}
});
queueMicrotask(mount);
window.TotiPhase5Support=Object.freeze({isInstalled:()=>true});
})();
