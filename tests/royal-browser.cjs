// Browser-level UI regression coverage. Headless Chromium, no backend modifications.
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const path=require('node:path');
const dir=path.join(process.cwd(),'royal-preview-screenshots');
fs.mkdirSync(dir,{recursive:true});
const exe=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>fs.existsSync(x));
if(!exe)throw new Error('No system Chromium available on CI runner');
const base=process.env.UI_URL||'http://127.0.0.1:8765/app/';
const errors=[];
let browser;
async function load(page,query){
 await page.goto(base+query,{waitUntil:'domcontentloaded',timeout:30000});
 await page.waitForSelector('#app.rf-app',{timeout:20000});
 await new Promise(res=>setTimeout(res,120));
}
async function shot(page,name){
 await page.screenshot({path:path.join(dir,name+'.png'),fullPage:true});
}
(async()=>{
 browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
 const page=await browser.newPage();
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 await load(page,'?view=royal-home&review=1');
 assert.ok(await page.$('.rf-review-fab'));
 await page.click('[data-rf="review-list"]');
 assert.equal(await page.$$eval('.rf-review-grid button',x=>x.length),36);
 await page.click('[data-rf="review-route"][data-target="cp"]');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'cp');
 await shot(page,'00-review-navigator');
 await load(page,'?view=royal-home');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'home');
 assert.ok(await page.$('.royal-home'));
 assert.equal(await page.$$eval('.royal-room-tile',x=>x.length),6);
 assert.equal(await page.$('.royal-official'),null,'The bottom official-ad box must be absent');
 assert.ok(await page.$('.royal-hero'),'Top rotating promotional banner must be preserved');
 assert.ok(await page.$('.royal-near'),'Nearby rooms must remain present');
 // Five bottom destinations and the original falcon are shared by Home and Me.
 assert.equal(await page.$$eval('.royal-nav button',x=>x.length),5);
 assert.ok(await page.$('.royal-nav [data-v="me"] .tc-falcon-nav'));
 assert.equal(await page.$$eval('.tc-banner-controls .tc-banner-dot',x=>x.length)>=3,true);
 // Preserve coverage for the banner slot without racing its automatic slide timer.
 assert.ok(await page.$('.royal-hero img'));
 assert.equal(await page.$$eval('.tc-banner-dot',items=>items.length)>=3,true);
 await shot(page,'01-home-banner-second-slide');
 await page.click('.royal-nav [data-v="me"]');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'me');
 assert.equal(await page.$$eval('.tc-unified-nav button',x=>x.length),5);
 assert.equal(await page.$$eval('.me-royal .me-links .me-link',x=>x.length),4);
 assert.equal(await page.$$eval('.me-royal .me-more button',x=>x.length),5);
 assert.ok(await page.$('.tc-unified-nav [data-v="me"] .tc-falcon-nav'));
 // Premium profile statistics should remain readable and fully clickable.
 const stats=await page.$$eval('.me-royal > .me-statcard > button',items=>items.map(el=>({
   number:el.querySelector('b')?.textContent?.trim(),
   label:el.querySelector('small')?.textContent?.trim(),
   numberColor:getComputedStyle(el.querySelector('b')).color,
   labelColor:getComputedStyle(el.querySelector('small')).color
 })));
 assert.deepEqual(stats.map(({number,label})=>[number,label]),[
  ['240','متابعين'],['120','الأصدقاء'],['33','متابعة'],['0','زوار']
 ]);
 assert.equal(await page.$eval('.me-royal > .me-statcard',el=>el.classList.contains('tc-stats-luxe')),true,'Luxury statistics component must be mounted');
 assert.equal(await page.$$eval('.me-royal > .me-statcard > button .tc-stat-glyph',items=>items.length),4,'Each statistic has its own decorative icon');
 const background=await page.$eval('.me-royal > .me-statcard',el=>getComputedStyle(el).backgroundImage);
 assert.match(background,/rgb\(37, 17, 55\)|#251137|linear-gradient/i,'Stats panel must have the distinctive purple theme');
 assert.equal(stats[0].numberColor,'rgb(255, 227, 170)','Visible gold numbers must be used');
 assert.equal(stats[0].labelColor,'rgb(247, 234, 255)','Stat labels must have strong contrast');
 await shot(page,'01a-me-unified');
 await page.click('.me-royal > .me-statcard > button:first-child');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'friendsPreview','Statistics navigation must continue to work');
 await page.evaluate(()=>go('me'));
 await page.click('.tc-unified-nav [data-v="home"]');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'home');
 await shot(page,'01-home');
 await page.evaluate(()=>go('room'));
 await page.waitForSelector('.roomview.room-v2');
 assert.equal(await page.$$eval('.seats .seat',x=>x.length),15,'All 15 mic seats must remain present');
 assert.equal(await page.$('.rf-room-royal-ribbon'),null,'No unwanted voice slogan bar inside room');
 assert.equal(await page.$eval('.roomview .seats',el=>getComputedStyle(el).borderTopWidth),'0px','Remove outer seat grid border');
 assert.equal(await page.$eval('.roomview .seats',el=>getComputedStyle(el).backgroundImage),'none','Remove outer seat grid background');
 assert.equal(await page.$$eval('.seats .seatface',els=>els.length),15,'Keep all 15 clickable seat avatars');
 assert.equal(await page.$$eval('.seats .seat .seatname',els=>els.length),15,'Keep all seat labels');
 assert.ok(await page.$('[data-a="sheet"][data-v="games"]'));
 await shot(page,'02-room');
 await load(page,'?screen=room&view=share&owner=1');
 assert.ok(await page.$('.royal-feature-share'));
 assert.ok(await page.$('.royal-feature-share .rp-unified-close'));
 await page.click('[data-tc="friend"]');
 assert.equal(await page.$eval('#tc-share-count',e=>e.textContent),'1');
 await shot(page,'03-share');
 await load(page,'?screen=room&view=settings&owner=1');
 assert.ok(await page.$('.royal-feature-settings'));
 assert.ok(await page.$('.royal-feature-settings .rp-unified-close'));
 await page.click('[data-royal="seat-select"][data-count="8"]');
 assert.equal(await page.$eval('#tc-seat-count',e=>e.value),'8');
 await shot(page,'04-settings');
 await load(page,'?screen=room&view=games&owner=1');
 assert.ok(await page.$('.royal-feature-games'));
 await shot(page,'05-games');
 await page.click('[data-tc="start-game"][data-game="xo"]');
 assert.equal(await page.$$eval('.tc-xo button',x=>x.length),9);
 await page.click('.tc-xo button:first-child');
 assert.ok(await page.$eval('.tc-xo button:first-child',e=>e.textContent.trim()));
 await load(page,'?screen=room&view=minimized&owner=1');
 assert.ok(await page.$('.tc-mini-room'));
 assert.ok(await page.$('.tc-mini-room img'));
 await shot(page,'06-minimized');
 await page.evaluate(()=>document.querySelector('[data-a="restoreRoom"]')?.click());
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'room');

 // Unified X must be part of the room menu, not floating outside.
 await page.evaluate(()=>sheet('roomExitMenu'));
 await page.waitForSelector('.rp-room-menu-head .rp-unified-close');
 assert.ok(await page.$('.rp-room-menu-head .rp-unified-close svg'));
 const closeLocation=await page.$eval('.rp-room-menu-head .rp-unified-close',b=>{
  const a=b.getBoundingClientRect(),p=b.closest('.room-glass').getBoundingClientRect();
  return {inside:a.top>=p.top&&a.bottom<=p.bottom&&a.left>=p.left&&a.right<=p.right,w:a.width,h:a.height};
 });
 assert.equal(closeLocation.inside,true,'Room X must be INSIDE dialog');
 assert.equal(closeLocation.w,42);
 assert.equal(closeLocation.h,42);
 await shot(page,'07-room-menu-close');
 await page.click('.rp-room-menu-head .rp-unified-close');
 assert.equal(await page.$eval('#overlay',el=>el.classList.contains('show')),false);
 // Every level has its own generated vector emblem, with 100 selectable levels.
 await page.evaluate(()=>go('level'));
 assert.equal(await page.$$eval('.rp-level-groups button',xs=>xs.length),10);
 assert.equal(await page.$$eval('.rp-level-card',xs=>xs.length),10);
 assert.equal(await page.$$eval('.rp-level-card svg',xs=>xs.length),10);
 assert.ok(await page.$('.rp-level-card[data-level="45"]'));
 await shot(page,'08-royal-level-badges-41-to-50');
 await page.click('.rp-level-groups button[data-group="9"]');
 assert.ok(await page.$('.rp-level-card[data-level="100"]'));
 assert.equal(await page.$$eval('.rp-level-card[data-level] svg',els=>new Set(els.map(e=>e.getAttribute('aria-label'))).size),10);
 await shot(page,'09-royal-level-badges-91-to-100');
 await page.click('.rp-level-card[data-level="100"]');
 assert.ok(await page.$('.rp-badge-detail .rp-unified-close'));
 await page.click('.rp-badge-detail .rp-unified-close');
 assert.equal(await page.$eval('#overlay',el=>el.classList.contains('show')),false);
 await page.evaluate(()=>go('honor'));
 assert.equal(await page.$$eval('.rp-honor-card',xs=>xs.length),9);
 assert.equal(await page.$$eval('.rp-honor-icon svg',xs=>xs.length),9);
 await shot(page,'10-royal-achievement-badges');
 await page.click('.rp-honor-card');
 assert.ok(await page.$('#overlay .rp-unified-close'));
 await page.click('#overlay .rp-unified-close');
 assert.equal(await page.$eval('#overlay',el=>el.classList.contains('show')),false);

 const routes=[
 'me','profilePreview','profileEdit','messages','chatPreview','settings','storage','honor','level','ranks','agency','agencyPreview',
 'agencyApply','agencyStatusPreview','agencyJoinPreview','vip','wallet','rechargePreview','storePreview','bagPreview','friendsPreview',
 'discoverPreview','notificationsPreview','missionsPreview','treasurePreview','musicPreview','roomAdminPreview','gamesPreview',
 'giftsPreview','loginPreview','signupPreview','welcomePreview','tour','languages','block','report'
 ];
 for(const route of routes){
   await page.evaluate(x=>go(x),route);
   const hasContent=await page.$eval('#app',e=>e.textContent.trim().length>20);
   assert.ok(hasContent,'Blank UI '+route);
   assert.equal(await page.$eval('#app',e=>e.dataset.route),route,'Wrong route '+route);
   if(['me','vip','cp','storePreview','agencyPreview','profilePreview','musicPreview'].includes(route))await shot(page,'route-'+route);
 }

 // 15 distinct interactive VIP levels, previews, benefits, tabs and no backend writes.
 await load(page,'?view=royal-vip&vip=1');
 assert.equal(await page.$eval('#app',el=>el.dataset.route),'vip');
 assert.equal(await page.$$eval('.rvip-tier',els=>els.length),15);
 assert.equal(await page.$$eval('.rvip-tier .rvip-crest',els=>els.length),15);
 assert.equal(await page.$$eval('.rvip-tier .rvip-crest',els=>new Set(els.map(el=>el.getAttribute('aria-label'))).size),15);

 // SVG elements are deliberately isolated as cached image surfaces, not
 // duplicated inline defs. This targets Android checkerboard artifacts.
 const imagesStable=async()=>{
  return page.$$eval('.rvip-root img.rvip-crest',els=>({
   count:els.length,allDecoded:els.every(el=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0),
   selfContained:els.every(el=>el.src.startsWith('data:image/svg+xml;charset=utf-8,')),
   dimensions:els.map(el=>({w:el.naturalWidth,h:el.naturalHeight})),
   duplicates:document.querySelectorAll('.rvip-root [id^="rvip"]').length
  }));
 };
 await page.evaluate(()=>Promise.all([...document.querySelectorAll('.rvip-root img.rvip-crest')].map(el=>el.decode())));
 let vipImgCheck=await imagesStable();
 assert.equal(vipImgCheck.selfContained,true,'VIP artwork must have private image namespace');
 assert.equal(vipImgCheck.allDecoded,true,'All 15 VIP crests must decode');
 assert.equal(vipImgCheck.duplicates,0,'No inline SVG gradient IDs should collide');
 assert.ok(vipImgCheck.count>=15);

 assert.ok(await page.$('.rvip-hero-crest .rvip-crest[aria-label^="شارة VIP 1 "]'));
 await shot(page,'11-vip-01-royal');
 await page.click('[data-vip15="select"][data-level="15"]');
 assert.ok(await page.$('.rvip-hero-crest .rvip-crest[aria-label^="شارة VIP 15 "]'));
 assert.equal(await page.$eval('[data-vip15="select"][data-level="15"]',el=>el.getAttribute('aria-pressed')),'true');
 await shot(page,'12-vip-15-supreme');

 // Stress the original intermittent repro: switch tiers and pages while the
 // horizontal gallery scrolls, then force an image decode after the transition.
 for(let k=0;k<24;k++){
  const t=[13,1,15,8,9,12][k%6];
  await page.evaluate(level=>document.querySelector('[data-vip15="select"][data-level="'+level+'"]')?.click(),t);
  if(k%4===0)await page.evaluate(()=>document.querySelector('[data-vip15="tab"][data-tab="المميزات"]')?.click());
  else if(k%4===1)await page.evaluate(()=>document.querySelector('[data-vip15="tab"][data-tab="معلومات"]')?.click());
  await page.evaluate(()=>Promise.all([...document.querySelectorAll('.rvip-root img.rvip-crest')].map(el=>el.decode())));
  vipImgCheck=await imagesStable();
  assert.equal(vipImgCheck.allDecoded,true,'A VIP crest failed after redraw '+k);
  assert.equal(vipImgCheck.duplicates,0,'Duplicate SVG gradient after redraw '+k);
 }
 await page.evaluate(()=>document.querySelector('[data-vip15="select"][data-level="13"]')?.click());
 await page.evaluate(()=>Promise.all([...document.querySelectorAll('.rvip-root img.rvip-crest')].map(el=>el.decode())));
 await shot(page,'12b-vip-13-after-24-transitions');
 await page.evaluate(()=>document.querySelector('[data-vip15="select"][data-level="15"]')?.click());

 await page.click('[data-vip15="tab"][data-tab="المميزات"]');
 assert.equal(await page.$$eval('.rvip-benefit:not(.locked)',els=>els.length),15);
 await shot(page,'13-vip-15-perks');
 await page.click('[data-vip15="select"][data-level="4"]');
 assert.equal(await page.$$eval('.rvip-benefit:not(.locked)',els=>els.length),4);
 await page.click('[data-vip15="tab"][data-tab="المعاينة"]');
 assert.ok(await page.$('.rvip-scenario-avatar .rvip-crest'));
 assert.ok(await page.$('.rvip-enter-line .rvip-crest'));
 await shot(page,'14-vip-04-app-preview');
 await page.click('[data-vip15="effect"]');
 assert.ok(await page.$('.rvip-effect-overlay'));
 await page.click('[data-vip15="tab"][data-tab="الأسعار"]');
 assert.ok(await page.$('.rvip-buy-panel'));
 assert.equal(await page.$eval('.rvip-privacy',el=>el.textContent.includes('لا تعديل')),true);
 await load(page,'?view=royal-vip&vip=15');
 await page.click('[data-vip15="tab"][data-tab="الأسعار"]');
 assert.match(await page.$eval('.rvip-buy-panel',el=>el.textContent),/السعر غير معتمد/);
 await page.click('[data-vip15="upgrade"]');
 assert.ok(await page.$('#overlay .rvip-detail'));
 assert.ok(await page.$('#overlay .rp-unified-close'));
 await page.click('#overlay .rp-unified-close');
 assert.equal(await page.$eval('#overlay',el=>el.classList.contains('show')),false);

 await load(page,'?view=royal-level');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'level');
 assert.equal(await page.$$eval('.rp-level-card',xs=>xs.length),10);
 await load(page,'?view=royal-achievements');
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'honor');
 assert.equal(await page.$$eval('.rp-honor-card',xs=>xs.length),9);
 assert.equal(errors.length,0,'Browser JS errors: '+errors.join(' | '));
 console.log('Royal browser QA passed: 6 major flows, '+routes.length+' routes, 15 unchanged seats, 0 uncaught page errors');
})().catch(e=>{console.error(e.stack||e);process.exitCode=1}).finally(async()=>{if(browser)await browser.close()});