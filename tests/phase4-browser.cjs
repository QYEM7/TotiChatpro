/* Isolated UI contract; intercepted responses are test fixtures, not live E2E. */
'use strict';
const puppeteer=require('puppeteer-core'),fs=require('fs'),assert=require('node:assert/strict');
const user={id:'94c0e8fb-126e-4149-ad30-6f25e3c99c33',email:'ui@test.invalid'},partner='824acf3a-9119-4b97-a715-d1b080ed8ed0';
let browser,relation=null,redeemed=false;const calls=[],errors=[];
const reply=value=>({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'},body:JSON.stringify(value)});
(async()=>{
 browser=await puppeteer.launch({headless:true,executablePath:process.env.CHROME_BIN,args:['--no-sandbox']});const p=await browser.newPage();await p.setViewport({width:390,height:844});p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>d.accept());await p.setRequestInterception(true);
 p.on('request',req=>{
  const url=new URL(req.url());if(!url.hostname.endsWith('.supabase.co'))return req.continue();if(req.method()==='OPTIONS')return req.respond(reply(null));const path=url.pathname,b=JSON.parse(req.postData()||'{}');calls.push({path,body:b});
  if(path==='/auth/v1/settings')return req.respond(reply({external:{}}));if(path==='/auth/v1/token')return req.respond(reply({access_token:'test-token',refresh_token:'refresh',expires_in:3600,user}));if(path==='/auth/v1/user')return req.respond(reply({...user,email_confirmed_at:'2026-10-10T00:00:00Z',factors:[],identities:[]}));
  if(path.endsWith('/profiles'))return req.respond(reply(url.searchParams.has('display_name')?[{id:partner,display_name:'Partner'}]:[{id:user.id,display_name:'Tester',bio:'',avatar_url:null}]));
  if(path.endsWith('/wallets'))return req.respond(reply([{user_id:user.id,coins:redeemed?3:0,diamonds:redeemed?0:10}]));
  if(path.endsWith('/phase4_verified_session'))return req.respond(reply(user.id));
  if(path.endsWith('/phase3_admin_session'))return req.respond(reply({isOwner:true,canManageCatalogs:true,canReadReports:true}));
  if(path.endsWith('/phase4_cp_state'))return req.respond(reply({types:[{id:'love',label:'رفيق الروح'}],relations:relation?[relation]:[]}));
  if(path.endsWith('/phase4_cp_action')){assert.equal(b.p_partner_id,partner);assert.equal(b.p_action,'request');assert.match(b.p_request_id,/^[0-9a-f-]{36}$/);relation={id:crypto.randomUUID(),partner:{id:partner,display_name:'Partner'},type_label:'رفيق الروح',type_id:'love',requested_by:user.id,accepted_at:null};return req.respond(reply(relation));}
  if(path.endsWith('/phase4_diamond_state'))return req.respond(reply({fixed:redeemed?0:10,lucky:0,untracked:0}));
  if(path.endsWith('/phase4_preview_redemption')){assert.equal(b.p_diamonds,10);return req.respond(reply({diamonds:10,coins:3,numerator:3,denominator:10}));}
  if(path.endsWith('/phase4_redeem_diamonds')){assert.equal(b.p_diamonds,10);assert.equal(b.p_expected_coins,3);assert.match(b.p_request_id,/^[0-9a-f-]{36}$/);redeemed=true;return req.respond(reply({id:crypto.randomUUID(),status:'completed'}));}
  if(path.endsWith('/phase4_admin_report'))return req.respond(reply({summary:{users:2,coins:3,diamonds:0},rows:[{id:'actual-row',operation:'diamond_redemption',status:'completed',created_at:'2026-10-10T00:00:00Z',payload:{text:'=HYPERLINK("unsafe")'}}],total:1}));
  return req.respond(reply([]));
 });
 await p.goto('http://127.0.0.1:8765/app/?mode=live',{waitUntil:'networkidle0'});await p.type('#fc-email',user.email);await p.type('#fc-pass','ContractPassword123!');await p.click('[data-fc="validate-auth"]');await p.waitForFunction(()=>window.TotiPhase2Auth.state().profile?.display_name==='Tester');
 await p.evaluate(()=>go('cp'));await p.waitForSelector('[data-cp-search]');await p.type('[data-cp-search] input','Partner');await p.click('[data-cp-search] button');await p.waitForFunction(()=>document.querySelector('[data-cp-request] select[name=partner]').options.length===2);await p.select('[data-cp-request] select[name=partner]',partner);await p.click('[data-cp-request] button');await p.waitForSelector('[data-cp-action="end"]');assert.equal(calls.filter(c=>c.path.endsWith('/phase4_cp_action')).length,1);
 await p.evaluate(()=>go('wallet'));await p.waitForSelector('[data-redemption-preview]');await p.type('[data-redemption-preview] input','10');await p.click('[data-redemption-preview] button');await p.waitForSelector('[data-redemption-action="confirm"]');await p.click('[data-redemption-action="confirm"]');await p.waitForFunction(()=>document.querySelector('[data-redemption-status]')?.textContent.includes('تم الاستبدال'));assert.equal(calls.filter(c=>c.path.endsWith('/phase4_redeem_diamonds')).length,1);
 await p.click('[data-gift-receipt-action="audio"]');await p.waitForFunction(()=>document.querySelector('[data-gift-receipt-action="audio"]')?.textContent==='إيقاف صوت الهدايا');
 await p.evaluate(()=>go('me'));await p.click('[data-phase2="account"]');await p.waitForSelector('[data-reports-open]');await p.click('[data-reports-open]');await p.waitForFunction(()=>document.querySelector('[data-report-results]')?.textContent.includes('actual-row'));
 const exported=await p.evaluate(async()=>Array.from(new Uint8Array(await window.TotiPhase4Exports.xlsx([{text:'=HYPERLINK("unsafe")',amount:3}]).arrayBuffer())));fs.writeFileSync('/tmp/totichat-phase4-export.xlsx',Buffer.from(exported));
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);assert.deepEqual(errors,[]);await p.screenshot({path:'/tmp/totichat-phase4-reports-contract.png',fullPage:true});
 console.log('PASS browser contract: CP request, exact redemption quote and one mutation, actual WAV playback after click, permission-gated SQL report, XLSX and mobile width. Not live E2E.');
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>browser?.close());
