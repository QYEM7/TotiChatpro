/* Agency and recharge mobile regression checks. Uses local demo only. */
const puppeteer=require('puppeteer-core');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>fs.existsSync(x));
if(!exe)throw Error('No browser on runner');
const base=process.env.UI_URL||'http://127.0.0.1:8765/app/';
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
 const page=await browser.newPage();await page.setViewport({width:390,height:844});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  await page.goto(base+'?view=agency-center',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('.tca-root');
  assert.equal(await page.$eval('.tca-role select',e=>e.value),'user');
  assert.ok(await page.$$eval('.tca-tile',e=>e.length)>=4);
  await page.evaluate(()=>go('rechargePreview'));
  await page.waitForSelector('[data-a="chargePick"]');
  const packs=await page.$$eval('[data-a="chargePick"]',e=>e.length);
  assert.equal(packs,6,'all 6 original packs remain present');
  await page.click('[data-a="chargePick"][data-v="1"]');
  assert.ok(await page.$('#overlay.show .tca-sheet'));
  assert.equal(await page.$$eval('[data-tca="choose-agent"]',e=>e.length),2);
  await page.click('[data-tca="choose-agent"][data-id="AG-1001"]');
  await page.click('[data-tca="new-order"]');
  await page.waitForSelector('.tca-root');
  assert.ok(await page.$('[data-tca="accept"]'));
  await page.click('[data-tca="accept"]');
  assert.ok(await page.$('[data-tca="paid"]'));
  await page.click('[data-tca="paid"]');
  assert.ok(await page.$('[data-tca="complete"]'));
  await page.click('[data-tca="complete"]');
  assert.ok(await page.$('[data-tca="rate"]'));
  await page.$eval('[data-tca="rate"]', el=>el.click());
  assert.ok(await page.$('#tca-stars'));
  await page.click('[data-tca="rate-save"]');
  await page.$eval('[data-tca="section"][data-id="overview"]',el=>el.click());
  await page.$eval('[data-tca="section"][data-id="ratings"]',el=>el.click());
  assert.ok(await page.$('.tca-root .tca-card'));
  // Original application agency screens are preserved with new entry point.
  await page.evaluate(()=>go('agencyPreview'));
  await page.waitForSelector('.ag-screen');
  assert.ok(await page.$('[data-tca="hub"]'));
  await page.$eval('[data-tca="hub"]',el=>el.click());
  await page.select('#tca-role','agent');
  await page.$eval('[data-tca="section"][data-id="staff"]',el=>el.click());
  await page.type('#tca-staff-id','9123456');
  await page.click('[data-tca="hire"]');
  assert.ok(await page.$eval('.tca-root',e=>e.textContent.includes('9123456')));
  await page.select('#tca-role','admin');
  await page.$eval('[data-tca="section"][data-id="approvals"]',el=>el.click());
  assert.ok(await page.$('[data-tca="hire-approve"]'));
  await page.click('[data-tca="hire-approve"]');
  // Reactualized role and navigation after agency creation.
  await page.evaluate(()=>go('home'));
  assert.ok(await page.$('.royal-home'));
  const bg=await page.$eval('.royal-home',el=>getComputedStyle(el).backgroundImage);
  assert.equal(bg,'none','page-sized wallpaper removed');
  assert.deepEqual(errors,[],'no browser runtime errors');
  console.log('PASS agency journey: pack, agents, chat, payment UX, rating, staff hire and approval. '+packs+' pack buttons retained.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
