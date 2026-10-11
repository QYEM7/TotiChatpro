/* TotiChat Phase 2 — truthful beta entry. Android opens the REAL account
 * flow by default, never the old sample-home as if it were live data.
 * Approved design remains untouched; preview is an EXPLICIT user choice.
 */
(function(){
'use strict';
const params=new URLSearchParams(location.search);
const isNative=(location.protocol==='https:'&&location.hostname==='localhost')||
  !!window.Capacitor?.isNativePlatform?.();
const enabled=params.get('mode')==='live'||isNative;
// URL query parameters must never bypass the live account flow in a native build.
// Deliberate design-preview entry remains available through the labelled login UI.
if(!enabled)return;
const auth=window.TotiPhase2Auth;
if(!auth||typeof window.render!=='function'){
  // Do not silently treat backend failures as demo success.
  document.body.insertAdjacentHTML('afterbegin','<div role="alert" style="padding:20px;background:#431953;color:white">تعذّر بدء اتصال TotiChat الحقيقي. أعد تشغيل التطبيق بعد الاتصال بالإنترنت.</div>');
  return;
}
document.documentElement.classList.add('tc-live-visual-identity');
let explicitPreview=false;
const authScreens=new Set(['loginPreview','signupPreview','verifyAccountPreview','passwordResetPreview']);
const allowed=new Set(['home','me','room','wallet','profilePreview','profileEdit','storePreview','rechargePreview','cp','giftsPreview','musicPreview',...authScreens]);
const $=(q,root=document)=>root.querySelector(q);
const $$=(q,root=document)=>Array.from(root.querySelectorAll(q));
let lastNotice='';
function warn(text){
  const msg=text||'هذه الوظيفة قيد الربط بالخادم، ولن نعرض بيانات تجريبية على أنها حقيقية.';
  if(msg!==lastNotice){lastNotice=msg;if(typeof showToast==='function')showToast(msg);}
  setTimeout(()=>{lastNotice='';},1200);
}
function live(){return auth.state().signedIn;}
function banner(parent,id,text,action,buttonText){
  if(!parent||document.getElementById(id))return;
  const bar=document.createElement('aside');
  bar.id=id;bar.className='tc-phase2-live-banner';
  bar.setAttribute('role','status');
  const caption=document.createElement('span');caption.textContent=text;bar.appendChild(caption);
  if(action){
    const button=document.createElement('button');button.type='button';button.dataset.liveEntry=action;
    button.textContent=buttonText;bar.appendChild(button);
  }
  parent.prepend(bar);
}
function protectIdentity(){
  if(!live())return;
  const state=auth.state(), profile=state.profile;
  if(screen==='me'){
    $$('.me-agency').forEach(e=>e.remove()); // Old demo agency is not a real membership.
    const badge=$('.me-vip-banner strong');
    if(badge)badge.textContent='👑 VIP · لم يُفعّل';
  }
  if(screen==='profilePreview'){
    const id=$('.pr-person-meta .pr-minor');
    if(id)id.textContent='حساب حقيقي · '+state.user.id.slice(0,8).toUpperCase();
    const heading=$('.pr-person-meta h1');
    if(heading){
      const name=profile?.display_name||'مستخدم جديد';
      heading.textContent=name;
    }
    const badges=$('.pr-person-meta .pr-vipstrip');
    if(badges)badges.textContent='👑 VIP قيد الربط · 💠 المستوى قيد الربط';
    $$('.pr-numbers button strong').forEach(e=>e.textContent='—');
    $$('.pr-agencywide').forEach(e=>e.remove());
    const about=$('.pr-about');
    if(about)about.textContent=profile?.bio||'لا توجد نبذة شخصية بعد';
    const gifts=$('.pr-event span');
    if(gifts)gifts.textContent='الهدايا والمكافآت · قيد الربط بالحساب';
    const inventory=$('.pr-display-items');
    if(inventory){
      inventory.replaceChildren();
      const empty=document.createElement('p');
      empty.className='tc-phase2-live-empty';
      empty.textContent='لا توجد مقتنيات مرتبطة بحسابك بعد. نظام الحقيبة قيد التفعيل.';
      inventory.appendChild(empty);
    }
  }
  if(screen==='profileEdit'){
    const details=$('.edit-profile-person .details small');
    if(details)details.textContent='حساب حقيقي · '+state.user.id.slice(0,8).toUpperCase();
  }
}
function decorate(){
  const state=auth.state();
  if(!state.signedIn&&!explicitPreview&&authScreens.has(screen)){
    const page=$('.fc-page')||$('#app .main')||$('#app');
    banner(page,'tc-phase2-login-banner',
      '🔐 هذه نسخة متصلة بقاعدة TotiChat الجديدة. لا توجد حسابات قديمة منقولة. سجّل حساباً جديداً حتى تظهر بياناتك الحقيقية.',
      screen==='loginPreview'?'signup':'login',screen==='loginPreview'?'إنشاء حساب جديد':'تسجيل الدخول');
    if(screen==='loginPreview'){
      banner(page,'tc-phase2-demo-choice',
        'تريد تشوف التصميم فقط؟ تستطيع فتح المعاينة، لكن كل الأرقام والمستخدمين فيها غير حقيقيين.',
        'preview','عرض التصميم التجريبي');
    }
    return;
  }
  if(explicitPreview&&!state.signedIn){
    banner($('#app .main')||$('#app'),'tc-phase2-demo-indicator',
      '⚠️ وضع المعاينة: جميع الحسابات والأرصدة والغرف المعروضة غير حقيقية.',
      'login','الدخول الحقيقي');
    return;
  }
  if(state.signedIn){
    protectIdentity();
    const parent=screen==='home' ? $('.royal-home-main'):
                 screen==='me' ? $('.me-royal'):
                 screen==='room' ? $('.roomview.room-v2'):
                 screen==='profilePreview' ? $('.profile-royal'):
                 null;
    if(parent)banner(parent,'tc-phase2-online-state',
      '✓ الحساب حقيقي · الغرف والدردشة متصلة · الهدايا بأسعار الخادم · الصوت يحتاج خدمة بث مفعّلة');
  }
}
const originalRender=render;
render=function(){
  const signed=live();
  if(!signed&&!explicitPreview&&!authScreens.has(screen))screen='loginPreview';
  if(signed&&!allowed.has(screen))screen='home';
  if(signed&&screen==='room'&&!window.TotiPhase2Rooms?.getStatus?.().activeRoomId)screen='home';
  const result=originalRender.apply(this,arguments);
  decorate();
  return result;
};
window.TotiLiveMode=Object.freeze({enabled:true,isPreview:()=>explicitPreview});
window.addEventListener('click',e=>{
  const action=e.target?.closest?.('[data-live-entry]');
  if(action){
    e.preventDefault();e.stopImmediatePropagation();e.stopPropagation();
    if(action.dataset.liveEntry==='preview'){
      explicitPreview=true;go('home');
    }else if(action.dataset.liveEntry==='signup'){
      explicitPreview=false;go('signupPreview');
    }else{
      explicitPreview=false;go('loginPreview');
    }
    return;
  }
  if(!live())return;
  const roomAction=e.target?.closest?.('[data-live-room-action]');
  if(roomAction&&screen==='room'){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    const what=roomAction.dataset.liveRoomAction;
    if(what==='gifts'){closeSheet();showGifts();}
    else if(what==='voice'){closeSheet();document.querySelector('[data-real-voice="connect"]')?.click();}
    else if(what==='settings'){closeSheet();window.TotiPhase2Rooms?.openSettings?.();}
    else if(what==='members'){
      const members=window.TotiPhase2Rooms?.getMembers?.()||[];
      showSheet('<section class="tc-live-tools"><h3>أعضاء الغرفة الحقيقيون</h3><div id="tc-live-member-list"></div><button class="primary" data-a="close">إغلاق</button></section>',true);
      const node=document.getElementById('tc-live-member-list');
      if(node){for(const m of members){const p=document.createElement('p');p.textContent=m.display_name||m.user_id.slice(0,8);node.appendChild(p);}}
    }else if(what==='info'){closeSheet();showSheet('<section class="tc-live-tools"><h3>معلومات الغرفة</h3><p id="tc-current-room-title"></p><button class="primary" data-a="close">إغلاق</button></section>',true);const n=document.getElementById('tc-current-room-title');if(n){const room=window.TotiPhase2Rooms?.getRoomSummary?.();n.textContent=room?room.title+' · '+room.id:'';}}
    return;
  }
  const item=e.target?.closest?.('[data-a="go"],[data-a="sheet"],[data-a="chatTab"],[data-a="shareRoom"],[data-royal]');
  if(!item)return;
  const route=item.dataset.v||'';
  const op=item.dataset.a||'';
  const royal=item.dataset.royal||'';
  if(screen==='room'&&op==='sheet'&&route==='roomInfo'){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    const info=window.TotiPhase2Rooms?.getRoomSummary?.();
    if(!info){warn('لا توجد غرفة حقيقية مفتوحة');return;}
    showSheet('<div class="tc-live-room-info"><h3></h3><p></p><p></p><button class="primary" data-a="close">إغلاق</button></div>',true);
    const box=document.querySelector('#sheet .tc-live-room-info');
    if(box){
      box.querySelector('h3').textContent='🎙️ '+info.title;
      box.querySelectorAll('p')[0].textContent='ID: '+info.id;
      box.querySelectorAll('p')[1].textContent='الأعضاء: '+info.memberCount;
    }return;
  }
  if(screen==='room'&&op==='chatTab'&&route==='هدية'){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    showGifts();return;
  }
  if(screen==='room'&&op==='sheet'&&route==='tools'){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    const info=window.TotiPhase2Rooms?.getRoomSummary?.();
    showSheet('<section class="tc-live-tools" dir="rtl"><h3>🛠️ أدوات الغرفة</h3>'+
      '<button class="primary" data-live-room-action="gifts">🎁 صندوق الهدايا الحقيقي</button>'+
      '<button class="primary" data-live-room-action="voice">🔊 تشغيل صوت الغرفة</button>'+
      '<button class="primary" data-live-room-action="members">👥 قائمة الأعضاء</button>'+
      '<button class="primary" data-live-room-action="info">ℹ️ معلومات الغرفة</button>'+
      (info?.isOwner?'<button class="primary" data-live-room-action="settings">🎨 إعدادات وخلفية الغرفة</button>':'')+
      '<button class="primary" data-a="close">إغلاق</button></section>',true);
    return;
  }
  if(screen==='room'&&op==='shareRoom'){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    const info=window.TotiPhase2Rooms?.getRoomSummary?.();
    if(info?.isPrivate&&info?.isOwner){
      document.querySelector('[data-phase2="invite-generate"]')?.click();return;
    }
    warn('لمشاركة الغرفة استخدم اسمها في قائمة الغرف؛ روابط الدخول المباشر قيد الربط.');
    return;
  }

  if((op==='go'&&!allowed.has(route))||
     (op==='go'&&route==='room'&&!window.TotiPhase2Rooms?.getStatus?.().activeRoomId)||
     (op==='sheet'&&/^(music|game|store|vip|recharge|lucky)/i.test(route))||
     ['friends','notify','search'].includes(royal)){
    e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
    warn(op==='go'&&route==='room'?'اختر غرفة حقيقية من القائمة أو أنشئ غرفتك أولاً.':undefined);
  }
},true);
window.addEventListener('totichat-phase2-auth',()=>{
  if(live()){
    explicitPreview=false;
    if(authScreens.has(screen)&&auth.state().profile)go('home');
    else decorate();
  }else if(!explicitPreview&&!authScreens.has(screen)){
    go('loginPreview');
  }
});
if(!live())go('loginPreview');
else if(!auth.state().profile)go('loginPreview'); // session will be checked by auth.resume().
else render();
})();
