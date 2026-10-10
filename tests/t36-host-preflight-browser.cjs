/* Isolated DOM/Chromium fixture: no network to Supabase, no production finance actions. */
'use strict';
const assert=require('node:assert/strict');
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const chrome=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium'].find(fs.existsSync);
if(!chrome)throw Error('T36 Chromium required');
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:chrome,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.setViewport({width:390,height:844});
  await page.goto('http://127.0.0.1:8765/t36-isolated-fixture',{waitUntil:'domcontentloaded'});
  await page.setContent('<!doctype html><html lang="ar"><body><button data-agencies-open>Open agencies</button><div id="sheet"></div></body></html>');
  await page.evaluate(()=>{
   window.__fixture={id:'11111111-1111-4111-8111-111111111111',canHost:true,calls:[]};
   window.TotiLiveMode={enabled:true};
   window.TotiPhase2Auth={
    state:()=>({signedIn:true,user:{id:window.__fixture.id}}),
    requestData:async(path,{body})=>{
     const x=window.__fixture;x.calls.push({path,body});
     if(path.endsWith('/phase4_agency_state'))return {
      authority:{canManageHostAgencies:x.canHost,canManageRechargeAgencies:false},
      agencies:[],registrations:[],requests:[],members:[]
     };
     if(path.endsWith('/phase5_host_month_preflight')){
      if(!x.canHost)throw Error('Permission denied');
      return {month:body.p_month,totalHostEntries:1,isDraftPreflight:true,
       canZeroDiamonds:false,paysSalaries:false,hasPayrollRates:false,
       entries:[{agency_id:'22222222-2222-4222-8222-222222222222',
        user_id:'33333333-3333-4333-8333-333333333333',
        earned_diamonds:120,remaining_diamonds:80,converted_or_allocated_diamonds:40}]};
     }
     throw Error('Unexpected RPC '+path);
    }
   };
   window.showSheet=html=>{document.querySelector('#sheet').innerHTML=html;};
   window.confirm=()=>true;
  });
  await page.addScriptTag({path:'app/phase4-agencies-ui.js'});
  await page.click('[data-agencies-open]');
  await page.waitForSelector('[data-agency-month-section]');
  const selected=await page.$eval('[data-agency-month]',e=>({value:e.value,max:e.max}));
  assert.equal(selected.value,selected.max,'Only the last closed UTC month is default');
  await page.click('[data-agency-action="month-preflight"]');
  await page.waitForFunction(()=>document.querySelector('[data-agency-month-results]')?.textContent.includes('120'));
  assert.match(await page.$eval('[data-agency-month-results]',e=>e.textContent),/لم تُنفذ|لم تُنفذ/);
  assert.equal(await page.evaluate(()=>window.__fixture.calls.filter(c=>c.path.includes('host_month_preflight')).length),1);
  assert.equal(await page.evaluate(()=>window.__fixture.calls.some(c=>/phase4_agency_action|recharge_action|month_close/i.test(c.path))),false);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),true);
  await page.evaluate(()=>{
   window.__fixture.id='44444444-4444-4444-8444-444444444444';
   window.__fixture.canHost=false;
   window.dispatchEvent(new Event('totichat-phase2-auth'));
  });
  await page.click('[data-agencies-open]');
  await page.waitForSelector('[data-agency-sheet]');
  await page.waitForFunction(()=>document.querySelector('[data-agency-body]')?.textContent.includes('طلب فتح وكالة'));
  assert.equal(await page.$('[data-agency-month-section]'),null,'Non-host administrator cannot see Owner/main partner preflight');
  assert.deepEqual(errors,[]);
  console.log('PASS T36 isolated Chromium: historical month preview, no settlement calls, host authority gating, account switch cleanup, mobile fit.');
 } finally { await browser.close(); }
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
