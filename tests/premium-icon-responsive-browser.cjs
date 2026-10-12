/* Responsive layout fixture. No backend requests, invented people or finance records. */
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const puppeteer=require('puppeteer-core');
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>fs.existsSync(x));
if(!exe)throw Error('Chromium not installed');
const read=x=>fs.readFileSync(path.join(process.cwd(),x),'utf8');
const styles=['app/toti-nav-banner-refine.css','app/phase6-inapp-admin.css','app/phase6-premium-icons.css'].map(read).join('\n');
const source=read('app/phase6-premium-icons.js');
const destination=path.join(process.cwd(),'premium-icon-screenshots');
fs.mkdirSync(destination,{recursive:true});
const profile=[['rechargePreview','الشحن','💳'],['storage','الحقيبة','🎒'],['level','المستويات','💠'],['honor','الشارات','🏅']].map(x=>'<button class="me-link" data-v="'+x[0]+'"><span class="rich-icon">'+x[2]+'</span><span>'+x[1]+'</span></button>').join('');
const more=[['agencyPreview','الوكالات','👥'],['block','الحظر','🚫'],['report','البلاغات','📝'],['languages','اللغة','🌐'],['settings','الإعدادات','⚙️']].map(x=>'<button data-v="'+x[0]+'"><span class="more-icon">'+x[2]+'</span><span>'+x[1]+'</span><span class="chev">‹</span></button>').join('');
const room=[['chatInput','الكتابة'],['gift','الهدايا'],['messagesRoom','الرسائل'],['games','الألعاب'],['tools','الأدوات']].map(x=>'<button data-v="'+x[0]+'" aria-label="'+x[1]+'">🎁</button>').join('');
const nav=[['home','⌂','الرئيسية'],['discoverPreview','◎','اكتشف'],['CREATE','＋','إنشاء غرفة'],['messages','☏','الرسائل'],['me','حسابي','حسابي']].map(x=>'<button '+(x[0]==='CREATE'?'class="royal-create" data-royal="create-room"':'data-v="'+x[0]+'"')+'><span>'+(x[0]==='me'?'<img class="tc-falcon-nav" alt="الصقر" src="data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=">':x[1])+'</span><small>'+x[2]+'</small></button>').join('');
const admin=[['overview','الرئيسية'],['users','المستخدمون'],['rooms','الغرف'],['staff','الموظفون'],['support','الدعم'],['banners','البنرات'],['vip','VIP'],['medals','الشارات']].map(x=>'<button class="tcac-card" data-tcac-view="'+x[0]+'"><span class="tcac-icon">◈</span><b>'+x[1]+'</b></button>').join('');
const html='<!doctype html><html dir="rtl" lang="ar"><head><meta name="viewport" content="width=device-width,initial-scale=1">'+
 '<style>*{box-sizing:border-box}html,body{margin:0;width:100%;min-height:100%;background:#f8f5fb;font-family:system-ui,sans-serif}#app{max-width:440px;margin:auto;padding-bottom:90px}.qa-profile{padding:10px}.qa-profile h1{margin:10px}.roomBottom{display:flex;justify-content:space-evenly;padding:8px;gap:5px;background:#352345}.roomBottom>button{width:44px;height:44px;border-radius:14px;color:#fff3f7;background:#563d6b;border:0}'+styles+'</style></head>'+
 '<body><div id="app" class="rf-app" data-route="me"><div class="qa-profile"><h1>TotiChat</h1><div class="me-royal"><div class="me-links">'+profile+'</div><div class="me-more">'+more+'<button data-tcac-entry><span class="tcac-entry-icon">◆</span><span class="tcac-entry-text">مركز الإدارة</span></button></div></div><div class="roomBottom">'+room+'</div></div>'+
 '<nav class="royal-nav tc-unified-nav" aria-label="التنقل الرئيسي">'+nav+'</nav>'+
 '<section id="tcac-root" class="tcac-root" style="display:none"><div class="tcac-shell"><header class="tcac-header"><button class="tcac-back" data-tcac="exit">➜</button><div class="tcac-brand"><b>TotiChat</b><small>مركز الإدارة</small></div><button class="tcac-refresh" data-tcac="refresh">⟳</button></header><section class="tcac-hero"><h2>مركز الإدارة</h2></section><main class="tcac-content"><div class="tcac-grid">'+admin+'</div></main><footer class="tcac-bottom"><button data-tcac="home">الرئيسية</button><button data-tcac="modules">الأقسام</button><button data-tcac="exit">عودة للتطبيق</button></footer></div></section></body></html>';
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  for(const width of [320,360,390,440]){
   const page=await browser.newPage();
   await page.setViewport({width,height:820,deviceScaleFactor:1});
   await page.setContent(html,{waitUntil:'load'});
   await page.evaluate(()=>{window.TotiLiveMode={enabled:true};window.TotiPhase2Auth={state:()=>({signedIn:true})};});
   await page.addScriptTag({content:source});
   await new Promise(resolve=>setTimeout(resolve,100));
   const before=await page.evaluate(()=>({
    overflow:document.documentElement.scrollWidth-innerWidth,
    navWidth:document.querySelector('.tc-unified-nav').getBoundingClientRect().width,
    navCount:document.querySelectorAll('.tc-unified-nav button').length,
    roomCount:document.querySelectorAll('.roomBottom>button').length,
    iconCount:document.querySelectorAll('#app svg.tc-premium-svg').length,
    falcon:!!document.querySelector('.tc-falcon-nav')
   }));
   assert.ok(before.overflow<=1,'Overflow at '+width+': '+JSON.stringify(before));
   assert.ok(before.navWidth<=width+1,'Navigation too wide at '+width);
   assert.equal(before.navCount,5);assert.equal(before.roomCount,5);
   assert.ok(before.iconCount>=14,'Icons did not paint');
   assert.ok(before.falcon,'Falcon logo disappeared');
   await page.screenshot({path:path.join(destination,'main-'+width+'.png')});
   const count=await page.evaluate(()=>{
    let clicked=0;const button=document.querySelector('.roomBottom [data-v="gift"]');
    button.addEventListener('click',()=>clicked++);button.click();
    return clicked;
   });
   assert.equal(count,1,'Gift button click broke');
   await page.evaluate(()=>{document.querySelector('#tcac-root').style.display='block';});
   await new Promise(resolve=>setTimeout(resolve,100));
   const after=await page.evaluate(()=>({
    overflow:document.documentElement.scrollWidth-innerWidth,
    count:document.querySelectorAll('#tcac-root .tcac-card svg.tc-premium-svg').length
   }));
   assert.ok(after.overflow<=1,'Admin overflow at '+width+': '+JSON.stringify(after));
   assert.equal(after.count,8,'Admin icons are inconsistent');
   await page.screenshot({path:path.join(destination,'admin-'+width+'.png')});
   await page.close();
  }
  console.log('PASS premium icon responsive layout at 320, 360, 390, 440 px');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
