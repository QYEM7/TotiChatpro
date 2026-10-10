/* TotiChat official Login / Register / Password recovery / Confirmation.
 * This module ONLY replaces auth-screen markup in the independent LIVE beta.
 * The previously approved room, Home, VIP artwork and Seats are not modified.
 * All form submissions use real Supabase Auth via the existing phase2 adapter.
 */
(function(){
'use strict';
if(!window.TotiLiveMode?.enabled||typeof window.render!=='function')return;
const auth=window.TotiPhase2Auth;
const screens=new Set(['loginPreview','signupPreview','passwordResetPreview','verifyAccountPreview']);
const falcon='../assets/images/toti_falcon_logo_1790422919580.jpg';
const svg=(name)=>{
 const paths={
   mail:'<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m4 7 8 6 8-6"/>',
   lock:'<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
   eye:'<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
   eyeoff:'<path d="m3 3 18 18M10.6 5.2c.46-.13.93-.2 1.4-.2 6.4 0 10 7 10 7a15 15 0 0 1-3.5 4.3M6.4 6.4C3.5 8.7 2 12 2 12s3.6 7 10 7c1.7 0 3.2-.5 4.5-1.2"/>',
   person:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
   arrow:'<path d="m14 5-7 7 7 7"/>'
 };
 return '<svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'+(paths[name]||'')+'</svg>';
};
const route=(id,title,subtitle,buttonText)=>({id,title,subtitle,buttonText});
const routes={
 loginPreview:route('loginPreview','مرحباً بعودتك 👋','سجّل دخولك للمتابعة','تسجيل الدخول'),
 signupPreview:route('signupPreview','انضم إلى TotiChat ✨','أنشئ حسابك الحقيقي للبدء','إنشاء الحساب'),
 passwordResetPreview:route('passwordResetPreview','استعادة الحساب','سنرسل تعليمات الاستعادة إلى بريدك الإلكتروني','إرسال رابط الاستعادة'),
 verifyAccountPreview:route('verifyAccountPreview','تأكيد بريدك الإلكتروني','أدخل رمز التأكيد المرسل إلى بريدك','تأكيد الحساب')
};
function input(id,type,label,placeholder,icon,autocomplete,extra=''){
 return '<label class="tc-login-label" for="'+id+'">'+label+'</label>'+
   '<span class="tc-login-input-wrap">'+svg(icon)+
   '<input id="'+id+'" name="'+id+'" type="'+type+'" placeholder="'+placeholder+
   '" autocomplete="'+autocomplete+'" '+extra+' required>'+
   (type==='password'?'<button class="tc-password-toggle" type="button" data-auth-action="toggle-password" data-target="'+id+'" aria-label="إظهار كلمة المرور" aria-pressed="false">'+svg('eye')+'</button>':'')+
   '</span>';
}
function social(){
 const names={google:'Google',apple:'Apple',facebook:'Facebook'};
 return '<div class="tc-login-divider"><span>أو سجّل الدخول بواسطة</span></div>'+
   '<div class="tc-social-buttons">'+Object.entries(names).map(([id,n])=>
    '<button type="button" data-auth-social="'+id+'" class="tc-social-button" disabled aria-label="تسجيل الدخول بواسطة '+n+'" title="يتم التحقق من توفر الخدمة">'+
    '<span class="tc-social-icon '+id+'">'+(id==='google'?'G':id==='apple'?'●':'f')+'</span>'+
    '<span>'+n+'</span></button>').join('')+'</div>'+
   '<p class="tc-social-explain" id="tc-social-state" role="status">يجري التحقق من خيارات الدخول المتاحة…</p>';
}
function create(){
 const config=routes[screen];if(!config)return;
 const login=config.id==='loginPreview',signup=config.id==='signupPreview';
 const forgot=config.id==='passwordResetPreview',verify=config.id==='verifyAccountPreview';
 const form=(signup?input('fc-name','text','اسم المستخدم','الاسم الذي سيظهر للآخرين','person','nickname','minlength="2" maxlength="35"'):'')+
 (verify?'':input('fc-email','email','البريد الإلكتروني','name@example.com','mail','email','inputmode="email" maxlength="254"'))+
 ((forgot||verify)?'':input('fc-pass','password','كلمة المرور','أدخل كلمة المرور','lock',login?'current-password':'new-password','minlength="8"'))+
 (signup?input('fc-confirm','password','تأكيد كلمة المرور','أعد كتابة كلمة المرور','lock','new-password','minlength="8"'):'')+
 (verify?input('fc-code','text','رمز التأكيد','000000','lock','one-time-code','inputmode="numeric" pattern="[0-9]{6,8}" maxlength="8"'):'')+
 (login?'<div class="tc-login-extras"><label class="tc-remember"><input id="tc-login-remember" type="checkbox"> تذكرني</label>'+
 '<button type="button" class="tc-login-text-btn" data-auth-route="passwordResetPreview">نسيت كلمة المرور؟</button></div>':'')+
 (signup?'<label class="tc-consent"><input type="checkbox" id="fc-terms" required><span>أوافق على إنشاء حساب وحفظ بياناتي اللازمة لتقديم الخدمة</span></label>':'')+
 '<p class="tc-auth-status" role="status" aria-live="polite" id="fc-form-status"></p>'+
 '<button class="tc-login-submit" type="submit" data-fc="validate-auth" data-v="'+config.id+'">'+
 '<span class="tc-login-spinner" aria-hidden="true"></span><span class="tc-login-submit-text">'+config.buttonText+'</span>'+svg('arrow')+'</button>';
 const footer=(login?'<p>ليس لديك حساب؟ <button type="button" data-auth-route="signupPreview">أنشئ حساباً</button></p>':
  signup?'<p>لديك حساب بالفعل؟ <button type="button" data-auth-route="loginPreview">تسجيل الدخول</button></p>':
  '<p>تذكرت كلمة المرور؟ <button type="button" data-auth-route="loginPreview">تسجيل الدخول</button></p>');
 const formHtml='<form class="tc-login-form" novalidate id="tc-real-auth-form">'+form+'</form>';
 const root=document.getElementById('app');
 if(!root)return;
 root.classList.add('tc-auth-root');
 root.innerHTML='<main class="tc-login-layout" dir="rtl">'+
  '<section class="tc-login-panel"><div class="tc-login-panel-inner">'+
  '<div class="tc-login-brand"><img src="'+falcon+'" alt="شعار الصقر الرسمي لتطبيق TotiChat" width="68" height="68"><span>TotiChat</span></div>'+
  '<header class="tc-login-intro"><h1>'+config.title+'</h1><p>'+config.subtitle+'</p></header>'+
  formHtml+(login?social():'')+
  '<div class="tc-login-footer">'+footer+'</div>'+
  '<p class="tc-login-safety">حسابك محمي عبر خدمة المصادقة الحقيقية. لن تُعرض بيانات تجريبية أو أرصدة وهمية.</p>'+
  '</div></section><aside class="tc-login-art" aria-hidden="true">'+
  '<div class="tc-login-art-glow"></div><img src="'+falcon+'" alt="">'+
  '<span>TOTICHAT</span><strong>مكانك بين الأصدقاء</strong><p>أصوات حقيقية · غرف حقيقية · مجتمع واحد</p>'+
  '</aside></main>';
 document.body.classList.add('tc-auth-body');
 document.body.style.background='#fcf9fe';
 const formElement=root.querySelector('#tc-real-auth-form');
 formElement.addEventListener('submit',event=>{
   event.preventDefault();
   if(!formElement.reportValidity())return;
   const button=root.querySelector('[data-fc="validate-auth"]');
   if(button&&!button.disabled)button.click();
 });
 if(login)void refreshProviders(root);
}
async function refreshProviders(root){
 const buttons=Array.from(root.querySelectorAll('[data-auth-social]'));
 const message=root.querySelector('#tc-social-state');
 try{
   const state=await auth.providers();
   if(!message?.isConnected)return;
   const enabled=buttons.filter(b=>{
     const available=state[b.dataset.authSocial]===true;
     b.disabled=!available;b.title=available?'الدخول بواسطة '+b.dataset.authSocial:'هذه الخدمة تحتاج تفعيلها في Supabase أولاً';
     return available;
   }).length;
   message.textContent=enabled?'طرق الدخول المتاحة مربوطة بخادم المصادقة.':
     'طرق الدخول الاجتماعي غير مفعّلة في قاعدة TotiChat الجديدة حالياً؛ استخدم البريد الإلكتروني.';
 }catch(_){
   if(message?.isConnected)message.textContent='تعذر التحقق من طرق الدخول الاجتماعي؛ استخدم البريد وكلمة المرور.';
 }
}
const prev=render;
render=function(){
 const result=prev.apply(this,arguments);
 const isAuth=screens.has(screen);
 document.body.classList.toggle('tc-auth-body',isAuth);
 const app=document.getElementById('app');
 app?.classList.toggle('tc-auth-root',isAuth);
 if(isAuth)create();
 return result;
};
document.addEventListener('click',e=>{
 const target=e.target?.closest?.('[data-auth-action],[data-auth-route],[data-auth-social]');
 if(!target||!screens.has(screen))return;
 e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
 const route=target.dataset.authRoute;
 if(route){go(route);return;}
 if(target.dataset.authAction==='toggle-password'){
   const input=document.getElementById(target.dataset.target);
   if(!input)return;
   const visible=input.type==='password';
   input.type=visible?'text':'password';
   target.setAttribute('aria-pressed',String(visible));
   target.setAttribute('aria-label',visible?'إخفاء كلمة المرور':'إظهار كلمة المرور');
   target.innerHTML=svg(visible?'eyeoff':'eye');
   input.focus({preventScroll:true});
   return;
 }
 if(target.dataset.authSocial){
   if(target.disabled)return;
   target.disabled=true;
   const notice=document.getElementById('fc-form-status');
   if(notice)notice.textContent='جارٍ فتح تسجيل الدخول الآمن…';
   void auth.signInWithProvider(target.dataset.authSocial).catch(err=>{
     if(notice)notice.textContent=String(err.message||'تعذر تسجيل الدخول');
   }).finally(()=>{if(target.isConnected)target.disabled=false;});
 }
},true);
document.addEventListener('change',e=>{
 if(e.target?.id==='tc-login-remember')auth.setRememberMe(!!e.target.checked);
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 if(!screens.has(screen))return;
 const button=document.querySelector('[data-fc="validate-auth"]');
 if(button)button.classList.toggle('tc-login-wait',button.disabled);
});
if(screens.has(screen))render();
})();
