/* Mocked browser contract only. Live catalog counts/grants are audited separately. */
'use strict';
const puppeteer=require('puppeteer-core'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/chromium'].find(fs.existsSync);
const seed=JSON.parse(fs.readFileSync(path.join(__dirname,'../supabase/reference/catalogs.json'),'utf8')).tables;
const user={id:'94c0e8fb-126e-4149-ad30-6f25e3c99c33',email:'catalog@test.invalid'};
let browser;const calls=[],errors=[];
const reply=data=>({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'},body:JSON.stringify(data)});
(async()=>{
 browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox','--disable-setuid-sandbox']});
 const p=await browser.newPage();await p.setViewport({width:390,height:844});
 p.on('pageerror',e=>errors.push(e.message));
 await p.setRequestInterception(true);
 p.on('request',async req=>{
  const url=new URL(req.url());
  if(!url.hostname.endsWith('.supabase.co'))return req.continue();
  calls.push({path:url.pathname,method:req.method()});
  if(req.method()==='OPTIONS')return req.respond(reply(null));
  if(url.pathname==='/auth/v1/settings')return req.respond(reply({external:{}}));
  if(url.pathname==='/auth/v1/token')return req.respond(reply({access_token:'test-token',refresh_token:'test-refresh',expires_in:3600,user}));
  if(url.pathname==='/auth/v1/user')return req.respond(reply(user));
  const body=JSON.parse(req.postData()||'{}');
  if(url.pathname==='/rest/v1/rpc/phase3_admin_session')return req.respond(reply({isOwner:true,isMainPartner:false,canManageCatalogs:true}));
  if(url.pathname==='/rest/v1/rpc/phase3_catalog_list'){
   const rows=seed[body.p_table];
   return req.respond(reply({rows,total:rows.length,offset:0,columns:Object.keys(rows[0]).map(name=>({name,type:typeof rows[0][name]==='boolean'?'boolean':typeof rows[0][name]==='number'?'integer':'text',nullable:true,hasDefault:true}))}));
  }
  if(url.pathname==='/rest/v1/rpc/phase3_catalog_write'){
   assert.equal(body.p_table,'gift_categories');assert.equal(body.p_action,'update');assert.equal(body.p_record.label,'QA updated label');assert.match(body.p_request_id,/^[0-9a-f-]{36}$/);
   const row=seed.gift_categories.find(r=>r.id===body.p_id);Object.assign(row,body.p_record);return req.respond(reply(row));
  }
  const table=url.pathname.split('/').pop();
  if(table==='profiles')return req.respond(reply([{id:user.id,display_name:'Catalog Tester',bio:'',avatar_url:null}]));
  if(table==='wallets')return req.respond(reply([{user_id:user.id,coins:0,diamonds:0}]));
  if(seed[table]){
   assert.equal(req.headers().authorization,'Bearer test-token');
   const rows=structuredClone(seed[table]);
   if(table==='store_catalog')rows[0].name='<img src=x onerror=alert(1)>';
   return req.respond(reply(rows));
  }
  return req.respond(reply([]));
 });
 await p.goto((process.env.UI_URL||'http://127.0.0.1:8765/app/')+'?mode=live',{waitUntil:'networkidle0'});
 await p.type('#fc-email',user.email);await p.type('#fc-pass','Password123!');
 await p.click('[data-fc="validate-auth"]');
 await p.waitForFunction(()=>window.TotiPhase2Auth.state().profile?.display_name==='Catalog Tester');
 await p.evaluate(()=>go('me'));
 await p.click('[data-phase2="account"]');
 await p.waitForSelector('[data-admin-open]');await p.click('[data-admin-open]');
 await p.waitForSelector('[data-admin-table]');
 await p.select('[data-admin-table]','gift_categories');
 await p.waitForFunction(()=>document.querySelector('[data-admin-records]')?.textContent.includes('CP'));
 await p.click('[data-admin-action="edit"]');
 await p.waitForSelector('[data-admin-form] [name="label"]');
 await p.$eval('[data-admin-form] [name="label"]',e=>{e.value='QA updated label';});
 p.on('dialog',dialog=>dialog.accept());
 await p.click('[data-admin-form] button');
 await p.waitForFunction(()=>document.querySelector('[data-admin-status]')?.textContent.includes('تم حفظ العملية'));
 assert.equal(calls.filter(c=>c.path==='/rest/v1/rpc/phase3_catalog_write'&&c.method==='POST').length,1);
 assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
 await p.evaluate(()=>closeSheet());
 await p.evaluate(()=>{window.dispatchEvent(new CustomEvent('totichat-phase2-auth',{detail:{signedIn:false}}));});
 assert.equal(await p.$('[data-admin-sheet]'),null);
 assert.deepEqual(errors,[]);
 console.log('PASS: server-authorized admin entry, schema-driven catalog edit, one idempotent RPC, mobile overflow and logout cleanup (browser contract).');
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{await browser?.close();});
