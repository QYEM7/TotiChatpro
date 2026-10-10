/* Official Login visual/functional regression against Android dist root.
 * No personal accounts created: Auth provider settings are controlled fixtures.
 */
'use strict';
const puppeteer=require('puppeteer-core');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const executablePath=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser']
 .find(p=>fs.existsSync(p));
if(!executablePath)throw Error('Chrome/Chromium needed');
(async()=>{
 const browser=await puppeteer.launch({executablePath,headless:true,
  args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  const page=await browser.newPage();
  const failed=[];
  page.on('pageerror',e=>failed.push(e.message));
  await page.setRequestInterception(true);
  page.on('request',req=>{
   const u=req.url();
   if(u.startsWith('https://sqedsnyvjblvbjbizcay.supabase.co/')){
    return req.respond({status:200,contentType:'application/json',
     headers:{'access-control-allow-origin':'*','access-control-allow-headers':'authorization,apikey,content-type'},
     body:JSON.stringify(u.includes('/auth/v1/settings')?{external:{google:false,apple:false,facebook:false}}:[])});
   }
   if(u.startsWith('http://127.0.0.1:8765/'))return req.continue();
   return req.abort();
  });
  await page.setViewport({width:1280,height:850});
  await page.goto('http://127.0.0.1:8765/dist/?mode=live',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('.tc-login-layout');
  const desktop=await page.evaluate(()=>{
   const a=document.querySelector('.tc-login-layout');
   const right=document.querySelector('.tc-login-panel');
   const left=document.querySelector('.tc-login-art');
   const rect=a.getBoundingClientRect(),pr=right.getBoundingClientRect(),lr=left.getBoundingClientRect();
   return {total:rect.width,right:pr.width,left:lr.width,artVisible:getComputedStyle(left).display!=='none',
    falcon:document.querySelector('.tc-login-brand img')?.naturalWidth||0,
    usernameField:!!document.getElementById('fc-email'),
    footer:!!document.querySelector('.tc-login-footer'),
    nav:document.querySelectorAll('.royal-nav,.bottom,.tc-unified-nav').length};
  });
  assert.ok(desktop.artVisible,'Desktop art column must display');
  assert.ok(Math.abs(desktop.right-desktop.left)<=2,'Desktop must be 50/50 '+JSON.stringify(desktop));
  assert.ok(desktop.falcon>0,'Official logo file must load');
  assert.ok(desktop.usernameField&&desktop.footer);
  assert.equal(desktop.nav,0,'Auth page must not show app tabs');
  await new Promise(resolve=>setTimeout(resolve,800));
  await fs.promises.mkdir('royal-preview-screenshots',{recursive:true});
  await page.screenshot({path:'royal-preview-screenshots/official-login-desktop.png',fullPage:true});
  await page.setViewport({width:390,height:844});
  await page.waitForFunction(()=>getComputedStyle(document.querySelector('.tc-login-art')).display==='none');
  const mobile=await page.evaluate(()=>({
    content:document.querySelector('.tc-login-panel').getBoundingClientRect().width,
    body:document.body.scrollWidth,
    isVisible:document.querySelector('#fc-email').getBoundingClientRect().width>50,
    socials:document.querySelectorAll('.tc-social-button').length,
    enabledSocial:[...document.querySelectorAll('.tc-social-button')].filter(b=>!b.disabled).length,
    secret:document.querySelector('#fc-pass').type
  }));
  assert.ok(mobile.content<=390&&mobile.isVisible,'Mobile form must fit');
  assert.ok(mobile.body<=391,'No horizontal overflow');
  assert.equal(mobile.socials,3);
  assert.equal(mobile.enabledSocial,0,'Disabled providers cannot pretend to work');
  assert.equal(mobile.secret,'password');
  await page.screenshot({path:'royal-preview-screenshots/official-login-mobile.png',fullPage:true});
  await page.$eval('[data-auth-action="toggle-password"]',x=>x.click());
  assert.equal(await page.$eval('#fc-pass',x=>x.type),'text');
  await page.$eval('[data-auth-action="toggle-password"]',x=>x.click());
  assert.equal(await page.$eval('#fc-pass',x=>x.type),'password');
  await page.$eval('[data-auth-route="passwordResetPreview"]',x=>x.click());
  assert.ok(await page.$('#fc-email'),'Password recovery form must work');
  await page.$eval('[data-auth-route="loginPreview"]',x=>x.click());
  await page.$eval('[data-auth-route="signupPreview"]',x=>x.click());
  assert.ok(await page.$('#fc-name'),'Signup name required');
  assert.ok(await page.$('#fc-confirm'),'Signup confirmation required');
  assert.equal(failed.length,0,'Unexpected browser errors: '+failed.join('; '));
  console.log('PASS official login: 50/50 desktop, one-column mobile, falcon, focus/OTP/forgot/signup, safe provider states');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
