/* Approved UI enhancement: real Owner-only special public ID approval, never preview. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!window.TotiLiveMode?.enabled||!auth)return;
const $=s=>document.querySelector(s);
const valid=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
let user='',epoch=0,loaded=0,code=null,loading=false,isOwner=false,ownerChecked=0,busy=false;
function signed(){return auth.state().signedIn===true&&auth.state().user?.id===user}
function identity(){
 const id=auth.state().user?.id||'';
 if(id===user)return;
 user=id;epoch++;loaded=0;code=null;loading=false;isOwner=false;ownerChecked=0;busy=false;
}
function renderIdentity(){
 if(!signed()||!['me','profilePreview'].includes(screen))return;
 const mark=code?'ID مميز: '+code:'حساب TotiChat · ID: '+user.slice(0,8).toUpperCase();
 const me=$('.me-summary .muted-id');
 const profile=$('.pr-person-meta .pr-minor');
 if(screen==='me'&&me)me.textContent=mark;
 if(screen==='profilePreview'&&profile)profile.textContent=mark;
}
async function refresh(force=false){
 if(!signed()||loading||(!force&&Date.now()-loaded<25000))return;
 loading=true;const ref=user,stamp=epoch;
 try{
  const result=await rpc('phase5_special_id_status',{p_target:ref});
  if(stamp!==epoch||!signed()||ref!==user)return;
  if(!result||result.userId!==ref||typeof result.assigned!=='boolean'
   ||result.assigned&&!(typeof result.publicId==='string'&&/^[1-9][0-9]{3,9}$/.test(result.publicId)))
   throw Error('Untrusted identity response');
  code=result.assigned?result.publicId:null;loaded=Date.now();renderIdentity();
 }catch(_){
  if(stamp===epoch&&signed()){code=null;loaded=Date.now();renderIdentity()}
 }finally{if(stamp===epoch)loading=false}
}
function adminButton(){
 if(window.TotiInAppAdmin)return; // Centralized Owner controls in Admin Center.
 if(!signed()||screen!=='me'||!isOwner)return;
 const panel=$('#app .me-more');if(!panel||panel.querySelector('[data-tc-special-id-open]'))return;
 const b=document.createElement('button');b.type='button';b.dataset.tcSpecialIdOpen='';
 b.setAttribute('aria-label','منح معرف مميز للحسابات بعد مراجعة المالك');
 for(const [cls,txt] of [['more-icon','🪪'],['','منح ID مميز'],['chev','‹']]){
  const span=document.createElement('span');if(cls)span.className=cls;span.textContent=txt;
  b.append(span);
 }
 panel.append(b);
}
async function inspectAuthority(force=false){
 if(!signed()||(!force&&Date.now()-ownerChecked<60000))return;
 const uid=user,stamp=epoch;ownerChecked=Date.now();
 try{
  const result=await rpc('phase3_admin_session',{});
  if(stamp!==epoch||uid!==user||!signed())return;
  isOwner=result?.isOwner===true;
  adminButton();
 }catch(_){if(stamp===epoch)isOwner=false}
}
function open(){
 if(!signed()||!isOwner)return;
 showSheet('<section dir="rtl" class="tc-special-id-form" id="tc-special-id-sheet">'+
 '<h3>🪪 اعتماد ID مميز</h3>'+
 '<p>للمالك الرئيسي فقط. الرقم فريد ونهائي؛ لا ينقل ملكية الحساب ولا يستبدل UUID الداخلي.</p>'+
 '<p id="tc-special-id-status" role="status"></p>'+
 '<form id="tc-special-id-grant"><label>معرّف الحساب الداخلي UUID<input name="target" maxlength="36" required></label>'+
 '<label>الـID المميز (4–10 أرقام ولا يبدأ بصفر)<input name="code" inputmode="numeric" pattern="[1-9][0-9]{3,9}" maxlength="10" required></label>'+
 '<label>سبب المراجعة والاعتماد<textarea name="reason" minlength="10" maxlength="300" required></textarea></label>'+
 '<button type="submit">اعتماد نهائي</button></form>'+
 '<button type="button" data-a="close">إغلاق</button></section>',true);
}
async function grant(form){
 if(!signed()||!isOwner||busy||!form.reportValidity())return;
 const target=form.elements.target.value.trim();
 const publicId=form.elements.code.value.trim();
 const reason=form.elements.reason.value.trim();
 if(!valid(target)||!/^[1-9][0-9]{3,9}$/.test(publicId)||reason.length<10||reason.length>300){
  const status=$('#tc-special-id-status');if(status)status.textContent='تحقق من بيانات الحساب والسبب';return;
 }
 if(!window.confirm('تنبيه: اعتماد ID مميز نهائي ولا يمكن تغييره. هل توافق؟'))return;
 busy=true;const id=user,stamp=epoch;
 const button=form.querySelector('button[type="submit"]');if(button)button.disabled=true;
 const label=$('#tc-special-id-status');if(label)label.textContent='جارٍ اعتماد القرار على الخادم…';
 try{
  const result=await rpc('phase5_special_id_grant',{
   p_target:target,p_public_id:publicId,p_reason:reason,p_request_id:crypto.randomUUID()
  });
  if(stamp!==epoch||id!==user||!signed())return;
  if(result?.publicId!==publicId||result?.userId!==target||result?.success!==true)
   throw Error('الخادم لم يؤكد الاعتماد');
  if(label)label.textContent='تم اعتماد ID المميز وتوثيق القرار. لا يمكن تغييره.';
  if(target===user)void refresh(true);
 }catch(e){
  if(stamp===epoch&&label)label.textContent='لم يتم الاعتماد: '+String(e.message||'خطأ').slice(0,110);
 }finally{busy=false;if(button?.isConnected)button.disabled=false}
}
function mount(){
 identity();
 if(!signed())return;
 renderIdentity();
 if(['me','profilePreview'].includes(screen))void refresh();
 if(screen==='me'){adminButton();void inspectAuthority()}
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);mount();return result};
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-tc-special-id-open]');
 if(!b)return;
 event.preventDefault();event.stopImmediatePropagation();open();
},true);
document.addEventListener('submit',event=>{
 if(event.target?.id!=='tc-special-id-grant')return;
 event.preventDefault();event.stopImmediatePropagation();
 void grant(event.target);
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 identity();if(signed())mount();
});
window.addEventListener('focus',()=>{if(signed())void refresh(true)});
window.TotiSpecialId=Object.freeze({refresh:()=>refresh(true),isInstalled:()=>true});
queueMicrotask(mount);
})();
