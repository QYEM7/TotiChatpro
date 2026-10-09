/* Android WebView startup regression: exercise the EXACT generated dist/index.html,
 * NOT /app/ (which previously worked on GitHub Pages but was blank inside the APK).
 * Uses a local-only origin matching Capacitor's root path semantics.
 */
'use strict';
const puppeteer=require('puppeteer-core');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const exe=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser']
 .find(p=>fs.existsSync(p));
if(!exe)throw new Error('Chromium is required for Android root-page preflight');
const base=process.env.ANDROID_ROOT_URL||'http://127.0.0.1:8765/dist/';
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:exe,
   args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  const page=await browser.newPage();
  await page.setViewport({width:390,height:844,deviceScaleFactor:1});
  const missing=[],runtime=[];
  page.on('pageerror',e=>runtime.push(e.message));
  page.on('response',r=>{
    if(r.status()===404 && r.url().startsWith(base))missing.push(r.url());
  });
  await page.setRequestInterception(true);
  page.on('request',req=>{
    const url=req.url();
    if(url.startsWith('https://sqedsnyvjblvbjbizcay.supabase.co/')){
      return req.respond({status:200,contentType:'application/json',headers:{
        'access-control-allow-origin':'*','access-control-allow-headers':'*'
      },body:'[]'});
    }
    if(url.startsWith('http://127.0.0.1:8765/'))return req.continue();
    // Bundled UI must display offline without external web fonts or online images.
    return req.abort();
  });
  await page.goto(base,{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForSelector('#app.rf-app',{timeout:18000});
  await page.waitForSelector('.royal-home',{timeout:18000});
  const root=await page.evaluate(()=>({
    url:location.href,
    base:document.baseURI,
    route:document.querySelector('#app')?.dataset.route,
    tiles:document.querySelectorAll('.royal-room-tile').length,
    nav:document.querySelectorAll('.royal-nav button').length,
    hero:!!document.querySelector('.royal-hero'),
    appText:document.querySelector('#app')?.textContent?.slice(0,350)||'',
    logo:[...document.querySelectorAll('img')].filter(i=>
      i.src.includes('toti_falcon_logo_')).map(i=>({loaded:i.complete&&i.naturalWidth>0,src:i.src})),
  }));
  assert.equal(root.route,'home','App must start on Home, not the WebView fallback link');
  assert.equal(root.tiles,6,'Approved room cards must appear on Android first launch');
  assert.equal(root.nav,5,'Bottom navigation must be present on Android');
  assert.ok(root.hero,'Approved home promotional banner must render');
  assert.ok(root.logo.some(x=>x.loaded),'Bundled falcon logo must load from app assets');
  assert.ok(root.base.endsWith('/dist/app/'),root.base+' must resolve to bundled app');
  assert.ok(root.appText.length>100,'Blank screen regression detected');
  assert.deepEqual(missing,[],'Packaged local asset paths cannot 404: '+missing.join('; '));
  assert.deepEqual(runtime,[],'Root app cannot throw on launch: '+runtime.join('; '));
  await page.$eval('.royal-nav [data-v="me"]',el=>el.click());
  assert.equal(await page.$eval('#app',x=>x.dataset.route),'me','Bottom navigation must work on Android root');
  await page.evaluate(()=>go('room'));
  assert.equal(await page.$$eval('.seats .seat',els=>els.length),15,'All 15 microphone seats remain');
  console.log('PASS Android root: full Home, 6 room cards, 5 tabs, images, Me, 15 seats; no redirects or missing assets');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
