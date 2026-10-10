/* Verify voice-beta fails closed: no SFU credentials -> NO synthetic audio. */
'use strict';
const puppeteer=require('puppeteer-core');
const fs=require('node:fs'),assert=require('node:assert/strict');
const executablePath=process.env.CHROME_BIN||[
 '/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/usr/bin/chromium-browser'
].find(p=>fs.existsSync(p));
if(!executablePath)throw Error('Chrome not found');
const user='94c0e8fb-126e-4149-ad30-6f25e3c99c33';
const roomid='2ae6072b-d00c-46a9-8585-10ca1d6a10f2';
const token={access_token:'test-access',refresh_token:'test-refresh',expires_in:3600,
 user:{id:user,email:'audio@test.invalid'}};
const profile={id:user,display_name:'Audio Room Tester',bio:'',
 avatar_url:null,created_at:'2026-10-10T00:00:00Z',updated_at:'2026-10-10T00:00:00Z'};
let room=null,joined=false,seat=null,voiceCalls=0;
const result=(data,status=200)=>({status,contentType:'application/json',
 headers:{'access-control-allow-origin':'*','access-control-allow-headers':'authorization,apikey,content-type,prefer',
 'access-control-allow-methods':'GET,POST,OPTIONS'},body:JSON.stringify(data)});
(async()=>{
 const browser=await puppeteer.launch({executablePath,headless:true,
  args:['--no-sandbox','--disable-setuid-sandbox']});
 try{
  const page=await browser.newPage();
  await page.setViewport({width:390,height:844});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.setRequestInterception(true);
  page.on('request',request=>{
    const u=request.url();if(!u.startsWith('https://sqedsnyvjblvbjbizcay.supabase.co/'))
      return request.continue();
    const url=new URL(u),route=url.pathname;
    if(request.method()==='OPTIONS')return request.respond({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-methods':'POST,GET,OPTIONS','access-control-allow-headers':'authorization,apikey,content-type,prefer'}});
    const body=(()=>{try{return JSON.parse(request.postData()||'null')}catch{return null}})();
    let out;
    if(route==='/auth/v1/settings')out=result({external:{google:false,apple:false,facebook:false}});
    else if(route==='/auth/v1/token')out=result(token);
    else if(route==='/rest/v1/profiles')out=result([profile]);
    else if(route==='/rest/v1/home_banners')out=result([]);
    else if(route==='/rest/v1/rooms')out=result(room?[room]:[]);
    else if(route==='/rest/v1/room_members')out=result(joined?[{room_id:roomid}]:[]);
    else if(route==='/rest/v1/room_messages')out=result([]);
    else if(route==='/rest/v1/rpc/phase2_room_create'){
      room={id:roomid,title:'غرفة صوت حقيقية',owner_id:user,is_private:false,created_at:'2026-10-10T00:00:00Z'};
      joined=true;out=result(roomid);
    }else if(route==='/rest/v1/rpc/phase2_room_join'){joined=true;out=result(true);}
    else if(route==='/rest/v1/rpc/phase2_room_members'){
      out=result(joined?[{user_id:user,display_name:profile.display_name,seat_no:seat,is_muted:true}]:[]);
    }else if(route==='/rest/v1/rpc/phase2_room_take_seat'){
      seat=body.p_seat;out=result(seat);
    }else if(route==='/functions/v1/phase2-voice-token'){
      voiceCalls++;assert.equal(body.roomId,roomid);
      assert.match(request.headers().authorization,/^Bearer test-access$/);
      out=result({error:'LIVEKIT_NOT_CONFIGURED'},503);
    }else{out=result({message:'No mock endpoint '+route},404);}
    return request.respond(out).catch(()=>{});
  });
  await page.goto('http://127.0.0.1:8765/dist/?mode=live',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#fc-email');
  await page.type('#fc-email','audio@test.invalid');
  await page.type('#fc-pass','strong-password');
  await page.$eval('[data-fc="validate-auth"]',e=>e.click());
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='home',{timeout:20000});
  await page.waitForSelector('[data-phase2="create-room"]');
  await page.$eval('[data-phase2="create-room"]',e=>e.click());
  await page.type('#tc-phase2-room-title','غرفة صوت حقيقية');
  await page.$eval('[data-phase2="create-room-submit"]',e=>e.click());
  await page.waitForFunction(()=>document.querySelector('#app')?.dataset.route==='room',{timeout:20000});
  await page.waitForSelector('#tc-real-voice-controls [data-real-voice="connect"]');
  assert.equal(await page.$eval('[data-real-voice="mic"]',e=>e.hidden),true);
  await page.$eval('[data-real-voice="connect"]',e=>e.click());
  await page.waitForFunction(()=>window.TotiRealVoice?.status()?.error?.includes('خدمة البث الصوتي'),{timeout:15000});
  assert.equal(voiceCalls,1);
  assert.equal(await page.evaluate(()=>window.TotiRealVoice?.status().connected),false,
   'No real audio connection if LiveKit secrets are missing');
  assert.equal(await page.evaluate(()=>document.querySelectorAll('[data-toti-live-audio]').length),0,
   'No dummy audio track is presented');
  assert.equal(errors.length,0,'JavaScript errors: '+errors.join('; '));
  console.log('PASS: real LiveKit token call with signed-in session; missing SFU rejected; no fake audio');
 }finally{await browser.close();}
})().catch(error=>{console.error(error.stack||error);process.exitCode=1;});
