/* TotiChat Staging: expose real authorised account/admin controls, preserving
 * approved profile layout. Does not create any sample records or grant roles. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const $=s=>document.querySelector(s);
let user='',authority=null,loading=false,config=null,busy=false;
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
function explain(s){const n=$('[data-backend-status]');if(n)n.textContent=String(s||'').slice(0,250)}
function row(ico,label,action){
 const b=document.createElement('button');b.type='button';b.dataset[action]='';
 b.appendChild(Object.assign(document.createElement('span'),{className:'more-icon',textContent:ico}));
 b.appendChild(Object.assign(document.createElement('span'),{textContent:label}));
 b.appendChild(Object.assign(document.createElement('span'),{className:'chev',textContent:'‹'}));
 return b;
}
function inject(){
 if(!auth.state().signedIn||screen!=='me')return;
 const panel=$('#app .me-more');if(!panel)return;
 const agency=panel.querySelector('[data-a="go"][data-v="agencyPreview"]');
 if(agency){
  agency.removeAttribute('data-a');agency.removeAttribute('data-v');agency.dataset.agenciesOpen='';
  agency.setAttribute('aria-label','فتح طلبات وكالات TotiChat الحقيقية');
 }
 const settings=panel.querySelector('[data-a="go"][data-v="settings"]');
 if(settings){
  settings.removeAttribute('data-a');settings.removeAttribute('data-v');settings.dataset.phase2='account';
  const label=settings.querySelectorAll('span')[1];if(label)label.textContent='أمان الحساب';
 }
 if(!panel.querySelector('[data-support-open]'))panel.appendChild(row('🛟','خدمة العملاء والتذاكر الحقيقية','supportOpen'));
 // Consolidated administration: only the role-verified center entry is shown in Profile.
 // Existing catalog, reports, gifts and DB opening handlers remain available inside it.
 window.TotiInAppAdmin?.onProfile();

}
async function loadAuthority(){
 const id=auth.state().user?.id||'';
 if(!id||loading||authority&&user===id)return;
 loading=true;user=id;authority=null;
 try{
  const role=await rpc('phase3_admin_session',{});
  if(auth.state().user?.id!==id)return;
  authority=role;inject();
 }catch(error){console.warn('TotiChat admin authority:',String(error.message||'forbidden').slice(0,90));}
 finally{loading=false;}
}
const initialRender=render;
render=function(){
 const r=initialRender.apply(this,arguments);
 if(screen==='me'&&auth.state().signedIn){inject();void loadAuthority();}
 return r;
};
async function globalGiftOpen(){
 if(!auth.state().signedIn||!authority?.isOwner&&!authority?.isMainPartner)return;
 showSheet('<section dir="rtl" class="tc-phase2-account-sheet" data-global-gifts-sheet>'+
  '<h3>🎁 إعلانات الهدايا العالمية المؤكدة</h3>'+
  '<p>الإعلان ما يظهر إلا بعد إرسال حقيقي وخصم الكوينز وإضافة الماس، ووفق السعر المعتمد.</p>'+
  '<p data-backend-status role="status">جارٍ تحميل إعدادات الخادم…</p>'+
  '<div data-global-gift-body></div><button class="primary" data-a="close">إغلاق</button></section>',true);
 await refreshGlobal();
}
async function refreshGlobal(){
 const n=$('[data-global-gift-body]'),owner=auth.state().user?.id;
 if(!n||!owner)return;
 try{
  const state=await rpc('phase3_global_gift_admin',{p_action:'read'});
  if(owner!==auth.state().user?.id||!n.isConnected)return;
  if(!Array.isArray(state.gifts))throw Error('بيانات إعدادات غير متوقعة');
  config=state;
  n.innerHTML='<form data-global-config><label><input type="checkbox" name="enabled" '+(state.enabled?'checked':'')+'> تشغيل الإعلانات العالمية</label>'+
   '<label>الحد الأدنى للدعم المؤكد (إجمالي الكوينز في العملية)<input type="number" name="minPrice" min="7000" max="9007199254740991" step="1" required value="'+esc(Math.max(7000,Number(state.minPrice)||7000))+'"></label>'+
   '<button class="primary">حفظ الحد والإتاحة</button></form>'+
   '<h4>الهدايا المؤهلة للإعلان</h4>'+
   state.gifts.map(g=>'<article class="tc-global-gift-row"><span>'+esc(g.name)+' · '+esc(g.price)+' كوين</span>'+
    '<button type="button" data-global-gift-item="'+esc(g.id)+'" data-global-gift-enable="'+!g.global+'">'+
    (g.global?'إيقاف الإعلان':'السماح بالإعلان')+'</button></article>').join('');
  explain(state.enabled?'الإعلانات مفعّلة للأحداث المالية المؤكدة فقط':'الإعلانات متوقفة حالياً');
 }catch(e){explain('تعذّر تحميل الإعدادات: '+String(e.message).slice(0,160));}
}
async function saveConfig(form){
 const enabled=form.elements.enabled.checked;
 const value=String(form.elements.minPrice.value||'').trim();
 const price=Number(value);
 if(!Number.isSafeInteger(price)||price<7000){explain('الحد الأدنى لشريط الدعم هو 7,000 كوينز من عملية حقيقية مؤكدة');return;}
 await rpc('phase3_global_gift_admin',{p_action:'configure',p_enabled:enabled,p_min_price:price});
 await refreshGlobal();explain('تم حفظ إعداد الإعلان على الخادم');
}
async function flagGift(button){
 const enabled=button.dataset.globalGiftEnable==='true',id=button.dataset.globalGiftItem;
 if(!id||!confirm((enabled?'السماح':'إيقاف')+' بإعلان هذه الهدية عالمياً؟'))return;
 await rpc('phase3_global_gift_admin',{p_action:'gift_flag',p_enabled:enabled,p_gift_id:id});
 await refreshGlobal();explain('تم تسجيل التغيير في سجل الإدارة');
}
function hostApprovalOpen(){
 if(!(authority?.role==='db'&&authority?.permissions?.includes('host_agency.open')))return;
 showSheet('<section dir="rtl" class="tc-phase2-account-sheet"><h3>فتح وكالة مضيفين بتفويض</h3>'+
 '<p>هذا الإجراء يوافق على طلب وكالة مضيفين موجود. لا يفتح وكالة شحن ولا يمنح صلاحية إدارة الوكالات.</p>'+
 '<p data-backend-status role="status"></p><form data-host-opening>'+
 '<label>رقم طلب وكالة المضيفين<input name="id" pattern="[0-9a-fA-F-]{36}" maxlength="36" required placeholder="UUID"></label>'+
 '<label>العمولة (%)<input name="commission_percent" type="number" min="0" max="100" step="0.01" required></label>'+
 '<label>ملاحظة المراجعة<textarea name="note" minlength="3" maxlength="500" required></textarea></label>'+
 '<button class="primary" type="submit">الموافقة على افتتاح وكالة المضيفين</button></form>'+
 '<button class="primary" data-a="close">إغلاق</button></section>',true);
}
async function hostApproval(form){
 if(!form.reportValidity())return;
 const id=form.elements.id.value.trim();
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))throw Error('معرف الطلب غير صحيح');
 const commission=Number(form.elements.commission_percent.value);
 if(!Number.isFinite(commission)||commission<0||commission>100)throw Error('العمولة غير صحيحة');
 if(!confirm('تأكيد موافقة افتتاح وكالة مضيفين فقط؟'))return;
 const result=await rpc('phase4_agency_action',{p_action:'approve_registration',p_data:{
  id,commission_percent:commission,note:form.elements.note.value.trim()},p_request_id:crypto.randomUUID()});
 if(!result?.id)throw Error('لم يؤكد الخادم العملية');
 explain('تم افتتاح وكالة المضيفين وتسجيل القرار');
}
document.addEventListener('click',e=>{
 const b=e.target.closest('[data-tc-global-gift-admin],[data-global-gift-item],[data-tc-host-approval]');
 if(!b)return;e.preventDefault();e.stopImmediatePropagation();
 if(b.hasAttribute('data-tc-global-gift-admin')){void globalGiftOpen();return;}
 if(b.hasAttribute('data-tc-host-approval')){hostApprovalOpen();return;}
 if(busy)return;busy=true;b.disabled=true;
 void flagGift(b).catch(err=>explain(err.message)).finally(()=>{busy=false;if(b.isConnected)b.disabled=false;});
},true);
document.addEventListener('submit',e=>{
 const f=e.target;
 if(!f.matches('[data-global-config],[data-host-opening]'))return;
 e.preventDefault();e.stopImmediatePropagation();
 if(busy||!f.reportValidity())return;
 busy=true;const b=f.querySelector('button[type="submit"],button.primary');if(b)b.disabled=true;
 void (f.matches('[data-global-config]')?saveConfig(f):hostApproval(f))
  .catch(err=>explain(err.message)).finally(()=>{busy=false;if(b?.isConnected)b.disabled=false;});
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const id=auth.state().user?.id||'';
 if(id!==user){user='';authority=null;config=null;}
 if(id&&screen==='me')void loadAuthority();
});
// Approved HTML must stay byte-for-byte untouched. Enhance ONLY authenticated
// live-mode sessions with independently tested modules, never demo preview.
const moduleBase=new URL('.',document.currentScript?.src||location.href);
const giftTrayStyle=document.createElement('link');
giftTrayStyle.rel='stylesheet';
giftTrayStyle.href=new URL('phase6-gift-tray.css',moduleBase).href;
document.head.appendChild(giftTrayStyle);
const micPresenceStyle=document.createElement('link');
micPresenceStyle.rel='stylesheet';
micPresenceStyle.href=new URL('phase6-mic-presence.css',moduleBase).href;
document.head.appendChild(micPresenceStyle);
const premiumIconStyle=document.createElement('link');
premiumIconStyle.rel='stylesheet';
premiumIconStyle.href=new URL('phase6-premium-icons.css',moduleBase).href;
document.head.appendChild(premiumIconStyle);
const inAppAdminStyle=document.createElement('link');
inAppAdminStyle.rel='stylesheet';
inAppAdminStyle.href=new URL('phase6-inapp-admin.css',moduleBase).href;
document.head.appendChild(inAppAdminStyle);
const notificationsStyle=document.createElement('link');
notificationsStyle.rel='stylesheet';
notificationsStyle.href=new URL('phase5-notifications-ui.css',moduleBase).href;
document.head.appendChild(notificationsStyle);
const socialStyle=document.createElement('link');
socialStyle.rel='stylesheet';
socialStyle.href=new URL('phase5-social-ui.css',moduleBase).href;
document.head.appendChild(socialStyle);
const identityStyle=document.createElement('link');
identityStyle.rel='stylesheet';
identityStyle.href=new URL('phase5-special-id-ui.css',moduleBase).href;
document.head.appendChild(identityStyle);
const medalStyle=document.createElement('link');
medalStyle.rel='stylesheet';
medalStyle.href=new URL('phase5-medals-ui.css',moduleBase).href;
document.head.appendChild(medalStyle);
const gamesStyle=document.createElement('link');
gamesStyle.rel='stylesheet';
gamesStyle.href=new URL('phase5-room-games-ui.css',moduleBase).href;
document.head.appendChild(gamesStyle);
const soloGameStyle=document.createElement('link');
soloGameStyle.rel='stylesheet';
soloGameStyle.href=new URL('phase5-solo-games-ui.css',moduleBase).href;
document.head.appendChild(soloGameStyle);
const giftHistoryStyle=document.createElement('link');
giftHistoryStyle.rel='stylesheet';
giftHistoryStyle.href=new URL('phase5-gift-history-ui.css',moduleBase).href;
document.head.appendChild(giftHistoryStyle);
const hostReviewStyle=document.createElement('link');
hostReviewStyle.rel='stylesheet';
hostReviewStyle.href=new URL('phase5-host-month-review-ui.css',moduleBase).href;
document.head.appendChild(hostReviewStyle);
const financeAuditStyle=document.createElement('link');
financeAuditStyle.rel='stylesheet';
financeAuditStyle.href=new URL('phase5-finance-integrity-ui.css',moduleBase).href;
document.head.appendChild(financeAuditStyle);
for(const name of ['phase5-notifications-ui.js','phase5-vip-status-ui.js','phase5-social-ui.js','phase5-special-id-ui.js','phase5-medals-ui.js','phase5-room-games-ui.js','phase5-solo-games-ui.js','phase5-gift-history-ui.js','phase5-host-month-review-ui.js','phase5-push-privacy-ui.js','phase5-finance-integrity-ui.js','phase6-inapp-admin.js','phase6-admin-banners.js','phase6-premium-icons.js','phase6-verified-state-sync.js']){
 const script=document.createElement('script');
 script.async=false;
 script.src=new URL(name,moduleBase).href;
 document.body.appendChild(script);
}
})();
