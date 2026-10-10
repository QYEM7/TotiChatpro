/* T42 browser contract: local fixture only, never a live Supabase account. */
'use strict';
const puppeteer=require('puppeteer-core');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const exe=process.env.CHROME_BIN||['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium'].find(fs.existsSync);
if(!exe)throw Error('Browser QA requires Chrome/Chromium');
const OWNER='5c4f8202-4400-4b2e-8000-111111111111';
const AGENT='5c4f8202-4400-4b2e-8000-222222222222';
const CUSTOMER='5c4f8202-4400-4b2e-8000-333333333333';
(async()=>{
 const browser=await puppeteer.launch({headless:true,executablePath:exe,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.setViewport({width:390,height:844});
  await page.goto('http://127.0.0.1:8765/t42-isolated-contract-fixture',{waitUntil:'domcontentloaded'});
  await page.setContent('<!doctype html><html lang="ar"><head><meta charset="UTF-8"></head><body><button data-support-open>Open support</button><div id="test-sheet"></div></body></html>');
  await page.evaluate(({OWNER,AGENT,CUSTOMER})=>{
   window.__mock={uid:OWNER,owner:true,canHandle:true,calls:[],tickets:[],messages:new Map(),next:0};
   window.TotiPhase2Auth={
    state:()=>({signedIn:!!window.__mock.uid,user:window.__mock.uid?{id:window.__mock.uid}:null}),
    requestData:async(path,{body})=>{
     const m=window.__mock;
     m.calls.push({path,body,uid:m.uid});
     if(path.endsWith('/phase3_admin_session'))return {isOwner:m.owner};
     if(path.endsWith('/phase5_support_list')){
      if(body.p_scope==='all'&&!m.canHandle)throw Error('Support scope denied');
      const rows=m.tickets.filter(t=>body.p_scope==='all'||t.creator_id===m.uid);
      return {rows,total:rows.length,canHandle:m.canHandle};
     }
     if(path.endsWith('/phase5_support_thread')){
      const ticket=m.tickets.find(t=>t.id===body.p_ticket_id);
      if(!ticket||(!m.canHandle&&ticket.creator_id!==m.uid))throw Error('Ticket not found');
      return {ticket,messages:m.messages.get(ticket.id)||[],canHandle:m.canHandle};
     }
     if(path.endsWith('/phase5_support_action')){
      const act=body.p_action;
      if(['staff_grant','staff_revoke'].includes(act)){
       if(!m.owner)throw Error('Owner only');
       return {id:body.p_data.user_id,enabled:act==='staff_grant'};
      }
      if(act==='create'){
       const id=crypto.randomUUID(),t={id,creator_id:m.uid,subject:body.p_data.subject,category:body.p_data.category,
         status:'open',updated_at:new Date().toISOString()};
       m.tickets.push(t);m.messages.set(id,[{author_id:m.uid,body:body.p_data.message,created_at:t.updated_at}]);
       return {id,status:'open'};
      }
      const t=m.tickets.find(x=>x.id===body.p_data.ticket_id);
      if(!t)throw Error('Ticket not found');
      if(act==='reply'){m.messages.get(t.id).push({author_id:m.uid,body:body.p_data.message,created_at:new Date().toISOString()});t.status='waiting_user';}
      if(act==='status')t.status=body.p_data.status;
      return {id:t.id,status:t.status};
     }
     throw Error('Unexpected API route: '+path);
    }
   };
   window.showSheet=html=>{document.querySelector('#test-sheet').innerHTML=html;};
   window.confirm=()=>true;
  },{OWNER,AGENT,CUSTOMER});
  await page.addScriptTag({path:'app/phase5-support-ui.js'});
  await page.click('[data-support-open]');
  await page.waitForSelector('[data-t42-form="staff"]');
  await page.type('[data-t42-form="staff"] [name="user_id"]',AGENT);
  await page.select('[data-t42-form="staff"] [name="decision"]','staff_grant');
  const formState=await page.$eval('[data-t42-form="staff"]',form=>({
   valid:form.checkValidity(),
   id:form.querySelector('[name="user_id"]')?.value,
   decision:form.querySelector('[name="decision"]')?.value,
   controls:[...form.elements].map(x=>({
      tag:x.tagName,name:x.name,value:x.value,valid:x.validity?.valid,
      reason:x.validationMessage,pattern:x.pattern,required:x.required
   })),
   markup:form.outerHTML.slice(0,2000)
  }));
  assert.equal(formState.valid,true,'Staff form client validation: '+JSON.stringify(formState));
  await page.click('[data-t42-form="staff"] button[type="submit"]');
  await page.waitForFunction(()=>window.__mock.calls.some(c=>c.body?.p_action==='staff_grant'),{timeout:5000})
    .catch(async error=>{console.error('T42 staff form diagnostic',await page.evaluate(()=>({
       calls:window.__mock.calls.slice(-8),
       status:document.querySelector('[data-t42-status]')?.textContent,
       fields:[...document.querySelectorAll('[data-t42-form="staff"] input, [data-t42-form="staff"] select')].map(x=>({name:x.name,value:x.value,valid:x.validity.valid})),
       buttons:[...document.querySelectorAll('[data-t42-form="staff"] button')].map(x=>({disabled:x.disabled,type:x.type}))
      })));throw error;});
  const staffCall=await page.evaluate(()=>window.__mock.calls.find(c=>c.body?.p_action==='staff_grant'));
  assert.equal(staffCall.body.p_data.user_id,AGENT);
  assert.match(staffCall.body.p_request_id,/^[0-9a-f-]{36}$/i);

  await page.evaluate(({uid})=>{window.__mock.uid=uid;window.__mock.owner=false;window.__mock.canHandle=true;window.dispatchEvent(new Event('totichat-phase2-auth'));},{uid:AGENT});
  await page.click('[data-support-open]');
  await page.waitForSelector('[data-t42-form="create"]');
  assert.equal(await page.$('[data-t42-form="staff"]'),null,'Non-owner staff assignment UI must stay hidden');
  assert.equal(await page.$('[data-scope="all"]')!==null,true);

  await page.evaluate(({uid})=>{window.__mock.uid=uid;window.__mock.canHandle=false;window.dispatchEvent(new Event('totichat-phase2-auth'));},{uid:CUSTOMER});
  await page.click('[data-support-open]');
  await page.waitForSelector('[data-t42-form="create"]');
  assert.equal(await page.$('[data-scope="all"]'),null,'Customer may not see staff inbox');
  await page.type('[data-t42-form="create"] [name="subject"]','Browser contract support ticket');
  await page.type('[data-t42-form="create"] [name="message"]','I need to contact customer support');
  await page.click('[data-t42-form="create"] button[type="submit"]');
  await page.waitForFunction(()=>window.__mock.calls.some(c=>c.body?.p_action==='create'));
  await page.waitForSelector('[data-t42-form="reply"]');
  await page.type('[data-t42-form="reply"] [name="message"]','Follow-up message');
  await page.click('[data-t42-form="reply"] button[type="submit"]');
  await page.waitForFunction(()=>window.__mock.calls.some(c=>c.body?.p_action==='reply'));
  await page.waitForFunction(()=>document.querySelector('[data-t42-thread]')?.textContent.includes('Follow-up message'));
  const create=await page.evaluate(()=>window.__mock.calls.find(c=>c.body?.p_action==='create'));
  assert.equal(create.body.p_data.category,'general');
  assert.equal(create.uid,CUSTOMER);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),true);
  await page.evaluate(()=>{window.__mock.uid=null;window.dispatchEvent(new Event('totichat-phase2-auth'));});
  assert.equal(await page.$('#t42-support-sheet'),null,'Logout clears private support content');
  assert.deepEqual(errors,[]);
  console.log('PASS T42 isolated Chrome: Owner-only staff grant, non-owner UI denied, private customer request + reply, account cleanup and mobile fit. Mock API only; hosted E2E not claimed.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});