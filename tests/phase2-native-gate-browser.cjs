/* Android beta honesty check: default first launch MUST NOT show fake accounts,
 * demo rooms, VIP balances or pretend to be connected. No real user is created.
 */
'use strict';
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const executablePath=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser']
 .find(p=>fs.existsSync(p));
if(!executablePath)throw Error('System chromium unavailable');
(async()=>{
 const browser=await puppeteer.launch({executablePath,headless:true,args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  const page=await browser.newPage();await page.setViewport({width:390,height:844});
  const uid='94c0e8fb-126e-4149-ad30-6f25e3c99c33';
  const authResult={access_token:'test-access',refresh_token:'test-refresh',expires_in:3600,
   user:{id:uid,email:'newuser@test.invalid'}};
  const userProfile={id:uid,display_name:'الحساب الحقيقي',bio:'',
   avatar_url:null,created_at:'2026-10-10T00:00:00Z',updated_at:'2026-10-10T00:00:00Z'};
  await page.setRequestInterception(true);
  page.on('request',r=>{
   const url=r.url(),method=r.method();
   if(!url.startsWith('https://sqedsnyvjblvbjbizcay.supabase.co/'))return r.continue();
   const path=new URL(url).pathname;
   const response=path==='/auth/v1/token'?authResult:
    path==='/rest/v1/profiles'?[userProfile]:
    path==='/rest/v1/wallets'?[{user_id:uid,coins:0,diamonds:0,updated_at:'2026-10-10T00:00:00Z'}]:
    path==='/rest/v1/wallet_ledger'?[]:
    path==='/rest/v1/rooms'||path==='/rest/v1/room_members'||path==='/rest/v1/home_banners'?[]:
    path==='/auth/v1/user'?authResult.user:[];
   return r.respond({status:200,contentType:'application/json',headers:{
    'access-control-allow-origin':'*','access-control-allow-headers':'authorization,apikey,content-type,prefer',
    'access-control-allow-methods':'GET,POST,PATCH,OPTIONS'
   },body:JSON.stringify(response)});
  });
  // Force the identical live startup behavior on the local HTTP test origin.
  await page.goto('http://127.0.0.1:8765/dist/?mode=live',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#app.rf-app');
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='loginPreview');
  assert.equal(await page.$('.royal-room-tile'),null,'No demo rooms displayed before login');
  assert.ok(await page.$('.tc-login-layout'),'Official responsive clean login must be mounted');
  assert.equal(await page.$eval('.royal-nav,.bottom',items=>items.length),0,
    'No distracting bottom navigation on Login');
  assert.ok(await page.$('.tc-login-brand img'),'Approved official falcon must display');
  assert.match(await page.$eval('.tc-login-intro h1',x=>x.textContent),/مرحباً بعودتك/);
  assert.equal(await page.$eval('[data-auth-social]',items=>items.length),3);
  await page.$eval('[data-auth-action="toggle-password"]',b=>b.click());
  assert.equal(await page.$eval('#fc-pass',el=>el.type),'text','Show password works');
  await page.$eval('[data-auth-action="toggle-password"]',b=>b.click());
  assert.equal(await page.$eval('#fc-pass',el=>el.type),'password','Hide password works');
  await page.$eval('[data-auth-route="signupPreview"]',b=>b.click());
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='signupPreview');
  assert.ok(await page.$('#fc-name'),'Signup fields genuinely exist');
  await page.$eval('[data-auth-route="loginPreview"]',b=>b.click());
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='loginPreview');
  await page.type('#fc-email','newuser@test.invalid');
  await page.type('#fc-pass','strong-password');
  await page.$eval('[data-fc="validate-auth"]',b=>b.click());
  await page.waitForFunction(()=>window.TotiPhase2Auth?.state()?.profile?.display_name==='الحساب الحقيقي');
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='home');
  await page.waitForFunction(()=>window.TotiPhase2Rooms?.getStatus()?.roomCount===0);
  assert.equal(await page.$$eval('.royal-room-gallery .royal-room-tile',i=>i.length),0,
   'Signed-in user sees zero real rooms instead of six fake ones');
  assert.ok(await page.$('#tc-phase2-online-state'),'Live UI states supported capabilities clearly');
  await page.evaluate(()=>go('me'));
  const numbers=await page.$$eval('.me-royal .me-statcard button b',e=>e.map(x=>x.textContent.trim()));
  assert.equal(numbers.length,4);
  assert.ok(numbers.every(x=>x==='—'),'Never show demo follower counts as real');
  assert.equal(await page.$('.me-agency'),null,'Fake agency membership must be hidden');
  await page.evaluate(()=>go('profilePreview'));
  const fakeBio=await page.$eval('.pr-about',e=>e.textContent);
  assert.notEqual(fakeBio,'هذا المستخدم غامض، ولم يترك شيئاً');
  assert.equal(await page.$('.pr-agencywide'),null);
  await page.evaluate(()=>go('wallet'));
  await page.waitForFunction(()=>window.TotiPhase2Wallet?.status()?.loaded===true);
  assert.equal(await page.$eval('#app',e=>e.dataset.route),'wallet','Real wallet must be accessible');
  assert.match(await page.$eval('.visual-hero h2',e=>e.textContent),/^0 🪙$/);
  assert.match(await page.$eval('.visual-hero p',e=>e.textContent),/^0 ماسة/);
  assert.ok(await page.$('#tc-live-wallet-records'),'Journal is from server, no demo entries');
  assert.equal(await page.$('.visual-product-grid'),null,'Never show fake coin packages');
  console.log('PASS: Official falcon login, no fake guest mode, sign-in, server zero wallet and empty room state');
 }finally{await browser.close();}
})().catch(err=>{console.error(err.stack||err);process.exitCode=1;});
