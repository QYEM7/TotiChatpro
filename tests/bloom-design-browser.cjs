// TotiChat Bloom Signature visual contract: no removed seats or VIP crests, no broken UI.
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>fs.existsSync(x));
if(!exe)throw Error('Chromium required');
const base=process.env.UI_URL||'http://127.0.0.1:8765/app/';
(async()=>{
const b=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
const p=await b.newPage();await p.setViewport({width:390,height:844,deviceScaleFactor:1});
const errors=[];p.on('pageerror',e=>errors.push(e.message));
try{
 await p.goto(base+'?view=royal-home',{waitUntil:'domcontentloaded'});
 await p.waitForSelector('.royal-home');
 assert.equal(await p.$$eval('.royal-cat',els=>els.length),7);
 assert.equal(await p.$$eval('.royal-room-tile',els=>els.length),6);
 const home=await p.evaluate(()=>{
  const s=t=>getComputedStyle(document.querySelector(t));
  return {background:s('.royal-home').backgroundImage,heroRadius:parseFloat(s('.royal-hero').borderTopLeftRadius),catRadius:parseFloat(s('.royal-cat').borderTopLeftRadius),brand:s('.royal-brand').color};
 });
 assert.equal(home.background,'none','no large photographic wallpaper on main page');
 assert.ok(home.heroRadius>=20&&home.catRadius>=16,'tactile, high-detail home cards');
 const tokens=await p.evaluate(()=>{const s=getComputedStyle(document.documentElement);return ['--tc-royal','--tc-pink','--tc-background','--tc-turquoise','--tc-gold','--tc-white','--tc-text'].map(k=>s.getPropertyValue(k).trim().toUpperCase());});
 assert.deepEqual(tokens,['#7656D9','#FF79AC','#F7F5FF','#55D6CF','#F6C66A','#FFFFFF','#292344'],'official Royal Purple & Pink token contract');
 assert.ok(home.brand.includes('76, 41, 138')||home.brand.includes('118, 86, 217'),'royal brand visible');
 await p.evaluate(()=>go('room'));
 await p.waitForSelector('.seats .seat');
 assert.equal(await p.$$eval('.seats .seat',els=>els.length),15);
 const roomBg=await p.$eval('.roomview',el=>getComputedStyle(el).backgroundImage);
 assert.ok(roomBg.includes('gradient'),'voice room has ambient stage atmosphere');
 assert.ok(roomBg.includes('room_wallpaper_crown_queen_1790560306491.jpg'),'preserve original room wallpaper under tonal lighting');
 assert.equal(await p.$$eval('.seats .seat',es=>es.filter(e=>getComputedStyle(e).display==='none').length),0,'never hide microphone seats');
 await p.evaluate(()=>go('vip'));
 await p.waitForSelector('.rvip-tier .rvip-crest');
 assert.equal(await p.$$eval('.rvip-tier .rvip-crest',els=>els.length),15);
 assert.equal(await p.$eval('.rvip-crest',el=>getComputedStyle(el).filter),'none','Android paint fix must survive');
 await p.goto(base+'?view=agency-center',{waitUntil:'domcontentloaded'});
 await p.waitForSelector('.tca-root');
 await p.select('#tca-role','agent');
 assert.ok(await p.$$eval('.tca-tile .tca-svg',els=>els.length)>=10,'agency buttons use consistent SVG icons');
 const card=await p.$eval('.tca-tile',el=>({radius:parseFloat(getComputedStyle(el).borderRadius),bg:getComputedStyle(el).backgroundImage}));
 assert.ok(card.radius>=18&&card.bg.includes('gradient'),'agency tools have crafted visual treatment');
 await p.evaluate(()=>go('rechargePreview'));
 assert.equal(await p.$$eval('[data-a="chargePick"]',els=>els.length),6);
 assert.deepEqual(errors,[],'no JavaScript runtime errors');
 console.log('PASS Royal Purple & Pink Reference #1: lively surfaces, 15 seats, all VIP icons, 14 agency tools, 6 coin packages.');
}finally{await b.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1});
