/* Account security uses GoTrue endpoints; no credentials are stored in markup. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth)return;
let generation=0,factor=null,busy=false;
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function status(message,error=false){const node=document.querySelector('[data-security-status]');if(node){node.textContent=message;node.setAttribute('role',error?'alert':'status');}}
async function open(){
 const id=++generation;factor=null;
 showSheet('<section class="tc-phase2-account-sheet" dir="rtl" data-security-sheet><h3>أمان الحساب</h3><p data-security-status role="status">جارٍ تحميل إعدادات الأمان…</p><div data-security-body></div><button class="primary" data-phase2="logout">تسجيل الخروج</button><button class="primary" data-a="close">إغلاق</button></section>',true);
 try{
  const [state,providers]=await Promise.all([auth.securityState(),auth.providers()]);if(id!==generation||!auth.state().signedIn)return;
  const node=document.querySelector('[data-security-body]');if(!node)return;
  node.innerHTML='<p>'+esc(auth.state().user.email)+'</p><p>البريد '+(state.emailConfirmed?'مؤكد':'غير مؤكد')+'</p>'+
   '<form data-security-password><label>كلمة المرور الجديدة<input type="password" name="password" autocomplete="new-password" minlength="12" maxlength="128" required></label><label>تأكيد كلمة المرور<input type="password" name="confirmation" autocomplete="new-password" required></label><button class="primary" type="submit">حفظ كلمة المرور</button></form>'+
   '<button class="primary" data-security-action="sessions">إنهاء الجلسات على الأجهزة الأخرى</button><h4>التحقق بخطوتين</h4>'+
   state.factors.map(f=>'<div><span>'+esc(f.name||'تطبيق المصادقة')+' · '+esc(f.status)+'</span><button class="primary" data-security-action="challenge" data-factor="'+esc(f.id)+'">تحقق بالرمز</button><button class="primary" data-security-action="remove" data-factor="'+esc(f.id)+'">إزالة العامل</button></div>').join('')+
   '<button class="primary" data-security-action="enroll">إضافة تطبيق مصادقة</button><div data-security-enrollment></div>'+
   '<h4>الحسابات المرتبطة</h4><p>'+state.identities.map(i=>esc(i.provider)).join('، ')+'</p>'+['google','apple','facebook'].filter(p=>providers[p]&&!state.identities.some(i=>i.provider===p)).map(p=>'<button class="primary" data-security-action="link" data-provider="'+p+'">ربط '+p+'</button>').join('');
  void auth.requestData('/rest/v1/rpc/phase3_admin_session',{method:'POST',body:{}}).then(authority=>{
   if(id!==generation||!node.isConnected||!authority)return;
   if(authority.canReadReports){const report=document.createElement('button');report.type='button';report.className='primary';report.dataset.reportsOpen='';report.textContent='التقارير والمعاملات';node.appendChild(report);}
   if(!authority.canManageCatalogs)return;
   const button=document.createElement('button');button.type='button';button.className='primary';button.dataset.adminOpen='';button.textContent='إدارة الإعدادات';node.appendChild(button);
  }).catch(()=>{});
  status(auth.state().recoveryRequired?'أدخل كلمة مرور جديدة لإكمال الاستعادة':'تم تحميل إعدادات حسابك');
 }catch(e){status(e.message,true);}
}
async function run(button,task){if(busy)return;busy=true;button.disabled=true;status('جارٍ التنفيذ…');try{await task();}catch(e){status(e.message,true);}finally{busy=false;if(button.isConnected)button.disabled=false;}}
function verification(id,totp){factor=id;const node=document.querySelector('[data-security-enrollment]');if(!node)return;
 node.innerHTML=(totp?'<p>امسح الرمز بتطبيق المصادقة ثم أدخل رمز التحقق.</p><img alt="رمز إعداد تطبيق المصادقة" width="200" height="200" data-security-qr><details><summary>مفتاح الإعداد اليدوي</summary><code>'+esc(totp.secret)+'</code></details>':'')+
 '<form data-security-code><label>رمز التحقق<input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required></label><button class="primary">تأكيد</button></form>';
 if(totp){const img=node.querySelector('img');img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(totp.qr_code);}
 status('أدخل الرمز الحالي من تطبيق المصادقة');
}
window.addEventListener('click',event=>{
 const button=event.target.closest('[data-phase2="account"],[data-security-action]');if(!button)return;
 if(button.dataset.phase2==='account'){if(!auth.state().signedIn)return;event.preventDefault();event.stopImmediatePropagation();void open();return;}
 event.preventDefault();event.stopImmediatePropagation();
 void run(button,async()=>{
  switch(button.dataset.securityAction){
   case 'link':await auth.linkProvider(button.dataset.provider);break;
   case 'sessions':if(!confirm('إنهاء جميع الجلسات الأخرى؟'))return;await auth.revokeOtherSessions();status('تم إنهاء الجلسات الأخرى');break;
   case 'enroll':{const data=await auth.enrollMFA();verification(data.id,data.totp);break;}
   case 'challenge':verification(button.dataset.factor);break;
   case 'remove':if(!confirm('إزالة عامل التحقق؟ قد يتطلب الخادم التحقق أولاً.'))return;await auth.unenrollMFA(button.dataset.factor);await open();break;
  }
 });
},true);
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-security-password],[data-security-code]'))return;
 event.preventDefault();event.stopImmediatePropagation();if(!form.reportValidity())return;
 const button=form.querySelector('button');void run(button,async()=>{
  const data=new FormData(form);
  if(form.matches('[data-security-password]')){if(data.get('password')!==data.get('confirmation'))throw Error('كلمتا المرور غير متطابقتين');await auth.changePassword(data.get('password'));form.reset();status('تم تحديث كلمة المرور');}
  else {await auth.verifyMFA(factor,data.get('code'));await open();status('تم تأكيد التحقق بخطوتين');}
 });
},true);
window.addEventListener('totichat-auth-error',e=>{if(typeof showToast==='function')showToast(e.detail);});
let recoveryShown=false,verifiedUser=null,verificationPending=null;
window.addEventListener('totichat-phase2-auth',e=>{
 const user=e.detail.user?.id;
 if(!e.detail.signedIn){verifiedUser=null;verificationPending=null;}
 if(user&&e.detail.profile&&verifiedUser!==user&&verificationPending!==user){verificationPending=user;void auth.requestData('/rest/v1/rpc/phase4_verified_session',{method:'POST',body:{}}).then(id=>{if(id===user&&auth.state().user?.id===user)verifiedUser=user;}).catch(()=>{}).finally(()=>{if(verificationPending===user)verificationPending=null;});}
 if(!e.detail.signedIn){generation++;factor=null;recoveryShown=false;document.querySelector('[data-security-sheet]')?.remove();}
 if(e.detail.recoveryRequired&&!recoveryShown){recoveryShown=true;setTimeout(()=>void open(),0);}
});
})();
