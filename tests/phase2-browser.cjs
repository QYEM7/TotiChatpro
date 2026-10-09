/* Browser E2E: production UI talks to mocked Auth/PostgREST; no real accounts,
 * email delivery, money, or network mutations. Backend SQL remains independently
 * validated by Supabase RLS and grants queries.
 */
'use strict';
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const exe=process.env.CHROME_BIN||
 ['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser']
 .find(p=>fs.existsSync(p));
if(!exe)throw new Error('System Chromium unavailable');
const web=process.env.UI_URL||'http://127.0.0.1:8765/app/';
const owner='94c0e8fb-126e-4149-ad30-6f25e3c99c33';
const roomId='2ae6072b-d00c-46a9-8585-10ca1d6a10f2';
const today=new Date().toISOString();
const token={access_token:'test-access-token',refresh_token:'test-refresh-token',
 expires_in:3600,user:{id:owner,email:'voice@test.invalid'}};
let profile={id:owner,display_name:'Room Test User',bio:'مرحبا',
 avatar_url:null,created_at:today,updated_at:today};
let room=null,joined=false,seat=null,messages=[];
const calls=[];
let browser;
async function waitUntil(page,fn){
  try{await page.waitForFunction(fn,{timeout:13000,polling:150});}
  catch(error){
    const text=await page.$eval('#fc-form-status',x=>x.textContent).catch(()=>null);
    const route=await page.$eval('#app',x=>x.dataset.route).catch(()=>null);
    console.error('UI timeout diagnostics:',JSON.stringify({route,formStatus:text}));
    console.error('Recent backend endpoints:',JSON.stringify(calls.slice(-15)));
    console.error('Last UI toast:',await page.$eval('#toast',x=>x.textContent).catch(()=>''));
    throw error;
  }
}
function json(data,status=200){
 return {status,contentType:'application/json',headers:{
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization,apikey,content-type,prefer',
  'access-control-allow-methods':'GET,POST,PATCH,OPTIONS',
  'access-control-expose-headers':'content-range'
 },body:JSON.stringify(data)};
}
(async()=>{
 browser=await puppeteer.launch({headless:true,executablePath:exe,
  args:['--no-sandbox','--disable-setuid-sandbox']});
 const page=await browser.newPage();
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});
 const errors=[];
 page.on('pageerror',e=>{errors.push(e.message);console.error('Browser JS error:',e.message)});
 page.on('requestfailed',r=>{if(r.url().includes('supabase.co'))console.error('API failed:',r.url(),r.failure()?.errorText)});
 page.on('console',m=>{if(m.type()==='error')console.error('Console error:',m.text())});
 page.on('dialog',d=>d.accept());
 await page.setRequestInterception(true);
 page.on('request',async req=>{
  const url=req.url(),method=req.method();
  if(!url.startsWith('https://sqedsnyvjblvbjbizcay.supabase.co/')){
   return req.continue();
  }
  if(method==='OPTIONS')return req.respond({
   status:204,headers:{'access-control-allow-origin':'*',
   'access-control-allow-headers':'authorization,apikey,content-type,prefer',
   'access-control-allow-methods':'GET,POST,PATCH,OPTIONS'},body:''
  });
  const u=new URL(url),route=u.pathname;
  calls.push(method+' '+route);
  const body=(()=>{try{return JSON.parse(req.postData()||'null')}catch{return null}})();
  let result;
  if(route==='/rest/v1/home_banners'){result=json([]);}
  else if(route==='/auth/v1/token'&&u.searchParams.get('grant_type')==='password'){
   assert.equal(body.email,'voice@test.invalid');result=json(token);
  }
  else if(route==='/auth/v1/user')result=json(token.user);
  else if(route==='/auth/v1/logout')result=json(null,204);
  else if(route==='/rest/v1/profiles'&&method==='GET')result=json([profile]);
  else if(route==='/rest/v1/profiles'&&method==='PATCH'){
   assert.deepEqual(Object.keys(body).sort(),['bio','display_name']);
   profile={...profile,...body};result=json([profile]);
  }
  else if(route==='/rest/v1/rooms'&&method==='GET')result=json(room?[room]:[]);
  else if(route==='/rest/v1/room_members'&&method==='GET')result=json(joined?[{room_id:roomId}]:[]);
  else if(route==='/rest/v1/room_messages'&&method==='GET')result=json([...messages].reverse());
  else if(route==='/rest/v1/rpc/phase2_room_create'){
   room={id:roomId,title:body.p_title,owner_id:owner,is_private:!!body.p_is_private,created_at:today};
   joined=true;result=json(roomId);
  }
  else if(route==='/rest/v1/rpc/phase2_room_join'){assert.equal(body.p_room_id,roomId);joined=true;result=json(true);}
  else if(route==='/rest/v1/rpc/phase2_room_members'){
   result=json(joined?[{user_id:owner,display_name:profile.display_name,seat_no:seat,is_muted:true}]:[]);
  }
  else if(route==='/rest/v1/rpc/phase2_room_take_seat'){
   seat=body.p_seat;result=json(seat);
  }
  else if(route==='/rest/v1/rpc/phase2_room_send_message'){
   assert.equal(body.p_room_id,roomId);
   messages.push({id:messages.length+1,sender_id:owner,body:body.p_body,created_at:today});
   result=json(messages.length);
  }
  else if(route==='/rest/v1/rpc/phase2_room_leave'){
   joined=false;room=null;seat=null;result=json(true);
  }
  else result=json({msg:'Unmocked API: '+route},404);
  return req.respond(result).catch(()=>{});
 });
 await page.goto(web+'?screen=me',{waitUntil:'domcontentloaded'});
 await page.waitForSelector('#app.rf-app');
 console.log('Stage 2 runtime modules',JSON.stringify(await page.evaluate(()=>({
    auth:!!window.TotiPhase2Auth,rooms:!!window.TotiPhase2Rooms,
    render:typeof window.render,base:!!window.TOTICHAT_PUBLIC_BACKEND
 }))));
 assert.ok(await page.$('[data-phase2="account"]'),'Account button must exist inside approved Me screen');
 await page.click('[data-phase2="account"]');
 assert.equal(await page.$eval('#app',x=>x.dataset.route),'loginPreview');
 await page.type('#fc-email','voice@test.invalid');
 await page.type('#fc-pass','strong-password');
 await page.click('[data-fc="validate-auth"]');
 await waitUntil(page,()=>window.TotiPhase2Auth?.state()?.profile?.display_name==='Room Test User');
 await waitUntil(page,()=>document.querySelector('#app')?.dataset.route==='me');
 assert.match(await page.$eval('.me-summary b',x=>x.textContent),/Room Test User/);
 assert.equal(await page.$eval('.me-statcard button b',x=>x.textContent.trim()),'—',
   'Demo social counters must not pretend to be real');
 await page.click('.tc-unified-nav [data-v="home"]');
 await waitUntil(page,()=>document.querySelector('.tc-phase2-empty')?.textContent.includes('ماكو غرف'));
 assert.equal(await page.$$eval('.royal-room-gallery .royal-room-tile',x=>x.length),0,
   'Signed-in user never sees demo rooms when actual directory empty');
 await page.click('[data-phase2="create-room"]');
 await page.type('#tc-phase2-room-title','غرفة الاختبار الحقيقية');
 await page.click('[data-phase2="create-room-submit"]');
 await waitUntil(page,()=>document.querySelector('#app')?.dataset.route==='room');
 await waitUntil(page,()=>document.querySelector('.roomidentity b')?.textContent==='غرفة الاختبار الحقيقية');
 assert.equal(await page.$$eval('.seats .seat',e=>e.length),15);
 await page.click('.seats .seat:first-child');
 await waitUntil(page,()=>document.querySelector('.seats .seat:first-child .seatname')?.textContent==='Room Test User');
 await page.click('.roomBottom [data-a="sheet"][data-v="chatInput"]');
 await page.waitForSelector('#composerInput');
 await page.type('#composerInput','مرحبا من الدردشة الحقيقية');
 await page.click('[data-a="sendPreview"]');
 await waitUntil(page,()=>[...document.querySelectorAll('.chatArea .chatMsg')].some(x=>x.textContent.includes('مرحبا من الدردشة الحقيقية')));
 assert.equal(messages.length,1,'One server-side send is recorded, no local fake send');
 assert.ok(!errors.length,'No browser errors: '+errors.join('; '));
 await page.evaluate(()=>go('me'));
 await page.click('.me-pencil');
 await page.waitForSelector('[data-edit-field="name"]');
 await page.$eval('[data-edit-field="name"]',input=>{input.value='New Test Name';input.dispatchEvent(new Event('input',{bubbles:true}));});
 await page.click('[data-a="saveProfilePreview"]');
 await waitUntil(page,()=>window.TotiPhase2Auth?.state()?.profile?.display_name==='New Test Name');
 assert.equal(await page.$eval('#app',x=>x.dataset.route),'profilePreview');
 await page.evaluate(()=>go('room'));
 await page.click('.roomtop [data-a="sheet"][data-v="roomExitMenu"]');
 await page.click('[data-a="leaveRoom"]');
 await waitUntil(page,()=>document.querySelector('#app')?.dataset.route==='home');
 await page.evaluate(()=>go('me'));
 await page.click('[data-phase2="account"]');
 await page.waitForSelector('.tc-phase2-account-sheet [data-phase2="logout"]');
 await page.click('.tc-phase2-account-sheet [data-phase2="logout"]');
 await waitUntil(page,()=>window.TotiPhase2Auth?.state()?.signedIn===false);
 assert.equal(await page.$eval('#app',e=>e.dataset.route),'loginPreview');
 console.log('PASS: real UI Auth -> profile -> rooms -> seat -> chat -> profile edit -> logout, all mocked/isolated');
 await browser.close();
})().catch(async e=>{console.error(e.stack||e);if(browser)await browser.close().catch(()=>{});process.exitCode=1;});
