/* Isolated UI contract with Chromium's test microphone. Not live device E2E. */
'use strict';
const puppeteer=require('puppeteer-core'),fs=require('fs'),assert=require('node:assert/strict');
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/chromium'].find(fs.existsSync),args:['--no-sandbox','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 try{const p=await browser.newPage();const errors=[];p.on('pageerror',e=>errors.push(e.message));await p.goto('http://127.0.0.1:8765/voice-contract.html');await p.addScriptTag({content:'let screen="room";'});
 await p.evaluate(()=>{
  document.body.innerHTML='<button data-a="sheet" data-v="messagesRoom">Messages</button>';
  window.screen='room';window.testOwner='94c0e8fb-126e-4149-ad30-6f25e3c99c33';window.testRoom='824acf3a-9119-4b97-a715-d1b080ed8ed0';window.testTracks=[];
  window.TotiLiveMode={enabled:true};window.TotiPhase2Rooms={getRoomSummary:()=>({id:window.testRoom})};
  window.TotiPhase2Auth={state:()=>({user:{id:window.testOwner}}),requestData:async()=>[]};
  window.showSheet=html=>document.body.insertAdjacentHTML('beforeend',html);
  const native=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);navigator.mediaDevices.getUserMedia=async opts=>{const media=await native(opts);window.testTracks.push(...media.getTracks());return media;};
 });
 await p.addScriptTag({path:'app/phase4-voice-messages-ui.js'});await p.click('[data-v="messagesRoom"]');await p.waitForSelector('[data-voice-message-sheet]',{timeout:3000}).catch(async e=>{console.error(await p.evaluate(()=>({mode:window.TotiLiveMode,room:window.TotiPhase2Rooms?.getRoomSummary(),screenValue:screen,body:document.body.innerHTML})));console.error(errors);throw e;});await p.click('[data-voice-message-action="record"]');
 await p.waitForFunction(()=>document.querySelector('[data-voice-message-status]').textContent.includes('جارٍ التسجيل'));
 await p.evaluate(()=>new Promise(resolve=>setTimeout(resolve,1200)));await p.click('[data-voice-message-action="record"]');await p.waitForSelector('[data-voice-message-draft] audio',{timeout:5000});
 assert.equal(await p.$eval('[data-voice-message-draft] audio',a=>a.src.startsWith('blob:')),true);
 assert.equal(await p.evaluate(()=>testTracks.every(t=>t.readyState==='ended')),true);
 await p.click('[data-voice-message-action="discard"]');await p.click('[data-voice-message-action="record"]');await p.waitForFunction(()=>testTracks.some(t=>t.readyState==='live'));
 await p.evaluate(()=>document.querySelector('[data-voice-message-sheet]').remove());await p.waitForFunction(()=>testTracks.every(t=>t.readyState==='ended'));
 await p.click('[data-v="messagesRoom"]');await p.click('[data-voice-message-action="record"]');await p.waitForFunction(()=>testTracks.some(t=>t.readyState==='live'));
 await p.evaluate(()=>{window.testOwner='different-user';window.dispatchEvent(new Event('totichat-phase2-auth'));});await p.waitForFunction(()=>testTracks.every(t=>t.readyState==='ended'));
 assert.equal(await p.$('[data-voice-message-sheet]'),null);assert.deepEqual(errors,[]);
 console.log('PASS isolated voice UI: native MediaRecorder using Chromium test microphone, draft Blob, explicit stop, overlay removal and account change stop capture. No real device/Storage delivery claimed.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
