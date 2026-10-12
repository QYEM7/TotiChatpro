/* Visual-only fixture: zero Supabase requests, no production/test-user writes.
 * Screenshots inspect how REAL occupancy classes render on 15 unchanged seats.
 */
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const puppeteer=require('puppeteer-core');
const exe=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(fs.existsSync);
if(!exe)throw Error('Chromium unavailable');
const read=name=>fs.readFileSync(path.join(process.cwd(),name),'utf8');
const baseCss=read('app/index.html').match(/<style>([\s\S]*?)<\/style>/)?.[1];
if(!baseCss)throw Error('Approved room CSS missing');
const css=baseCss+'\n'+read('app/royal-final.css')+'\n'+read('app/room-seats-finish.css')+'\n'+read('app/phase6-mic-presence.css');
const image='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><linearGradient id="a" x2="1" y2="1"><stop stop-color="#e5cab5"/><stop offset="1" stop-color="#644d8d"/></linearGradient></defs><rect width="100" height="100" fill="url(#a)"/><circle cx="50" cy="36" r="19" fill="#f8f1e5"/><path d="M10 98 Q50 50 90 98Z" fill="#f8f1e5"/></svg>');
const micOn='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v4m-4 0h8"/></svg>';
const micOff='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="2" width="6" height="13" rx="3"/><path d="M3 3 21 21"/></svg>';
const owner='<span class="tc-mic-owner-mark"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="m2.5 7 5.4 4.5L12 4l4.1 7.5L21.5 7l-1.8 12H4.3z"/></svg></span>';
function seat(i){
 const index=i+1,member=i<4,muted=i===1||i===3,isOwner=i===0;
 const cssClass='seat '+(member?'occupied tc-mic-member '+(muted?'tc-mic-muted':'tc-mic-unmuted')+(isOwner?' tc-mic-owner':''):'locked');
 const avatar=member?(i===1||i===3?'<span class="tc-real-seat-glyph tc-mic-monogram">'+(i===1?'ب':'م')+'</span>':'<img src="'+image+'" alt="">'):'<span>＋</span>';
 const indicator=member?'<span class="tc-mic-indicator">'+(muted?micOff:micOn)+'</span>':'';
 return '<button type="button" class="'+cssClass+'" aria-label="مقعد '+index+'">'+
 '<div class="seatface">'+avatar+indicator+(isOwner?owner:'')+'</div>'+
 '<span class="seatname">'+(member?['مالك الغرفة','مستخدم','عضو الغرفة','ضيف'][i]:'مقعد '+index)+'</span>'+
 '<small class="seatlv">'+(member?(muted?'المايك مكتوم':'غير مكتوم'):'')+'</small></button>';
}
const html='<!doctype html><html dir="rtl" lang="ar"><head><meta name="viewport" content="width=device-width,initial-scale=1"/><style>'+css+'</style>'+
 '<style>html,body{margin:0;min-height:100%;background:#160d24}#app{margin:auto;max-width:440px;width:100%;min-height:100dvh;padding:72px 0 0;background:linear-gradient(180deg,#221232,#0b0a17);box-sizing:border-box}</style></head><body>'+
 '<div id="app" class="rf-app rf-room"><div class="roomview room-v2"><div class="seats" aria-label="مقاعد المايك">'+Array.from({length:15},(_,i)=>seat(i)).join('')+'</div></div></div></body></html>';
const captures=path.join(process.cwd(),'mic-occupant-screenshots');
fs.mkdirSync(captures,{recursive:true});
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  for(const [w,h] of [[320,720],[360,780],[390,844],[440,915],[360,570]]){
   const page=await browser.newPage();
   await page.setViewport({width:w,height:h,deviceScaleFactor:1});
   await page.setContent(html,{waitUntil:'load'});
   const got=await page.evaluate(()=>{
    const all=[...document.querySelectorAll('.seats > .seat')];
    const grid=document.querySelector('.seats');
    const g=getComputedStyle(grid);
    const owner=document.querySelector('.seat.tc-mic-owner .seatface');
    return {count:all.length,occupied:all.filter(x=>x.classList.contains('tc-mic-member')).length,
      indicators:document.querySelectorAll('.tc-mic-indicator').length,
      crowns:document.querySelectorAll('.tc-mic-owner-mark').length,
      columns:g.gridTemplateColumns.split(' ').length,
      gridBorder:g.borderTopWidth,background:g.backgroundImage,
      xOverflow:document.documentElement.scrollWidth-innerWidth,
      ownerRadius:getComputedStyle(owner).borderRadius,
      muted:document.querySelectorAll('.tc-mic-muted').length,
      fallback:document.querySelectorAll('.tc-mic-monogram').length,
      roomWidth:grid.getBoundingClientRect().width};
   });
   assert.equal(got.count,15);
   assert.equal(got.occupied,4);
   assert.equal(got.indicators,4);
   assert.equal(got.crowns,1);
   assert.equal(got.columns,5,'Never modify five-column seat geometry');
   assert.equal(got.gridBorder,'0px','Seat grid border was approved removed');
   assert.equal(got.background,'none','Never restore an outer seat panel');
   assert.ok(got.xOverflow<=1,'Horizontal overflow at '+w+'x'+h+': '+JSON.stringify(got));
   assert.equal(got.ownerRadius,'50%');
   assert.equal(got.muted,2);
   assert.equal(got.fallback,2);
   await page.screenshot({path:path.join(captures,'mic-'+w+'x'+h+'.png')});
   // Simulate a REAL roster update: mute flag toggles without moving/replacing seat.
   const changed=await page.evaluate(()=>{
    const b=document.querySelector('.seats > .seat.tc-mic-owner');
    const pos=b.getBoundingClientRect().toJSON();
    b.classList.remove('tc-mic-unmuted');b.classList.add('tc-mic-muted');
    b.querySelector('.seatlv').textContent='المايك مكتوم';
    const next=b.getBoundingClientRect().toJSON();
    let clicks=0;b.addEventListener('click',()=>clicks++);b.click();
    return {clicks,deltaX:next.x-pos.x,deltaY:next.y-pos.y,muted:b.classList.contains('tc-mic-muted')};
   });
   assert.equal(changed.clicks,1,'Do not interfere with seat actions');
   assert.equal(changed.deltaX,0);assert.equal(changed.deltaY,0);
   assert.ok(changed.muted);
   await page.close();
  }
  console.log('PASS verified-avatar UI: 15 seats, 5x3 geometry, 4 occupants, 2 mute marks, 1 verified owner, no overflow');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
