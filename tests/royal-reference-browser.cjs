/* TotiChat reference #1 visual regression — mobile browser, read-only UI. */
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const path=require('node:path');
const out=path.join(process.cwd(),'royal-preview-screenshots');
fs.mkdirSync(out,{recursive:true});
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>fs.existsSync(x));
if(!exe)throw Error('Chromium not available for branch QA');
const url=process.env.UI_URL||'http://127.0.0.1:8765/app/';
(async()=>{
 const browser=await puppeteer.launch({executablePath:exe,headless:true,args:['--no-sandbox','--disable-setuid-sandbox']});
 const page=await browser.newPage(),issues=[];
 page.on('pageerror',e=>issues.push(e.message));
 try{
  for(const w of [350,390,440]){
   await page.setViewport({width:w,height:844,deviceScaleFactor:1});
   await page.goto(url+'?view=royal-home',{waitUntil:'domcontentloaded'});
   await page.waitForSelector('.royal-home');
   const {palette,homeBg,bodyOverflow}=await page.evaluate(()=>{
    const get=k=>getComputedStyle(document.documentElement).getPropertyValue(k).trim().toUpperCase();
    return{palette:['--tc-royal','--tc-pink','--tc-background','--tc-turquoise','--tc-gold','--tc-white','--tc-text'].map(get),
     homeBg:getComputedStyle(document.querySelector('.royal-home')).backgroundColor,
     bodyOverflow:document.documentElement.scrollWidth-innerWidth};
   });
   assert.deepEqual(palette,['#7656D9','#FF79AC','#F7F5FF','#55D6CF','#F6C66A','#FFFFFF','#292344']);
   assert.ok(bodyOverflow<=2,'mobile horizontal overflow on home width '+w+': '+bodyOverflow);
   assert.equal(await page.$$eval('.royal-cat',els=>els.length),7);
   assert.equal(await page.$$eval('.royal-room-tile',els=>els.length),6);
   assert.ok(homeBg.includes('247, 245, 255'),'reference light background must render');
   await page.screenshot({path:path.join(out,'reference1-home-'+w+'.png'),fullPage:false});
   await page.evaluate(()=>go('room'));
   assert.equal(await page.$$eval('.seats .seat',els=>els.length),15);
   assert.equal(await page.$$eval('.seats .seat',els=>els.filter(el=>getComputedStyle(el).display==='none'||getComputedStyle(el).visibility==='hidden').length),0);
   const wallpaper=await page.$eval('.roomview',el=>getComputedStyle(el).backgroundImage);
   assert.ok(wallpaper.includes('room_wallpaper_crown_queen_1790560306491.jpg'),'original room art missing');
   assert.ok(await page.$('.giftTicker'),'gift activity ribbon kept');
   assert.ok(await page.$('.chatArea'),'chat and events kept');
   assert.ok(await page.$('.roomBottom button.gift'),'gift interaction remains');
   await page.screenshot({path:path.join(out,'reference1-room-'+w+'.png'),fullPage:false});
   await page.evaluate(()=>go('vip'));
   assert.equal(await page.$$eval('.rvip-tier .rvip-crest',els=>els.length),15);
   assert.equal(await page.$eval('.rvip-crest',el=>getComputedStyle(el).filter),'none','VIP Android image fix');
  }
  await page.setViewport({width:390,height:844});
  for(const route of ['cp','me','profilePreview','profileEdit','wallet','rechargePreview','storePreview','bagPreview','agencyPreview','agencyApply','musicPreview','gamesPreview','settings','notificationsPreview','friendsPreview','roomAdminPreview','honor','level','ranks']){
   await page.evaluate(name=>go(name),route);
   assert.equal(await page.$eval('#app',el=>el.dataset.route),route,'missing route '+route);
   assert.ok((await page.$eval('#app',el=>el.textContent.trim().length))>=70,'suspicious empty screen '+route);
   if(['cp','wallet','agencyPreview','storePreview','musicPreview'].includes(route))
    await page.screenshot({path:path.join(out,'reference1-'+route+'.png'),fullPage:false});
  }
  await page.evaluate(()=>go('room'));
  await page.$eval('[data-a="sheet"][data-v="gift"]',el=>el.click());
  assert.ok(await page.$('#overlay.show'),'gift sheet fails to open');
  await page.goto(url+'?view=agency-center',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('.tca-root');
  assert.ok(await page.$('.tca-banner'),'agency hub accessible');
  await page.screenshot({path:path.join(out,'reference1-agency.png'),fullPage:false});
  assert.deepEqual(issues,[],'JavaScript exception');
  console.log('PASS Royal Purple & Pink UI: 350/390/440px, 15 seats and VIP, original room wallpaper, gift, 19 routes, 7 colors.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
