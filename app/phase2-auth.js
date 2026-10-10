/* TotiChat phase 2: isolated, real Supabase Auth + RLS profile adapter.
 * Auth here is BETA: session kept in sessionStorage (not a production
 * Android secure key store). Never persist passwords or backend secrets.
 * No legacy database, user IDs, balances or simulated Auth success.
 */
(function initPhase2Auth(){
  'use strict';
  const settings=window.TOTICHAT_PUBLIC_BACKEND||{};
  let origin='';
  try{
    const url=new URL(settings.supabaseUrl||'');
    if(url.protocol==='https:'&&url.hostname.endsWith('.supabase.co'))origin=url.origin;
  }catch(_){}
  const apiKey=String(settings.publishableKey||'');
  if(!origin||!apiKey.startsWith('sb_publishable_')){
    console.warn('TotiChat phase 2: independent backend is not configured');
    return;
  }
  const SESSION_KEY='totichat.phase2.session.v1';
  const PENDING_EMAIL='totichat.phase2.pending-email.v1';
  const REMEMBER_KEY='totichat.phase2.remember.session.v1';
  let remember=false;
  let session=null,profile=null,refreshInFlight=null,clock=0,requestGeneration=0;
  function safeLoad(){
    try{
      const persistent=localStorage.getItem(REMEMBER_KEY);
      const obj=JSON.parse(persistent||sessionStorage.getItem(SESSION_KEY)||'null');
      if(obj&&typeof obj.access_token==='string'&&
        typeof obj.refresh_token==='string'&&obj.user&&typeof obj.user.id==='string'){
        session=obj;remember=Boolean(persistent);
      }
    }catch(_){
      try{
        const obj=JSON.parse(sessionStorage.getItem(SESSION_KEY)||'null');
        if(obj?.access_token&&obj?.refresh_token&&obj?.user?.id)session=obj;
      }catch(_){}
    }
  }
  safeLoad();
  function persist(){
    try{
      if(session&&remember)localStorage.setItem(REMEMBER_KEY,JSON.stringify(session));
      else localStorage.removeItem(REMEMBER_KEY);
    }catch(_){}
    try{
      if(session&&!remember)sessionStorage.setItem(SESSION_KEY,JSON.stringify(session));
      else sessionStorage.removeItem(SESSION_KEY);
    }catch(_){}
  }
  function setRememberMe(selected){remember=Boolean(selected);persist();}
  function isRemembered(){return remember;}
  function publicState(){
    return Object.freeze({
      signedIn:!!session?.user?.id,
      loading:!!refreshInFlight,
      user:session?.user?Object.freeze({id:session.user.id,email:session.user.email||''}):null,
      profile:profile?Object.freeze({...profile}):null
    });
  }
  function notify(){window.dispatchEvent(new CustomEvent('totichat-phase2-auth',{detail:publicState()}));}
  function apiError(obj,status){
    const text=String(obj?.msg||obj?.error_description||obj?.message||obj?.error||'Request failed');
    const e=new Error(text.length>200?text.slice(0,200):text);
    e.status=status;
    return e;
  }
  async function request(path,{method='GET',body,accessToken,prefer}={}){
    const headers={apikey:apiKey,Accept:'application/json'};
    if(body!==undefined)headers['Content-Type']='application/json';
    if(accessToken)headers.Authorization='Bearer '+accessToken;
    if(prefer)headers.Prefer=prefer;
    const response=await fetch(origin+path,{
      method,headers,
      body:body===undefined?undefined:JSON.stringify(body),
      cache:'no-store',credentials:'omit'
    });
    const raw=await response.text();
    let data=null;
    if(raw){
      try{data=JSON.parse(raw);}
      catch(_){throw new Error('Unexpected backend response');}
    }
    if(!response.ok)throw apiError(data,response.status);
    return data;
  }
  function storeToken(data,generation){
    if(generation!==requestGeneration)return false;
    if(!data||typeof data.access_token!=='string'||typeof data.refresh_token!=='string'||!data.user?.id)
      return false;
    const expiresAt=Math.floor(Date.now()/1000)+Number(data.expires_in||3600);
    session={
      access_token:data.access_token,
      refresh_token:data.refresh_token,
      expires_at:expiresAt,
      user:{id:data.user.id,email:data.user.email||''}
    };
    persist();scheduleRefresh();notify();return true;
  }
  function scheduleRefresh(){
    clearTimeout(clock);
    if(!session)return;
    const delta=Math.max(1000,Math.min(2147483647,(session.expires_at*1000-Date.now()-90000)));
    clock=setTimeout(()=>{void refresh().catch(()=>{});},delta);
  }
  async function refresh(){
    if(!session?.refresh_token)return false;
    if(refreshInFlight)return refreshInFlight;
    const before=requestGeneration;
    const secret=session.refresh_token;
    refreshInFlight=(async()=>{
      try{
        const data=await request('/auth/v1/token?grant_type=refresh_token',{
          method:'POST',body:{refresh_token:secret}
        });
        return storeToken(data,before);
      }catch(error){
        // Rejected refresh tokens expire/rotate; outages must not silently log users out.
        if((error.status===400||error.status===401)&&before===requestGeneration){
          session=null;profile=null;persist();clearTimeout(clock);notify();
        }
        throw error;
      }finally{refreshInFlight=null;}
    })();
    return refreshInFlight;
  }
  async function validToken(){
    if(!session)throw new Error('يجب تسجيل الدخول أولاً');
    if(session.expires_at*1000<Date.now()+30000)await refresh();
    if(!session?.access_token)throw new Error('انتهت الجلسة، سجّل الدخول مجدداً');
    return session.access_token;
  }
  async function readProfile(){
    if(!session?.user?.id)return null;
    const generation=requestGeneration;
    const token=await validToken();
    const id=encodeURIComponent(session.user.id);
    const data=await request('/rest/v1/profiles?id=eq.'+id+
      '&select=id,display_name,bio,avatar_url,created_at,updated_at&limit=1',
      {accessToken:token});
    if(generation!==requestGeneration)return null;
    if(!Array.isArray(data)||!data.length){
      profile=null;notify();throw new Error('تعذر العثور على الملف الشخصي لهذا الحساب');
    }
    profile=data[0];notify();return {...profile};
  }
  async function updateProfile(input){
    const displayName=String(input.display_name||'').trim();
    const bio=String(input.bio||'');
    if(displayName.length<2||displayName.length>35)throw new Error('الاسم يجب أن يكون من 2 إلى 35 حرفاً');
    if(bio.length>150)throw new Error('النبذة أطول من 150 حرفاً');
    const token=await validToken();
    const id=session.user.id,generation=requestGeneration;
    const data=await request('/rest/v1/profiles?id=eq.'+encodeURIComponent(id)+
      '&select=id,display_name,bio,avatar_url,created_at,updated_at',{
      method:'PATCH',accessToken:token,
      body:{display_name:displayName,bio},
      prefer:'return=representation'
    });
    if(generation!==requestGeneration)throw new Error('الجلسة تغيرت أثناء حفظ البيانات');
    if(!Array.isArray(data)||data.length!==1||data[0].id!==id)
      throw new Error('لم يؤكد الخادم حفظ الملف الشخصي');
    profile=data[0];notify();return {...profile};
  }
  function emailValid(s){return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s)&&s.length<=254;}
  async function signUp({email,password,displayName}){
    email=String(email||'').trim().toLowerCase();
    displayName=String(displayName||'').trim();
    if(!emailValid(email))throw new Error('البريد الإلكتروني غير صالح');
    if(typeof password!=='string'||password.length<8)throw new Error('كلمة المرور قصيرة');
    if(displayName.length<2||displayName.length>35)throw new Error('الاسم يجب أن يكون من 2 إلى 35 حرفاً');
    const generation=requestGeneration;
    const data=await request('/auth/v1/signup',{method:'POST',body:{
      email,password,data:{display_name:displayName}
    }});
    try{sessionStorage.setItem(PENDING_EMAIL,email);}catch(_){}
    if(data?.access_token&&storeToken(data,generation))await readProfile();
    return {signedIn:!!session?.user?.id,confirmationRequired:!data?.access_token};
  }
  async function signIn({email,password}){
    email=String(email||'').trim().toLowerCase();
    if(!emailValid(email)||!password)throw new Error('أدخل البريد وكلمة المرور');
    const generation=requestGeneration;
    const data=await request('/auth/v1/token?grant_type=password',{
      method:'POST',body:{email,password}
    });
    if(!storeToken(data,generation))throw new Error('تعذر بدء جلسة الحساب');
    await readProfile();
    return publicState();
  }
  async function verifySignup(code){
    let email='';
    try{email=sessionStorage.getItem(PENDING_EMAIL)||'';}catch(_){}
    if(!emailValid(email))throw new Error('أعد إدخال البريد عبر شاشة التسجيل أولاً');
    const token=String(code||'').trim();
    if(!/^\d{6,8}$/.test(token))throw new Error('رمز تأكيد الحساب غير صحيح');
    const generation=requestGeneration;
    const data=await request('/auth/v1/verify',{
      method:'POST',body:{email,token,type:'signup'}
    });
    if(data?.access_token&&storeToken(data,generation)){
      try{sessionStorage.removeItem(PENDING_EMAIL);}catch(_){}
      await readProfile();return true;
    }
    return false;
  }
  async function recover(email){
    email=String(email||'').trim().toLowerCase();
    if(!emailValid(email))throw new Error('البريد الإلكتروني غير صالح');
    await request('/auth/v1/recover',{method:'POST',body:{email}});
    return true;
  }
  async function signOut(){
    const old=session?.access_token;
    requestGeneration++;session=null;profile=null;clearTimeout(clock);persist();notify();
    if(old){
      try{await request('/auth/v1/logout',{method:'POST',accessToken:old});}
      catch(_){/* Local session already revoked; server revocation may retry online. */}
    }
  }
  async function resume(){
    if(!session)return publicState();
    try{
      await validToken();
      const token=await validToken(),generation=requestGeneration;
      const user=await request('/auth/v1/user',{accessToken:token});
      if(generation!==requestGeneration)return publicState();
      if(!user?.id||user.id!==session.user.id)throw Object.assign(new Error('Invalid user'),{status:401});
      await readProfile();
    }catch(error){
      if(error.status===401||error.status===403){requestGeneration++;session=null;profile=null;persist();notify();}
      else console.warn('TotiChat account reconnect pending:',String(error.message||'Network error'));
    }
    scheduleRefresh();return publicState();
  }
  async function requestData(path,{method='GET',body,prefer}={}){
    if(typeof path!=='string'||!path.startsWith('/rest/v1/'))throw new Error('Forbidden service path');
    const accessToken=await validToken();
    return request(path,{method,body,accessToken,prefer});
  }
  // Public GoTrue provider settings: never guess an OAuth button is available.
  let providerCache=null;
  async function providers(){
    if(providerCache)return {...providerCache};
    const response=await request('/auth/v1/settings');
    const enabled=response?.external||response?.external_providers||{};
    providerCache={
      google:enabled.google===true,
      apple:enabled.apple===true,
      facebook:enabled.facebook===true
    };
    return {...providerCache};
  }
  function base64Url(array){
    const arr=Array.from(array);
    return btoa(arr.map(byte=>String.fromCharCode(byte)).join(''))
      .replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  }
  const OAUTH_PENDING='totichat.phase2.oauth.pending';
  async function signInWithProvider(provider){
    if(!['google','apple','facebook'].includes(provider))throw new Error('Invalid provider');
    const enabled=await providers();
    if(!enabled[provider])throw new Error('طريقة الدخول غير مفعّلة في خادم TotiChat الجديد');
    const native=location.hostname==='localhost'&&location.protocol==='https:';
    const app=window.Capacitor?.Plugins?.App;
    const browser=window.Capacitor?.Plugins?.Browser;
    if(native&&(!app||!browser))throw new Error('Android OAuth bridge غير مثبت في هذه النسخة');
    const verifier=base64Url(crypto.getRandomValues(new Uint8Array(48)));
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(verifier));
    const challenge=base64Url(new Uint8Array(digest));
    const redirect=native?'com.totichat.beta://auth/callback':
      new URL('./',location.href).href;
    // GoTrue uses the code challenge + code verifier pair for the one-time exchange.
    const loginUrl=origin+'/auth/v1/authorize?provider='+encodeURIComponent(provider)+
      '&redirect_to='+encodeURIComponent(redirect)+
      '&code_challenge='+encodeURIComponent(challenge)+'&code_challenge_method=s256';
    try{sessionStorage.setItem(OAUTH_PENDING,JSON.stringify({
      verifier,created:Date.now(),provider,redirect
    }));}catch(_){throw new Error('OAuth temporary storage unavailable');}
    if(native){
      await app.addListener('appUrlOpen',async event=>{
        try{
          if(!event?.url?.startsWith('com.totichat.beta://auth/callback'))return;
          await browser.close().catch(()=>{});
          await handleOAuthCallback(event.url);
        }catch(error){console.warn('TotiChat OAuth callback error',String(error.message));}
      });
      await browser.open({url:loginUrl});
    }else location.assign(loginUrl);
  }
  async function handleOAuthCallback(callbackUrl){
    const parsed=new URL(callbackUrl);
    const native=parsed.protocol==='com.totichat.beta:';
    if(native&&(parsed.hostname!=='auth'||parsed.pathname!=='/callback'))
      throw new Error('Wrong OAuth callback');
    if(parsed.searchParams.has('error'))
      throw new Error('لم يكتمل تسجيل الدخول بواسطة مزود الهوية');
    const code=parsed.searchParams.get('code');
    if(!code)throw new Error('Missing OAuth authorization code');
    const raw=sessionStorage.getItem(OAUTH_PENDING);
    const pending=JSON.parse(raw||'null');
    if(!pending?.verifier||Date.now()-pending.created>10*60*1000)
      throw new Error('انتهت صلاحية محاولة تسجيل الدخول');
    // Delete the verifier BEFORE network exchange: no code can be used twice.
    sessionStorage.removeItem(OAUTH_PENDING);
    const generation=requestGeneration;
    const response=await request('/auth/v1/token?grant_type=pkce',{
      method:'POST',body:{auth_code:code,code_verifier:pending.verifier}
    });
    if(!storeToken(response,generation))throw new Error('تعذر إكمال الجلسة');
    await readProfile();
    return publicState();
  }
  if(typeof location!=='undefined'&&location.search.includes('code=')){
    void handleOAuthCallback(location.href).then(()=>{
      const clean=new URL(location.href);clean.searchParams.delete('code');
      history.replaceState(null,'',clean.href);
    }).catch(error=>console.warn('OAuth resume:',String(error.message)));
  }
  const api=Object.freeze({state:publicState,signUp,signIn,signOut,recover,
    verifySignup,readProfile,updateProfile,resume,refresh,requestData,
    providers,signInWithProvider,handleOAuthCallback,setRememberMe,isRemembered});
  window.TotiPhase2Auth=api;
  if(session){void resume();}
  else queueMicrotask(notify);
})();
