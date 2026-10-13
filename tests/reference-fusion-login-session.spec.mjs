import { test, expect } from '@playwright/test';

/*
 * Isolated browser contract checks with synthetic sessions and intercepted network.
 * NO production/staging mutation, NO access to a user's Google tokens.
 * A mocked backend cannot substitute for user-confirmed real OAuth/logout acceptance.
 */
const base = 'https://totichat-login-review-20261013.vercel.app/';
const apiHost = 'rziaedugbdwefbefcxjt.supabase.co';
const sessionKey = 'totichat.phase2.session.v1';
const rememberKey = 'totichat.phase2.remember.session.v1';
const user = { id:'11111111-1111-4111-8111-111111111111', email:'session-qa@example.invalid' };
const profile = { id:user.id, display_name:'Session Test', bio:'', avatar_url:null,
  created_at:'2026-10-13T00:00:00Z', updated_at:'2026-10-13T00:00:00Z' };

function session({expiresIn=3600,token='synthetic-access',refresh='synthetic-refresh'}={}) {
  return { access_token:token,refresh_token:refresh,
    expires_at:Math.floor(Date.now()/1000)+expiresIn,
    user:{...user} };
}
async function mount(page,{initialSession=session(),logoutStatus=204,refreshStatus=200,userStatus=200,returnUser={...user}}={}) {
  const calls=[];
  await page.addInitScript(({value,key})=>{
    // Stored only in this test's clean browser context.
    if (location.hostname==='totichat-login-review-20261013.vercel.app'
        && sessionStorage.getItem('__tc_session_qa_initialized__')!=='1') {
      sessionStorage.setItem(key,JSON.stringify(value));
      sessionStorage.setItem('__tc_session_qa_initialized__','1');
      localStorage.removeItem('totichat.phase2.remember.session.v1');
    }
  },{value:initialSession,key:sessionKey});

  await page.route('https://'+apiHost+'/**',async route=>{
    const request=route.request(),url=new URL(request.url());
    const method=request.method();
    calls.push({method,path:url.pathname,query:url.search});
    const cors={
      'access-control-allow-origin':'https://totichat-login-review-20261013.vercel.app',
      'access-control-allow-headers':'authorization,apikey,content-type,accept',
      'access-control-allow-methods':'GET,POST,OPTIONS',
      'access-control-max-age':'600'
    };
    if(method==='OPTIONS')return route.fulfill({status:204,headers:cors,body:''});
    const json=(status,obj)=>route.fulfill({
      status,contentType:'application/json',headers:cors,body:JSON.stringify(obj)
    });
    if(url.pathname==='/auth/v1/settings')return json(200,{external:{google:true}});
    if(url.pathname==='/auth/v1/user')return json(userStatus,userStatus===200?returnUser:{message:'Invalid JWT'});
    if(url.pathname==='/rest/v1/profiles')return json(200,[profile]);
    if(url.pathname==='/auth/v1/token'&&url.searchParams.get('grant_type')==='refresh_token') {
      return json(refreshStatus,refreshStatus===200?
        { access_token:'synthetic-rotated',refresh_token:'synthetic-rotated-refresh',
          expires_in:3600,user:{...user}}:{error:'invalid_grant',message:'Invalid refresh token'});
    }
    if(url.pathname==='/auth/v1/logout'&&method==='POST'){
      if(logoutStatus===204)return route.fulfill({
        status:204,headers:cors,body:''});
      return json(logoutStatus,{message:'Service temporarily unavailable'});
    }
    return json(404,{message:'Unmocked session contract endpoint'});
  });
  return calls;
}

async function debugSession(page,label,calls) {
  const data=await page.evaluate(key=>({
    adapterLoaded:Boolean(window.TotiPhase2Auth),
    configLoaded:Boolean(window.TOTICHAT_PUBLIC_BACKEND),
    sessionPresent:Boolean(sessionStorage.getItem(key)),
    stateSignedIn:Boolean(window.TotiPhase2Auth?.state()?.signedIn),
    errorText:document.getElementById('auth-message')?.textContent?.slice(0,140)||''
  }),sessionKey);
  console.log('SESSION_QA_DIAGNOSTIC '+label+': '+JSON.stringify({ ...data,paths:calls.map(x=>x.path).slice(0,14) }));
}

test('cached session resumes after page reload only after server verification',async({page})=>{
  const calls=await mount(page);
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(350);
  await debugSession(page,'init',calls);
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeVisible({timeout:12000});
  expect(calls.some(x=>x.path==='/auth/v1/user')).toBe(true);
  expect(calls.some(x=>x.path==='/rest/v1/profiles')).toBe(true);
  await page.reload({waitUntil:'domcontentloaded'});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeVisible({timeout:20000});
  expect(await page.evaluate(key=>Boolean(sessionStorage.getItem(key)),sessionKey)).toBe(true);
});

test('sign out clears local session and remains signed out after reload',async({page})=>{
  const calls=await mount(page);
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeVisible({timeout:20000});
  await page.getByRole('button',{name:'Sign out'}).click();
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible();
  expect(calls.some(x=>x.path==='/auth/v1/logout'&&x.method==='POST')).toBe(true);
  expect(await page.evaluate(key=>sessionStorage.getItem(key),sessionKey)).toBeNull();
  expect(await page.evaluate(key=>localStorage.getItem(key),rememberKey)).toBeNull();
  await page.reload({waitUntil:'domcontentloaded'});
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible();
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeHidden();
});

test('expired access token rotates through refresh_token and restores verified session',async({page})=>{
  const calls=await mount(page,{initialSession:session({expiresIn:2})});
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeVisible({timeout:20000});
  expect(calls.some(x=>x.path==='/auth/v1/token'&&x.query.includes('grant_type=refresh_token'))).toBe(true);
  const value=await page.evaluate(key=>JSON.parse(sessionStorage.getItem(key)||'null'),sessionKey);
  expect(value?.access_token).toBe('synthetic-rotated');
  expect(value?.refresh_token).toBe('synthetic-rotated-refresh');
});

test('revoked session is rejected, not shown as verified, and cleared',async({page})=>{
  await mount(page,{userStatus:401});
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible({timeout:20000});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeHidden();
  await expect.poll(async()=>page.evaluate(key=>sessionStorage.getItem(key),sessionKey)).toBeNull();
});

test('invalid refresh token forces re-authentication instead of silent success',async({page})=>{
  const calls=await mount(page,{initialSession:session({expiresIn:2}),refreshStatus:401});
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible({timeout:20000});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeHidden();
  expect(calls.some(x=>x.path==='/auth/v1/token')).toBe(true);
  await expect.poll(async()=>page.evaluate(key=>sessionStorage.getItem(key),sessionKey)).toBeNull();
});

test('account identity mismatch cannot show the cached identity as verified',async({page})=>{
  const calls=await mount(page,{returnUser:{...user,id:'22222222-2222-4222-8222-222222222222'}});
  await page.goto(base,{waitUntil:'domcontentloaded'});
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible({timeout:20000});
  await expect(page.getByRole('heading',{name:"You're signed in"})).toBeHidden();
  expect(calls.some(x=>x.path==='/auth/v1/user')).toBe(true);
});
