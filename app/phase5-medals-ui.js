/* Real medal entitlements: only awarded, server-persisted achievements are shown.
 * No preview badges, reward rules, coins, XP, or unapproved cosmetic redesign.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const validUUID=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
const safeKey=s=>/^[a-z][a-z0-9_-]{2,39}$/.test(s||'');
const rpc=(name,data)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body:data});
const el=(tag,label,cls)=>{
 const node=document.createElement(tag);
 node.textContent=String(label??'');
 if(cls)node.className=cls;
 return node;
};
let owner='',epoch=0,loaded=0,items=[],pending=false,failed=false;
let approvedOwner=false,checkingOwner=false,ownerChecked=0,busy=false;
function signed(){return auth.state().signedIn===true&&auth.state().user?.id===owner}
function show(){return Boolean($('#tc-medal-owner-sheet')&&$('#overlay')?.classList.contains('show'))}
function reidentify(){
 const id=auth.state().user?.id||'';
 if(id===owner)return;
 if(show())closeSheet();
 owner=id;epoch++;loaded=0;items=[];pending=false;failed=false;
 approvedOwner=false;checkingOwner=false;ownerChecked=0;busy=false;
}
function paint(){
 if(!signed()||screen!=='profilePreview')return;
 const body=$('.pr-display-items');
 if(!body)return;
 body.replaceChildren();
 if(failed){
  body.append(el('p','تعذّر التحقق من ميدالياتك. حدّث الصفحة لإعادة المحاولة.','tc-phase2-live-empty'));
  return;
 }
 if(pending&&!loaded){
  body.append(el('p','جارٍ تحميل الميداليات المكتسبة من الخادم…','tc-phase2-live-empty'));
  return;
 }
 if(!items.length){
  body.append(el('p','لا توجد ميداليات مكتسبة بحسابك حالياً.','tc-phase2-live-empty'));
  return;
 }
 for(const award of items){
  const card=document.createElement('article');card.className='tc-live-medal';
  card.setAttribute('aria-label','ميدالية مكتسبة: '+award.display_name);
  const art=el('span','🏅','pr-art tc-live-medal-icon');
  const caption=el('strong',award.display_name,'caption');
  card.append(art,caption);
  if(award.description)card.append(el('small',award.description,'tc-live-medal-desc'));
  body.append(card);
 }
}
async function load(force=false){
 if(!signed()||screen!=='profilePreview'||pending||(!force&&loaded&&Date.now()-loaded<30000))return;
 pending=true;failed=false;const ref=owner,stamp=epoch;
 paint();
 try{
  const result=await rpc('phase5_medal_user',{p_target:ref});
  if(stamp!==epoch||ref!==owner||!signed())return;
  if(!result||result.userId!==ref||!Array.isArray(result.items)||result.items.length>100||
     result.items.some(x=>!safeKey(x.medal_key)||
       typeof x.display_name!=='string'||x.display_name.length>60||
       typeof x.description!=='string'||x.description.length>180))
    throw Error('Invalid medal entitlement response');
  items=result.items;loaded=Date.now();failed=false;
 }catch(_){
  if(stamp===epoch&&signed()){items=[];loaded=Date.now();failed=true}
 }finally{
  if(stamp===epoch){pending=false;paint()}
 }
}
function ownerEntry(){
 if(!signed()||screen!=='me'||!approvedOwner)return;
 const panel=$('#app .me-more');
 if(!panel||panel.querySelector('[data-tc-medal-owner]'))return;
 const button=document.createElement('button');
 button.type='button';button.dataset.tcMedalOwner='';
 button.setAttribute('aria-label','إدارة الميداليات بموافقة المالك فقط');
 for(const [cls,caption] of [['more-icon','🏅'],['','اعتماد الميداليات'],['chev','‹']])
  button.append(el('span',caption,cls));
 panel.append(button);
}
async function verifyOwner(){
 if(!signed()||screen!=='me'||checkingOwner||Date.now()-ownerChecked<60000)return;
 checkingOwner=true;const ref=owner,stamp=epoch;ownerChecked=Date.now();
 try{
  const result=await rpc('phase3_admin_session',{});
  if(stamp!==epoch||!signed()||ref!==owner)return;
  approvedOwner=result?.isOwner===true;
  ownerEntry();
 }catch(_){if(stamp===epoch)approvedOwner=false}
 finally{if(stamp===epoch)checkingOwner=false}
}
const status=message=>{
 const text=$('#tc-medal-action-status');
 if(text)text.textContent=String(message||'').slice(0,190);
};
function openOwner(){
 if(!signed()||!approvedOwner||typeof showSheet!=='function')return;
 showSheet('<section id="tc-medal-owner-sheet" class="tc-medal-owner" dir="rtl">'+
 '<h3>🏅 اعتماد ميداليات TotiChat</h3>'+
 '<p>صلاحية المالك الرئيسي فقط؛ لا تُمنح ميداليات أو مزايا أو أرصدة تلقائياً.</p>'+
 '<p id="tc-medal-action-status" role="status"></p>'+
 '<form id="tc-medal-approve-form">'+
 '<label>العملية<select name="kind"><option value="register">تعريف ميدالية</option>'+
 '<option value="grant">منح ميدالية</option><option value="revoke">سحب ميدالية</option></select></label>'+
 '<label>كود الميدالية<input name="key" pattern="[a-z][a-z0-9_-]{2,39}" required maxlength="40" placeholder="approved_medal"></label>'+
 '<label>اسم الميدالية (عند التعريف)<input name="label" maxlength="60" placeholder="اسم معتمد"></label>'+
 '<label>وصف الميدالية (عند التعريف)<textarea name="description" maxlength="180"></textarea></label>'+
 '<label>معرف المستخدم UUID (عند المنح أو السحب)<input name="target" maxlength="36" placeholder="UUID"></label>'+
 '<label>سبب القرار الموثق<textarea name="reason" minlength="10" maxlength="300" required></textarea></label>'+
 '<button type="submit">تأكيد القرار على الخادم</button></form>'+
 '<button type="button" data-a="close">إغلاق</button></section>',true);
}
async function ownerAction(form){
 if(!signed()||!approvedOwner||busy||!form.reportValidity())return;
 const kind=String(form.elements.kind.value||'');
 const key=String(form.elements.key.value||'').trim();
 const reason=String(form.elements.reason.value||'').trim();
 const label=String(form.elements.label.value||'').trim();
 const description=String(form.elements.description.value||'').trim();
 const target=String(form.elements.target.value||'').trim();
 if(!['register','grant','revoke'].includes(kind)||!safeKey(key)||
    reason.length<10||reason.length>300)return status('تأكد من كود الميدالية وسبب الموافقة');
 if(kind==='register'&&(label.length<3||label.length>60||description.length>180))
  return status('اسم الميدالية مطلوب من 3 إلى 60 حرفاً');
 if(kind!=='register'&&!validUUID(target))return status('معرف المستفيد UUID غير صالح');
 if(!window.confirm('هذه عملية إدارية حقيقية تسجل في سجل التدقيق. هل تؤكد الموافقة؟'))return;
 const button=form.querySelector('button[type="submit"]');
 const ref=owner,stamp=epoch;
 busy=true;if(button)button.disabled=true;
 status('جارٍ تنفيذ قرارك على الخادم…');
 try{
  const result=await rpc('phase5_medal_owner_action',{
   p_action:kind,p_medal_key:key,p_target:kind==='register'?null:target,
   p_label:kind==='register'?label:null,
   p_description:kind==='register'?description:null,
   p_reason:reason,p_request_id:crypto.randomUUID()
  });
  if(stamp!==epoch||ref!==owner||!signed())return;
  if(result?.success!==true||result.medalKey!==key||result.action!==kind)
   throw Error('الخادم لم يؤكد تسجيل القرار');
  status('تم توثيق القرار الإداري بنجاح');
  if(target===owner){loaded=0;void load(true)}
 }catch(e){if(stamp===epoch)status('لم يتم الاعتماد: '+String(e.message).slice(0,120))}
 finally{busy=false;if(button?.isConnected)button.disabled=false}
}
function mount(){
 reidentify();
 if(!signed())return;
 if(screen==='profilePreview'){paint();void load()}
 if(screen==='me'){ownerEntry();void verifyOwner()}
}
const prev=window.render;
window.render=function(){const output=prev.apply(this,arguments);mount();return output};
document.addEventListener('click',event=>{
 const button=event.target?.closest?.('[data-tc-medal-owner]');
 if(!button)return;
 event.preventDefault();event.stopImmediatePropagation();
 openOwner();
},true);
document.addEventListener('submit',event=>{
 if(event.target?.id!=='tc-medal-approve-form')return;
 event.preventDefault();event.stopImmediatePropagation();
 void ownerAction(event.target);
},true);
window.addEventListener('totichat-phase2-auth',()=>{reidentify();if(signed())mount()});
window.addEventListener('focus',()=>{
 if(signed()&&screen==='profilePreview')void load(true);
});
window.TotiMedals=Object.freeze({refresh:()=>load(true),isInstalled:()=>true});
queueMicrotask(mount);
})();
