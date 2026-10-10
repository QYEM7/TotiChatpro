/* T09: no production access, Supabase requests are mocked by interception. */
'use strict';
const puppeteer=require('puppeteer-core');
const fs=require('node:fs'),assert=require('node:assert/strict');
const executablePath=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser']
 .find(p=>fs.existsSync(p));
if(!executablePath)throw Error('Chromium missing');
(async()=>{
 const browser=await puppeteer.launch({executablePath,headless:true,args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  const page=await browser.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
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
  for(const width of [320,360,390,430,768,1280]){
   await page.setViewport({width,height:844});
   await page.goto('http://127.0.0.1:8765/dist/?mode=live&phase2Demo=1',{waitUntil:'domcontentloaded'});
   await page.waitForSelector('.tc-login-layout');
   await page.waitForFunction(()=>window.TotiLiveMode?.enabled===true);
   const result=await page.evaluate(()=>({
    route:document.querySelector('#app')?.dataset.route,
    field:document.querySelector('#fc-email')?.getBoundingClientRect().width||0,
    logo:document.querySelector('.tc-login-brand img')?.naturalWidth||0,
    nav:document.querySelectorAll('.royal-nav,.bottom').length,
    demo:!!window.TotiLiveMode?.isPreview?.(),
    scroll:document.documentElement.scrollWidth,bodyScroll:document.body.scrollWidth
   }));
   assert.equal(result.route,'loginPreview','Live auth required '+width);
   assert(result.field>100&&result.logo>0,'Approved login/logo visible '+width);
   assert.equal(result.nav,0,'No guest demo navigation');
   assert.equal(result.demo,false,'Query must not enable visual-only mode');
   assert(Math.max(result.scroll,result.bodyScroll)<=width+2,'Horizontal overflow '+width+': '+JSON.stringify(result));
   if([320,390,1280].includes(width)){
    await fs.promises.mkdir('royal-preview-screenshots',{recursive:true});
    await page.screenshot({path:'royal-preview-screenshots/t09-live-'+width+'.png',fullPage:true});
   }
  }
  assert.deepEqual(errors,[],'Unexpected browser errors');
  console.log('PASS T09/T11: 320,360,390,430,768,1280 live layout and protected login');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
