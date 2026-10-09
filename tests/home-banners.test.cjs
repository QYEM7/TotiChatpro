// No dependencies. Run with: node --test tests/home-banners.test.cjs
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.join(__dirname,'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const core=require('../app/banner-core.js');
const now=Date.parse('2026-10-09T10:00:00Z');
function row(patch={}){return {id:'banner-1',title:'إعلان حقيقي',image_url:'https://example.org/banner.png',link_kind:'none',link_target:null,status:'published',starts_at:null,ends_at:null,sort_order:0,...patch};}

test('published and current ads are eligible, drafts and expired ads are not',()=>{
  assert.equal(core.normalize([row()],now).length,1);
  for(const patch of [{status:'draft'},{status:'archived'},{starts_at:'2026-10-10T00:00:00Z'},{ends_at:'2026-10-09T09:59:59Z'},{title:''}]){
    assert.equal(core.normalize([row(patch)],now).length,0,JSON.stringify(patch));
  }
});
test('external and image links accept HTTPS only, no credentials or script URLs',()=>{
  for(const url of ['javascript:alert(1)','data:image/png;base64,AA','http://example.org/img.jpg','https://user:pass@example.org','/relative.png']){
    assert.equal(core.normalize([row({image_url:url})],now).length,0,url);
    assert.equal(core.normalize([row({link_kind:'external',link_target:url})],now).length,0,url);
  }
  assert.equal(core.normalize([row({link_kind:'external',link_target:'https://totichat.example/event'})],now).length,1);
});
test('in-app navigation accepts only the known screen routes',()=>{
  assert.equal(core.normalize([row({link_kind:'screen',link_target:'agencyPreview'})],now).length,1);
  assert.equal(core.normalize([row({link_kind:'screen',link_target:'javascript:alert(1)'})],now).length,0);
  assert.equal(core.normalize([row({link_kind:'none',link_target:'https://example.org'})],now).length,0);
});
test('ads sort, dedupe and cap, never invent fallback banners',()=>{
  const input=Array.from({length:15},(_,i)=>row({id:'id-'+i,title:'Banner '+i,sort_order:14-i}));
  const result=core.normalize(input.concat(input[0]),now);
  assert.equal(result.length,12);
  assert.equal(result[0].id,'id-14');
  assert.equal(new Set(result.map(x=>x.id)).size,12);
  assert.deepEqual(core.normalize([],now),[]);
});
test('escape untrusted titles before inserting into UI',()=>{
  assert.equal(core.escape('<img src=x onerror="go()">'), '&lt;img src=x onerror=&quot;go()&quot;&gt;');
});
test('approved root preview stays byte-identical to signed visual master except local image URLs',()=>{
  const original=read('reference/approved-original.html');
  const rootPreview=read('index.html');
  const old='https://raw.githubusercontent.com/jsjsnsnsnsn0-pixel/TotiChat/main/public/assets/images/';
  assert.equal(rootPreview,original.replaceAll(old,'assets/images/'));
});
test('app preserves approved HTML and changes only the five reviewed banner-integration snippets and asset base',()=>{
  const rootPreview=read('index.html');
  let app=read('app/index.html');
  const substitutions=[
    [`<script>\nconst A=`,`<script src="./banner-core.js"></script>\n<script src="./config.js"></script>\n<script src="./home-banners.js"></script>\n<script>\nconst A=`],
    [`content='<div class="hero" '+act('sheet','promo')+'>'+im(['hero','hero2','hero3'][banner])+'<b>فعاليات ومكافآت TotiChat</b><div class="dots"><i class="'+(banner===0?'on':'')+'"></i><i class="'+(banner===1?'on':'')+'"></i><i class="'+(banner===2?'on':'')+'"></i></div></div><div class="featurecards">`,`content=window.TotiBannerData.renderBanner()+'<div class="featurecards">`],
    [`if(type==='announcement'){showSheet(head('الإعلانات الرسمية')+im('hero','class="eventbanner"')+'<p>تنشر إدارة TotiChat الإعلانات والفعاليات من لوحة التحكم. هذه بنرات عرض تجريبية.</p>');return}`,`if(type==='announcement'){showSheet(head('الإعلانات الرسمية')+window.TotiBannerData.renderAnnouncements());return}`],
    [`setInterval(()=>{if(screen==='home'&&homeTab==='حفلة'&&!document.getElementById('overlay').classList.contains('show')){banner=(banner+1)%3;const h=document.querySelector('.hero img');if(h)h.src=A+assets[['hero','hero2','hero3'][banner]];document.querySelectorAll('.dots i').forEach((e,i)=>e.className=i===banner?'on':'')}},6500);`,`setInterval(()=>{if(screen==='home'&&homeTab==='حفلة'&&!document.getElementById('overlay').classList.contains('show')){window.TotiBannerData.advance()}},6500);`],
    ['TotiChat • معاينة UI/UX فقط','TotiChat • نسخة ربط تجريبية (الإعلانات حقيقية عند الاتصال)']
  ];
  // Approved root is immutable. Additional reviewed feature layers on /app/ may
  // be loaded externally without altering the original inline HTML master.
  assert.match(app,/identity-return\.css\?v=/);
  assert.match(app,/agency-hub\.js\?v=/);
  app=app.replace(/<link rel="stylesheet" href="\.\/identity-return\.css\?v=[^"]+">\n/,'');
  assert.match(app,/bloom-signature\.css\?v=/);
  app=app.replace(/<link rel="stylesheet" href="\.\/bloom-signature\.css\?v=[^"]+">\n/,'');
  assert.match(app,/frontend-finish\.css\?v=/);
  assert.match(app,/frontend-finish\.js\?v=/);
  app=app.replace(/<link rel="stylesheet" href="\.\/frontend-finish\.css\?v=[^"]+">\n/,'');
  app=app.replace(/<script src="\.\/frontend-finish\.js\?v=[^"]+"><\/script>/,'');
  assert.match(app,/toti-nav-banner-refine\.css\?v=/);
  assert.match(app,/toti-nav-banner-refine\.js\?v=/);
  app=app.replace(/<link rel="stylesheet" href="\.\/toti-nav-banner-refine\.css\?v=[^"]+">/,'');
  assert.match(app,/profile-stats-luxe\.css\?v=/);
  app=app.replace(/<link rel="stylesheet" href="\.\/profile-stats-luxe\.css\?v=[^"]+">/,'');
  assert.match(app,/room-seats-finish\.css\?v=/);
  app=app.replace(/\n<link rel="stylesheet" href="\.\/room-seats-finish\.css\?v=[^"]+">/,'');
  assert.match(app,/phase2-ui\.css\?v=/);
  app=app.replace(/\n<link rel="stylesheet" href="\.\/phase2-ui\.css\?v=[^"]+">/,'');
  assert.match(app,/phase2-rooms\.css\?v=/);
  app=app.replace(/\n<link rel="stylesheet" href="\.\/phase2-rooms\.css\?v=[^"]+">/,'');

  app=app.replace(/<script src="\.\/toti-nav-banner-refine\.js\?v=[^"]+"><\/script>/,'');
  assert.match(app,/phase2-auth\.js\?v=/);
  assert.match(app,/phase2-ui\.js\?v=/);
  app=app.replace(/<script src="\.\/phase2-auth\.js\?v=[^"]+"><\/script>/,'');
  app=app.replace(/<script src="\.\/phase2-ui\.js\?v=[^"]+"><\/script>/,'');
  assert.match(app,/phase2-rooms\.js\?v=/);
  app=app.replace(/<script src="\.\/phase2-rooms\.js\?v=[^"]+"><\/script>/,'');
  app=app.replace(/<script src="\.\/agency-hub\.js\?v=[^"]+"><\/script>/,'');
  assert.match(app, /<link rel="stylesheet" href="\.\/royal-vip15\.css(?:\?v=[^"]+)?">/);
  assert.match(app, /<script src="\.\/royal-vip15\.js(?:\?v=[^"]+)?"><\/script>/);
  app=app.replace(/<link rel="stylesheet" href="\.\/royal-vip15\.css(?:\?v=[^"]+)?">/,'');
  app=app.replace(/<script src="\.\/royal-vip15\.js(?:\?v=[^"]+)?"><\/script>/,'');
  assert.match(app, /<link rel="stylesheet" href="\.\/royal-badges-close\.css">/);
  assert.match(app, /<script src="\.\/royal-badges-close\.js"><\/script>/);
  app=app.replace('<link rel="stylesheet" href="./royal-badges-close.css">','');
  app=app.replace('<script src="./royal-badges-close.js"></script>','');
  assert.match(app, /<link rel="stylesheet" href="\.\/royal-final\.css">/);
  assert.match(app, /<script src="\.\/royal-final\.js"><\/script>/);
  app=app.replace('<link rel="stylesheet" href="./royal-final.css">','');
  app=app.replace('<script src="./royal-final.js"></script>','');
  assert.match(app, /<link rel="stylesheet" href="\.\/royal-visuals\.css">/);
  assert.match(app, /<script src="\.\/royal-visuals\.js"><\/script>/);
  app=app.replace('<link rel="stylesheet" href="./royal-visuals.css">','');
  app=app.replace('<script src="./royal-visuals.js"></script>','');
  assert.match(app, /<link rel="stylesheet" href="\.\/room-ui-enhancements\.css">/);
  assert.match(app, /<script src="\.\/room-ui-enhancements\.js"><\/script>/);
  app=app.replace('<link rel="stylesheet" href="./room-ui-enhancements.css">','');
  app=app.replace('<script src="./room-ui-enhancements.js"></script>','');
  app=app.replaceAll('../assets/images/','assets/images/');
  for(const [oldCode,newCode] of substitutions){
    assert.equal(app.split(newCode).length,2,'replacement missing or duplicated');
    app=app.replace(newCode,oldCode);
  }
  assert.equal(app,rootPreview,'Unexpected visual changes outside authorized banner integration');
});
test('all frontend scripts compile and original 27 images match source hashes',()=>{
  for(const p of ['app/banner-core.js','app/config.js','app/home-banners.js','app/room-ui-enhancements.js','app/royal-visuals.js','app/royal-final.js','app/royal-badges-close.js','app/royal-vip15.js','app/agency-hub.js','app/frontend-finish.js','app/toti-nav-banner-refine.js']){
    new vm.Script(read(p),{filename:p});
  }
  const app=read('app/index.html');
  const match=app.match(/<script>\s*([\s\S]*?)<\/script>/);
  assert.ok(match,'Missing app inline script');
  new vm.Script(match[1],{filename:'app/index.html:inline'});
  const manifest=read('reference/approved-assets.gitsha').split('\n').filter(x=>/^[a-f0-9]{40} /.test(x));
  assert.equal(manifest.length,27);
  for(const line of manifest){
    const [expected,name]=line.split(' ');
    const bytes=fs.readFileSync(path.join(root,'assets/images',name));
    const hash=crypto.createHash('sha1').update(Buffer.from('blob '+bytes.length+'\0')).update(bytes).digest('hex');
    assert.equal(hash,expected,'Changed approved image '+name);
  }
});
test('database schema exposes only active published ads, never enables public writes or fake seeds',()=>{
  const sql=read('supabase/migrations/20261009150000_home_banners.sql');
  assert.match(sql,/enable row level security/i);
  assert.match(sql,/status = 'published'/);
  assert.match(sql,/starts_at is null or starts_at <= now\(\)/);
  assert.match(sql,/ends_at is null or ends_at > now\(\)/);
  assert.match(sql,/grant select on table public.home_banners to anon, authenticated/i);
  assert.doesNotMatch(sql,/grant\s+(insert|update|delete|all)\s+on\s+table\s+public.home_banners\s+to\s+anon/i);
  assert.doesNotMatch(sql,/insert\s+into\s+public.home_banners\s*\(/i);
});

test('room preview completion leaves server and approved root untouched',()=>{
 const source=read('app/room-ui-enhancements.js');
 for(const item of ['minimizeRoom','shareRoom','settingsRoom','games','startDrag','friendRows','xoMove','ownerPreview'])assert.ok(source.includes(item),item);
 assert.doesNotMatch(source,/\b(fetch|XMLHttpRequest|supabase\.from|navigator\.share)\s*\(/);
 assert.match(read('app/index.html'),/room-ui-enhancements\.js/);
 assert.doesNotMatch(read('index.html'),/room-ui-enhancements\.js/);
});

test('royal reference changes are frontend-only and preserve approved original artwork',()=>{
 const html=read('app/index.html');
 const royal=read('app/royal-visuals.js');
 const css=read('app/royal-visuals.css');
 assert.match(html,/royal-visuals\.css/);
 for(const key of ['royalHome','royal-feature-','royal-feature-games','royal-mini-room','royal-seat-chips'])assert.ok(royal.includes(key)||css.includes(key),key);
 for(const key of ['Room Settings','Share Room','Games Center','TotiChat Lounge'])assert.match(royal,new RegExp(key));
 assert.doesNotMatch(royal,/\b(fetch|XMLHttpRequest|supabase\.from)\s*\(/);
 assert.doesNotMatch(read('index.html'),/royal-visuals\.(css|js)/);
});

test('royal-wide UI makeover covers existing screens, preserves voice seats and backend',()=>{
 const app=read('app/index.html');
 const royalty=read('app/royal-final.js');
 const css=read('app/royal-final.css');
 const original=read('reference/approved-original.html');
 assert.match(royalty,/const priorRender=render/);
 assert.match(royalty,/vMore=function/);
 for(const token of ['decorateRoom','openMusicDb','musicPreview','roomAdminPreview','gamesPreview','notificationsPreview','missionsPreview','treasurePreview'])assert.match(royalty,new RegExp(token));
 for(const token of ['.rf-room .seat','.rf-room .roomBottom','.me-royal','.vip-royal','.ag-screen','.visual-inventory','.royal-profile-card'])assert.ok((css+read('app/royal-visuals.css')).includes(token),token);
 assert.match(app,/const seats=Array\.from\(\{length:15\}/);
 assert.match(app,/act\('seat',i\)/);
 assert.match(app,/act\('sheet','gift'\)/);
 assert.doesNotMatch(royalty,/\b(fetch|XMLHttpRequest|supabase\.from|socket\.emit)\s*\(/);
 assert.doesNotMatch(original,/royal-final/);
 assert.doesNotMatch(read('index.html'),/royal-final/);
});

test('unique royal badges and close controls are isolated to frontend preview',()=>{
 const js=read('app/royal-badges-close.js'),css=read('app/royal-badges-close.css'),app=read('app/index.html');
 for(const part of ['level=function()','honor=function()','badgeSvg(','rp-level-groups','rp-honor-grid','room-glass-close','rp-unified-close'])assert.ok((js+css).includes(part),part);
 assert.match(js,/length:10/); // 10 groups × 10 levels
 assert.match(js,/currentGroup\*10\+1/);
 assert.match(js,/achievements\.map/);
 assert.match(app,/royal-badges-close\.css/);
 assert.doesNotMatch(js,/\b(fetch|XMLHttpRequest|supabase\.from|socket\.emit)\s*\(/);
 assert.doesNotMatch(read('index.html'),/royal-badges-close/);
});

test('VIP 1 to 15 gallery is frontend-only and preserves other app sections',()=>{
 const app=read('app/index.html'),js=read('app/royal-vip15.js'),css=read('app/royal-vip15.css');
 assert.match(app,/royal-vip15\.css/);
 assert.match(app,/royal-vip15\.js/);
 for(const key of ['const tiers=[','length:15','Array.from({length:15}','vVIP=function','rvip-tier','rvip-hero','rvip-benefit','rvip-scenario','view','royal-vip','TotiChatVIPPreview']){
  assert.ok(js.includes(key)||css.includes(key),key);
 }
 assert.doesNotMatch(js,/\b(fetch|XMLHttpRequest|supabase\.from|socket\.emit)\s*\(/);
 assert.doesNotMatch(read('index.html'),/royal-vip15/);
 assert.match(read('app/index.html'),/const seats=Array.from\(\{length:15\}/);
});

test('profile and home share the five sections and original falcon asset, without replacing any screen',()=>{
  const markup=read('app/index.html');
  const refinement=read('app/toti-nav-banner-refine.js');
  const css=read('app/toti-nav-banner-refine.css');
  assert.match(markup,/toti-nav-banner-refine\.css/);
  assert.match(markup,/toti-nav-banner-refine\.js/);
  for(const label of ['الرئيسية','اكتشف','إنشاء غرفة','الرسائل','حسابي']){
    assert.ok(refinement.includes(label),label);
  }
  assert.match(refinement,/toti_falcon_logo_1790422919580\.jpg/);
  assert.match(refinement,/royal-create/);
  assert.match(refinement,/const previousRender=render/);
  assert.match(css,/\.me-links \.me-link/);
  assert.match(css,/\.me-more button/);
  assert.doesNotMatch(refinement,/\b(XMLHttpRequest|supabase\.from|socket\.emit)\s*\(/);
});

test('home banner slot rotates independently and only labels validated live banners as official',()=>{
  const script=read('app/toti-nav-banner-refine.js');
  const feed=read('app/home-banners.js');
  assert.match(feed,/getItems:\(\)=>state\.items\.map/);
  assert.match(script,/function localSlides/);
  assert.match(script,/function slides/);
  assert.match(script,/raw\.length/);
  assert.match(script,/liveIndex/);
  assert.match(script,/setInterval/);
  assert.match(script,/document\.hidden/);
  assert.match(script,/aria-label/);
  assert.match(script,/data-royal/);
  assert.match(read('index.html'),/const A=/);
  assert.doesNotMatch(read('index.html'),/toti-nav-banner-refine/);
});

test('profile stats makeover is isolated, truly distinctive and retains the four counters',()=>{
 const css=read('app/profile-stats-luxe.css');
 const js=read('app/toti-nav-banner-refine.js');
 const html=read('app/index.html');
 assert.match(html,/profile-stats-luxe\.css\?v=/);
 assert.match(css,/\.tc-stats-luxe/);
 assert.match(css,/linear-gradient\(121deg,#251137/);
 assert.match(css,/color:#ffe3aa!important/);
 assert.match(js,/function enhanceProfileStats/);
 assert.match(js,/button\.insertBefore\(glyph,button\.firstChild\)/);
 assert.match(html,/const stats='<div class="me-statcard">/);
 assert.match(html,/act\('go','friendsPreview'\)/);
 assert.doesNotMatch(read('index.html'),/profile-stats-luxe/);
});

test('the home room listings end without a duplicate official-ads footer, but retain top banner',()=>{
  const js=read('app/royal-visuals.js');
  assert.match(js,/class="royal-hero"/,'top hero banner remains');
  assert.match(js,/class="royal-near"/,'nearby voice rooms remain');
  assert.match(js,/class="royal-room-gallery"/,'featured rooms remain');
  assert.doesNotMatch(js,/class="royal-official"/,'the bottom duplicate ad must be removed');
  assert.match(read('app/home-banners.js'),/function renderBanner/,'live banners remain implemented');
  assert.match(read('app/toti-nav-banner-refine.js'),/function enhanceBanner/,'animated primary banner remains enabled');
});

test('voice room removes the slogan ribbon and the seats panel, keeping all mic data and clicks',()=>{
  const royal=read('app/royal-final.js');
  const finish=read('app/room-seats-finish.css');
  const markup=read('app/index.html');
  assert.doesNotMatch(royal,/rf-room-royal-ribbon/);
  assert.doesNotMatch(royal,/هنا يجتمع الصوت الجميل/);
  assert.match(markup,/room-seats-finish\.css\?v=/);
  for(const key of ['background:transparent!important','border:0!important','row-gap:3px!important','seat\.vip8','seat\.locked','seatname','seatlv']){
    assert.ok(finish.includes(key),key);
  }
  assert.match(markup,/const seats=Array\.from\(\{length:15\}/);
  assert.match(markup,/act\('seat',i\)/);
  assert.doesNotMatch(read('index.html'),/room-seats-finish/,'the immutable root remains unchanged');
});
