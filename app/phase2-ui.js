/* Stage-2 opt-in UI bridge. Preserve all approved markup, navigation and
 * guest visual QA while wiring only real Auth/profile flows to new Supabase.
 * Finance, gifts, agencies and audio remain explicitly demo until backed.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||typeof window.render!=='function')return;
const $=(selector,root=document)=>root.querySelector(selector);
let currentUser='',busy=false;
function notify(text,error=false){
  const target=$('#fc-form-status');
  if(target){target.textContent=text;target.classList.toggle('error',error);
    target.style.color=error?'#b22656':'#2f7959';target.setAttribute('role',error?'alert':'status');}
  else if(typeof showToast==='function')showToast(text);
}
function errorMessage(e){
  const str=String(e?.message||'تعذر الاتصال بالخادم');
  if(/invalid login credentials/i.test(str))return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  if(/email not confirmed/i.test(str))return 'يلزم تأكيد البريد الإلكتروني قبل الدخول';
  if(/rate limit|too many requests/i.test(str))return 'محاولات كثيرة؛ انتظر قليلاً وأعد المحاولة';
  if(/failed to fetch|networkerror/i.test(str))return 'تعذر الاتصال بالخادم؛ افحص الإنترنت';
  if(/already registered/i.test(str))return 'هذا البريد مرتبط بحساب مسبق';
  return str.length>150?'حدث خطأ غير متوقع':str;
}
function changePreviewIdentity(){
  const state=auth.state(),p=state.profile;
  if(p?.display_name){
    previewProfileName=p.display_name;
    previewProfileBio=p.bio||'';
    editForm.name=p.display_name;editForm.bio=p.bio||'';
    previewProfilePic=p.avatar_url||''; // Only the authenticated server value is displayed.
    currentUser=state.user?.id||'';
  }else if(!state.signedIn&&currentUser){
    // Never show the previous account identity after sign-out.
    previewProfileName='مستخدم تجريبي';
    previewProfileBio='هذه معاينة بصرية قبل تسجيل الدخول';
    editForm.name=previewProfileName;editForm.bio=previewProfileBio;
    previewProfilePic='';currentUser='';
  }
}
function hydrate(){
  const s=auth.state();
  if(screen==='me'){
    const container=$('.me-hero-top');
    if(container&&!container.querySelector('[data-phase2="account"]')){
      const b=document.createElement('button');
      b.type='button';b.className='tc-phase2-account';
      b.dataset.phase2='account';
      b.textContent=s.signedIn?'✓ الحساب مفعل':'تسجيل الدخول';
      b.setAttribute('aria-label',s.signedIn?'إدارة حسابك الحقيقي':'تسجيل الدخول إلى حساب TotiChat');
      const edit=container.querySelector('button');
      if(edit)container.insertBefore(b,edit);else container.appendChild(b);
    }
    if(s.signedIn){
      const summary=$('.me-summary .muted-id');
      if(summary)summary.textContent='🇮🇶 IQ | حساب '+s.user.id.slice(0,8).toUpperCase();
      const badges=$('.me-summary .vip-labels');
      if(badges)badges.innerHTML='<span>الحساب موثّق الدخول</span><span>VIP قيد الربط</span>';
      const vip=$('.me-vip-banner strong');
      if(vip)vip.textContent='👑 VIP · قيد الربط';
      // Counts have not been integrated with a social graph yet. Never show sample numbers as real.
      $$('.me-statcard > button b').forEach(x=>{x.textContent='—';});
    }
  }
  if(screen==='profilePreview'&&s.signedIn){
    const info=$('.pr-final');
    if(info)info.dataset.phase2='linked-profile';
  }
  if(['loginPreview','signupPreview','passwordResetPreview','verifyAccountPreview'].includes(screen)){
    const notes=$$('.fc-page .fc-note');
    notes.forEach(node=>{node.textContent='تسجيل الدخول والملف الشخصي مربوطان بقاعدة TotiChatpro الجديدة. بقية الوظائف لا تزال تجريبية.';});
    const cards=$$('.fc-page .fc-card');
    const note=cards[cards.length-1]?.querySelector('p');
    if(note)note.textContent='المصادقة تتم عبر Supabase Auth الحقيقي. لا نحتفظ بكلمة مرورك داخل التطبيق. قد يطلب الخادم تأكيد البريد.';
    const button=$('[data-fc="validate-auth"]');
    if(button){
      const caption={
        loginPreview:'تسجيل الدخول',
        signupPreview:'إنشاء الحساب',
        passwordResetPreview:'إرسال تعليمات الاستعادة',
        verifyAccountPreview:'تأكيد البريد الإلكتروني'
      };
      button.textContent=caption[screen]||'متابعة';
    }
    if(screen==='signupPreview'){
      const label=$('.fc-consent');
      if(label&&label.lastChild?.nodeType===3)
        label.lastChild.textContent=' أوافق على إنشاء الحساب وحفظ البريد واسم العرض والبيانات الأساسية اللازمة للخدمة';
    }
    if(s.signedIn){
      const c=$('.fc-heading');
      if(c)c.insertAdjacentHTML('beforeend','<small class="tc-phase2-connected">✓ أنت مسجل الدخول حالياً</small>');
    }
  }
  if(screen==='profileEdit'&&s.signedIn){
    const help=$('.edit-help');
    if(help)help.textContent='الاسم والنبذة وصورة الملف تُحفظ على الخادم. بقية الحقول قيد الربط.';
  }
  if(screen==='settings'){
    const logout=Array.from(document.querySelectorAll('button')).find(b=>b.textContent.trim()==='تسجيل الخروج');
    if(logout){
      logout.dataset.phase2='logout';
      logout.textContent=s.signedIn?'تسجيل الخروج من الحساب':'تسجيل الدخول';
    }
  }
}
function $$(selector,root=document){return Array.from(root.querySelectorAll(selector));}
const renderBefore=render;
render=function(){
  const result=renderBefore.apply(this,arguments);
  hydrate();return result;
};
hydrate();
async function submitAuth(route,button){
  const email=($('#fc-email')?.value||'').trim();
  const password=$('#fc-pass')?.value||'';
  const signup=route==='signupPreview',verify=route==='verifyAccountPreview';
  const reset=route==='passwordResetPreview';
  if(!verify&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Error('أدخل بريداً إلكترونياً صحيحاً');
  if(!reset&&!verify&&password.length<8)throw new Error('كلمة المرور يجب أن تحتوي ثمانية أحرف على الأقل');
  if(signup){
    const displayName=($('#fc-name')?.value||'').trim();
    if(displayName.length<2||displayName.length>35)throw new Error('الاسم يجب أن يكون 2–35 حرفاً');
    if(password!==($('#fc-confirm')?.value||''))throw new Error('كلمتا المرور غير متطابقتين');
    if(!$('#fc-terms')?.checked)throw new Error('يجب الموافقة على إنشاء الحساب');
    const result=await auth.signUp({email,password,displayName});
    if(!result.signedIn){notify('تحقق من بريدك الإلكتروني لتأكيد الحساب، ثم أدخل رمز التحقق أو ارجع لتسجيل الدخول.');return;}
  }else if(reset){
    await auth.recover(email);
    notify('إذا كان البريد مرتبطاً بحساب فستصلك رسالة استعادة.');return;
  }else if(verify){
    const ok=await auth.verifySignup($('#fc-code')?.value||'');
    if(!ok){notify('افتح رسالة التأكيد التي أرسلها الخادم ثم ارجع لتسجيل الدخول.');return;}
  }else{
    await auth.signIn({email,password});
  }
  changePreviewIdentity();
  if(typeof closeSheet==='function')closeSheet();
  go(window.TotiLiveMode?.enabled?'home':'me');
  if(typeof showToast==='function')showToast('تم تسجيل الدخول وربط الملف الشخصي بنجاح');
}
// Live / Android mode must never use a URL demo flag to disable real Auth.
const demoParam=new URLSearchParams(location.search).get('phase2Demo')==='1';
function previewOnly(){
 const params=new URLSearchParams(location.search);
 const native=(location.protocol==='https:'&&location.hostname==='localhost')||
   !!window.Capacitor?.isNativePlatform?.();
 return demoParam&&params.get('mode')!=='live'&&!native&&!window.TotiLiveMode?.enabled;
}
function handleAuthClick(route,button){
  if(previewOnly())return false;
  if(busy)return true;
  busy=true;button.disabled=true;
  notify('جارٍ التواصل مع الخادم…');
  void submitAuth(route,button).catch(err=>notify(errorMessage(err),true))
    .finally(()=>{busy=false;button.disabled=false;});
  return true;
}
window.TotiPhase2UI=Object.freeze({handleAuthClick});
document.addEventListener('click',event=>{
  const el=event.target.closest('[data-fc="validate-auth"],[data-a="saveProfilePreview"],[data-phase2]');
  if(!el)return;
  const action=el.dataset.phase2||el.dataset.fc||el.dataset.a;
  const state=auth.state();
  if(action==='saveProfilePreview'&&!state.signedIn)return; // Preserve guest demo edits.
  if(action==='validate-auth'&&previewOnly())return; // Visual-only regression mode.
  if(!['validate-auth','saveProfilePreview','account','logout'].includes(action))return;
  event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();
  if(action==='account'){
    if(state.signedIn){
      if(typeof showSheet==='function'){
        const div=document.createElement('div');
        const email=document.createElement('p');email.textContent=state.user.email||'';
        const name=document.createElement('b');name.textContent=state.profile?.display_name||'حساب متصل';
        div.append(name,email);
        showSheet('<div class="tc-phase2-account-sheet" dir="rtl"><h3>حساب TotiChat</h3><p class="tc-phase2-account-info"></p><button class="primary" data-phase2="logout">تسجيل الخروج</button><button class="primary" data-a="close">إغلاق</button></div>',true);
        const info=$('.tc-phase2-account-info');
        if(info)info.textContent=(state.profile?.display_name||'حساب متصل')+' · '+state.user.email;
      }
    }else go('loginPreview');
    return;
  }
  if(action==='logout'){
    if(busy)return;
    busy=true;el.disabled=true;
    void auth.signOut().then(()=>{
      changePreviewIdentity();go('loginPreview');
      if(typeof showToast==='function')showToast('تم تسجيل الخروج');
    }).catch(err=>notify(errorMessage(err),true))
      .finally(()=>{busy=false;el.disabled=false;});
    return;
  }
  if(action==='validate-auth'){
    handleAuthClick(el.dataset.v||screen,el);return;
  }
  if(busy)return;
  busy=true;el.disabled=true;
  if(action==='saveProfilePreview'){
    const name=(editForm.name||'').trim(),bio=(editForm.bio||'').slice(0,150);
    notify('جارٍ حفظ الملف على الخادم…');
    void auth.updateProfile({display_name:name,bio}).then(()=>{
      changePreviewIdentity();
      editDraftPhoto='';editError='';
      go('profilePreview');
      if(typeof showToast==='function')showToast('تم حفظ الاسم والنبذة في حسابك الحقيقي');
    }).catch(err=>notify(errorMessage(err),true))
      .finally(()=>{busy=false;el.disabled=false;});
  }
},true);

  // Capture BEFORE the approved guest FileReader listener to avoid falsely
  // claiming a local preview image was saved to a signed-in account.
  let photoBusy=false;
  async function avatarWebp(file){
    if(!file||!['image/jpeg','image/png','image/webp'].includes(file.type)||
      file.size<1||file.size>6*1024*1024)throw new Error('اختر JPG أو PNG أو WebP بحجم لا يزيد عن 6 ميغابايت');
    const image=await createImageBitmap(file);
    try{
      if(image.width<1||image.height<1||image.width>8192||image.height>8192)
        throw new Error('أبعاد الصورة غير مدعومة');
      const canvas=document.createElement('canvas');
      canvas.width=512;canvas.height=512;
      const ctx=canvas.getContext('2d');
      if(!ctx)throw new Error('تعذّر معالجة الصورة');
      const side=Math.min(image.width,image.height);
      ctx.drawImage(image,(image.width-side)/2,(image.height-side)/2,side,side,0,0,512,512);
      const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',.84));
      if(!blob||blob.type!=='image/webp'||blob.size>2097152)throw new Error('تعذّر تصغير الصورة إلى الحد الآمن');
      return blob;
    }finally{image.close?.();}
  }
  document.addEventListener('change',event=>{
    const input=event.target;
    if(!auth.state().signedIn||!['editAvatar','avatar'].includes(input?.dataset?.previewUpload))return;
    event.preventDefault();event.stopImmediatePropagation();
    if(photoBusy)return;
    const selected=input.files?.[0];if(!selected)return;
    const owner=auth.state().user?.id;photoBusy=true;input.disabled=true;
    notify('جارٍ رفع صورة الحساب الحقيقية…');
    void avatarWebp(selected).then(blob=>auth.uploadAvatar(blob)).then(p=>{
      if(auth.state().user?.id!==owner)return;
      previewProfilePic=p.avatar_url||'';editDraftPhoto='';
      if(typeof render==='function')render();
      if(typeof showToast==='function')showToast('تم حفظ صورة الحساب على الخادم');
    }).catch(err=>notify(errorMessage(err),true)).finally(()=>{
      photoBusy=false;if(input.isConnected){input.disabled=false;input.value='';}
    });
  },true);

window.addEventListener('totichat-phase2-auth',()=>{
  changePreviewIdentity();
  if(!['loginPreview','signupPreview','passwordResetPreview','verifyAccountPreview'].includes(screen))
    render();
  else hydrate();
});
})();
