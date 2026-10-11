/* TotiChat T57: real Staging notification inbox; no example events or fabricated counts.
 * Hooks only an additional entry in approved Profile UI, preserving original artwork.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const labels=Object.freeze({
 vip_granted:'تم تفعيل مستوى VIP على حسابك',
 vip_revoked:'تم إيقاف مستوى VIP',
 room_moderator_granted:'تم تعيينك مشرفاً بالغرفة',
 room_moderator_revoked:'تم إنهاء صلاحية الإشراف',
 room_kicked:'تم إخراجك من الغرفة',
 room_banned:'تم حظرك من الغرفة',
 room_unbanned:'تم رفع الحظر عن الغرفة',
 room_muted:'تم كتم المايك إدارياً',
 room_mic_allowed:'تم رفع منع تشغيل المايك',
 room_seat_released:'تم تحرير مقعدك',
 support_staff_replied:'لديك رد جديد من خدمة العملاء',
 medal_granted:'حصلت على ميدالية معتمدة',
 medal_revoked:'تم سحب ميدالية من حسابك'
});
let owner='',epoch=0,loading=false,items=[],unread=0,before=null,end=false;
function active(){
 return auth.state().signedIn===true&&auth.state().user?.id===owner;
}
function show(){return $('#t57-real-inbox')&&$('#overlay')?.classList.contains('show')}
function text(tag,value,cls){
 const node=document.createElement(tag);node.textContent=String(value??'');
 if(cls)node.className=cls;
 return node;
}
function message(s){
 const status=$('#t57-inbox-status');if(status)status.textContent=String(s||'').slice(0,180);
}
function entry(){
 if(!auth.state().signedIn||screen!=='me')return;
 const panel=$('#app .me-more');if(!panel||panel.querySelector('[data-t57-open]'))return;
 const button=document.createElement('button');
 button.type='button';button.dataset.t57Open='';
 button.setAttribute('aria-label','فتح إشعارات حسابك الحقيقية');
 const icon=text('span','🔔','more-icon');
 const name=text('span','الإشعارات الحقيقية');
 const count=text('span','','t57-more-count');count.dataset.t57Count='';
 const chev=text('span','‹','chev');
 button.append(icon,name,count,chev);
 panel.append(button);
 if(unread>0&&owner===auth.state().user?.id)
  count.textContent=unread>99?'99+':String(unread);
}
function showCount(){
 const badge=$('[data-t57-count]');
 if(badge)badge.textContent=unread>0?(unread>99?'99+':String(unread)):'';
}
function format(entry){
 const row=document.createElement('article');
 row.className='t57-event'+(entry.read_at?'':' t57-event-unread');
 const heading=text('strong',labels[entry.event_type]||'تحديث جديد في حسابك');
 const date=entry.created_at?new Date(entry.created_at):null;
 const when=text('small',date&&Number.isFinite(date.getTime())?
  date.toLocaleString('ar-IQ',{dateStyle:'medium',timeStyle:'short'}):'');
 row.append(heading,when);
 if(entry.event_type.startsWith('vip_')&&
  Number.isInteger(entry.context?.tier)&&entry.context.tier>=1&&entry.context.tier<=10)
  row.append(text('p','VIP '+entry.context.tier));
 if(entry.event_type==='support_staff_replied')row.append(
  text('p','افتح خدمة العملاء للاطلاع على الرد داخل تذكرتك.'));
 if(entry.read_at===null){
  const mark=text('button','تعليم كمقروء');mark.type='button';
  mark.dataset.t57Mark=String(entry.id);mark.className='t57-mark';
  row.append(mark);
 }
 return row;
}
function paint(){
 if(!show()||!active())return;
 const list=$('#t57-inbox-list'),summary=$('#t57-inbox-summary'),more=$('[data-t57-more]');
 if(!list||!summary)return;
 summary.textContent=unread>0?'غير مقروء: '+unread:'ما عندك إشعارات غير مقروءة';
 list.replaceChildren();
 if(!items.length)list.append(text('p','ما وصلت أي إشعارات حقيقية إلى حسابك بعد.','t57-empty'));
 else items.forEach(item=>list.append(format(item)));
 if(more)more.hidden=end||items.length===0;
 showCount();
}
function validate(data){
 if(!data||!Array.isArray(data.items)||data.items.length>30||
   !Number.isSafeInteger(data.unreadCount)||data.unreadCount<0)
  throw Error('صيغة الإشعارات من الخادم غير متوقعة');
 for(const item of data.items){
  if(!Number.isSafeInteger(item.id)||item.id<1||
    typeof item.event_type!=='string'||item.event_type.length>50)
   throw Error('بيانات إشعار غير صالحة');
 }
}
async function load(reset=false){
 if(!show()||!active()||loading)return;
 loading=true;const user=owner,stamp=epoch;
 const cursor=reset?null:before;
 message('جارٍ جلب إشعاراتك من الخادم…');
 try{
  const data=await auth.requestData('/rest/v1/rpc/phase5_notification_feed',{
   method:'POST',body:{p_limit:30,p_before:cursor}
  });
  if(stamp!==epoch||auth.state().user?.id!==user||!show())return;
  validate(data);
  items=reset?data.items:items.concat(data.items.filter(i=>!items.some(o=>o.id===i.id)));
  unread=data.unreadCount;end=data.items.length<30;
  before=data.items.length?data.items[data.items.length-1].id:cursor;
  paint();message('');
 }catch(error){
  if(stamp===epoch&&active()&&show())
   message('تعذّر تحميل الإشعارات: '+String(error.message||'خطأ اتصال').slice(0,115));
 }finally{loading=false}
}
async function mark(ids,all){
 if(!show()||!active()||loading)return;
 loading=true;const stamp=epoch,user=owner;
 message('جارٍ تحديث القراءة…');
 try{
  const result=await auth.requestData('/rest/v1/rpc/phase5_notification_mark',{
   method:'POST',body:{p_ids:ids,p_all:all}
  });
  if(stamp!==epoch||user!==auth.state().user?.id||!show())return;
  if(!Number.isSafeInteger(result?.updated)||result.updated<0)
   throw Error('الخادم لم يؤكد القراءة');
  items=[];before=null;end=false;
 }catch(e){
  if(stamp===epoch&&show())message('تعذّر حفظ القراءة: '+String(e.message).slice(0,110));
  return;
 }finally{loading=false}
 void load(true);
}
function open(){
 const id=auth.state().user?.id;if(!id||typeof showSheet!=='function')return;
 owner=id;epoch++;loading=false;items=[];unread=0;before=null;end=false;
 showSheet('<section id="t57-real-inbox" dir="rtl" class="t57-inbox" role="region" aria-label="الإشعارات الحقيقية">'+
  '<header><h3>🔔 إشعارات TotiChat</h3><button type="button" data-a="close" aria-label="إغلاق">✕</button></header>'+
  '<p id="t57-inbox-summary">تُعرض الإشعارات المحفوظة بحسابك فقط</p>'+
  '<p id="t57-inbox-status" role="status"></p>'+
  '<div class="t57-actions"><button type="button" data-t57-reload>تحديث</button>'+
  '<button type="button" data-t57-mark-all>تعليم الكل كمقروء</button></div>'+
  '<div id="t57-inbox-list"></div>'+
  '<button type="button" data-t57-more hidden>عرض إشعارات أقدم</button></section>',true);
 void load(true);
}
const prev=window.render;
window.render=function(){
 const response=prev.apply(this,arguments);
 entry();
 return response;
};
document.addEventListener('click',event=>{
 const button=event.target?.closest?.('[data-t57-open],[data-t57-reload],[data-t57-more],[data-t57-mark],[data-t57-mark-all]');
 if(!button||!auth.state().signedIn)return;
 event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
 if(button.hasAttribute('data-t57-open')){open();return}
 if(!show()||!active())return;
 if(button.hasAttribute('data-t57-reload'))void load(true);
 else if(button.hasAttribute('data-t57-more'))void load();
 else if(button.hasAttribute('data-t57-mark-all'))void mark([],true);
 else if(button.hasAttribute('data-t57-mark')){
  const id=Number(button.dataset.t57Mark);
  if(Number.isSafeInteger(id)&&id>0)void mark([id],false);
 }
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const id=auth.state().user?.id||'';
 if(id!==owner){
  epoch++;owner=id;items=[];unread=0;before=null;end=false;
  if(show())closeSheet();
  showCount();
 }
});
document.addEventListener('visibilitychange',()=>{
 if(!document.hidden&&show()&&active())void load(true);
});
setInterval(()=>{
 if(document.hidden||!show()||!active()||loading)return;
 void load(true);
},15000);
window.TotiNotifications=Object.freeze({open,refresh:()=>load(true),isInstalled:()=>true});
queueMicrotask(entry);
})();
