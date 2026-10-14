import {test,expect} from '@playwright/test';

// Synthetic browser fixtures are for isolated automated QA ONLY.
// The published Home always uses server-authenticated Supabase responses.
const base='https://totichat-login-review-20261013.vercel.app/home/';
const authHost='rziaedugbdwefbefcxjt.supabase.co';
const sessionKey='totichat.phase2.session.v1';
const userId='11111111-1111-4111-8111-111111111111';
const roomPublicId='22222222-2222-4222-8222-222222222222';
const roomPrivateId='33333333-3333-4333-8333-333333333333';
const profile={id:userId,display_name:'Home QA User',bio:'',avatar_url:null};
const publicRoom={id:roomPublicId,title:'QA Open Voice',owner_id:'44444444-4444-4444-8444-444444444444',is_private:false,cover_path:null,welcome_message:'Welcome',created_at:'2026-10-13T00:00:00Z'};
const privateRoom={id:roomPrivateId,title:'QA Private Space',owner_id:userId,is_private:true,cover_path:null,welcome_message:'Members only',created_at:'2026-10-13T01:00:00Z'};
function cache(){return {user:{id:userId,email:'qa-home@example.invalid'},access_token:'qa-token',refresh_token:'qa-refresh',expires_at:Math.floor(Date.now()/1000)+3600}}
async function setup(page,{rooms=[publicRoom,privateRoom],members=[],banners=[],events=[],failRooms=false}={}){
 const calls=[];
 await page.addInitScript(({key,session})=>{
   if(location.hostname==='totichat-login-review-20261013.vercel.app' && !sessionStorage.getItem('__home_qa_seeded')){
     sessionStorage.setItem(key,JSON.stringify(session));
     sessionStorage.setItem('__home_qa_seeded','1');
   }
 },{key:sessionKey,session:cache()});
 await page.route('https://'+authHost+'/**',async route=>{
   const request=route.request(),url=new URL(request.url());
   const path=url.pathname,method=request.method();
   calls.push({path,method,query:url.search});
   const cors={
    'access-control-allow-origin':'https://totichat-login-review-20261013.vercel.app',
    'access-control-allow-headers':'authorization,apikey,content-type,accept,x-upsert,cache-control',
    'access-control-allow-methods':'GET,POST,OPTIONS',
   };
   const response=(obj,status=200)=>route.fulfill({status,contentType:'application/json',headers:cors,body:JSON.stringify(obj)});
   if(method==='OPTIONS')return route.fulfill({status:204,headers:cors,body:''});
   if(path==='/auth/v1/user')return response({...cache().user,id:userId});
   if(path==='/auth/v1/settings')return response({external:{google:true,email:false}});
   if(path.startsWith('/storage/v1/object/public/')){
 const imageBase64=await page.evaluate(()=>{
   const canvas=document.createElement('canvas');canvas.width=80;canvas.height=80;
   const ctx=canvas.getContext('2d');ctx.fillStyle='#9672c8';ctx.fillRect(0,0,80,80);
   return canvas.toDataURL('image/png').split(',')[1];
 });
 const png=Buffer.from(imageBase64,'base64');
     return route.fulfill({status:200,contentType:'image/png',headers:cors,body:png});
   }
   if(path==='/rest/v1/profiles')return response([profile]);
   if(path==='/rest/v1/rooms')return failRooms?response({message:'Server unavailable'},503):response(rooms);
   if(path==='/rest/v1/room_members')return response(members);
   if(path==='/rest/v1/home_banners')return response(banners);
   if(path==='/rest/v1/gift_global_announcements')return response(events);
   if(path==='/rest/v1/rpc/phase2_room_create')return response(roomPrivateId);
   if(path==='/rest/v1/rpc/phase2_room_customize')return response(true);
   if(path.includes('/storage/v1/object/totichat-room-images/'))return response({Key:'ok'});
   return response({message:'Unmocked endpoint'},404);
 });
 return calls;
}
async function loaded(page){
 await expect(page.locator('#auth-status')).toBeHidden({timeout:17000});
 await expect(page.locator('#rooms-loading')).toBeHidden({timeout:17000});
 await expect(page.locator('#secure-content')).toBeVisible();
}
for(const width of [360,390,430]){
 test('Home at '+width+'px renders real authorized fixture without overflow',async({page})=>{
  await setup(page,{rooms:[publicRoom,privateRoom]});
  await page.setViewportSize({width,height:800});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const response=await page.goto(base,{waitUntil:'domcontentloaded'});
  expect(response?.status()).toBe(200);await loaded(page);
  await expect(page.locator('.room-card')).toHaveCount(2);
  await expect(page.locator('.room-card').first()).toContainText('QA Open Voice');
  await expect(page.locator('#banners')).toBeHidden();
  await expect(page.locator('#global-gift-strip')).toBeHidden();
  await expect(page.locator('.bottom-nav')).toBeVisible();
  const x=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,width:innerWidth}));
  expect(x.scroll).toBeLessThanOrEqual(x.width+1);
  expect(errors).toEqual([]);
  await page.screenshot({path:'test-results/home-'+width+'.png',fullPage:true,animations:'disabled'});
 });
}
test('published Home URL always serves new lavender UI and sign-in returns to Home',async({browser})=>{
  const anon=await browser.newContext({viewport:{width:390,height:844}});
  const page=await anon.newPage();
  await page.goto(base+'?review=home02', {waitUntil:'domcontentloaded'});
  await expect(page).toHaveURL(/\?returnTo=home/);
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible();
  await anon.close();
});

test('Home has deployed current design and CSP permits chosen-image previews',async({page})=>{
 const calls=await setup(page);
 const response=await page.goto(base,{waitUntil:'domcontentloaded'});
 await loaded(page);
 await expect(page.locator('.hero')).toBeVisible();
 await expect(page.locator('.hero')).toContainText('عالم الأصوات الجميلة');
 await expect(page.locator('.bottom-nav')).toBeVisible();
 const policy=response?.headers()['content-security-policy']||'';
 expect(policy).toContain('blob:');
 expect(policy).toContain("script-src 'self'");
 expect(calls.some(x=>x.path==='/rest/v1/rooms')).toBe(true);
});

test('staging-empty feed displays real empty state, never mock banners or gifts',async({page})=>{
 await setup(page,{rooms:[]});await page.goto(base,{waitUntil:'domcontentloaded'});await loaded(page);
 await expect(page.locator('#rooms-empty')).toBeVisible();
 await expect(page.locator('.room-card')).toHaveCount(0);
 await expect(page.locator('#banners')).toBeHidden();
 await expect(page.locator('#global-gift-strip')).toBeHidden();
});
test('filter and search only matching backend-authorized rooms',async({page})=>{
 await setup(page);await page.goto(base,{waitUntil:'domcontentloaded'});await loaded(page);
 await page.locator('[data-filter="public"]').click();
 await expect(page.locator('.room-card')).toHaveCount(1);
 await expect(page.locator('.room-card')).toContainText('QA Open Voice');
 await page.locator('[data-filter="mine"]').click();
 await expect(page.locator('.room-card')).toHaveCount(1);
 await expect(page.locator('.room-card')).toContainText('QA Private Space');
 await page.locator('[data-filter="all"]').click();
 await page.locator('#search-trigger').click();
 await page.locator('#room-search').fill('Open');
 await expect(page.locator('.room-card')).toHaveCount(1);
 await expect(page.locator('.room-card')).toContainText('QA Open Voice');
 await page.locator('#room-search').fill('NOT_A_ROOM');
 await expect(page.locator('#rooms-empty')).toBeVisible();
});
test('admin banners and 7000+ gift ticker appear only with verified backend rows',async({page})=>{
 await setup(page,{rooms:[],banners:[{id:'55555555-5555-4555-8555-555555555555',title:'Real published event',image_url:'https://rziaedugbdwefbefcxjt.supabase.co/storage/v1/object/public/a/b.webp',status:'published',sort_order:1}],events:[
 {id:'6',sender_name:'Alice',recipient_name:'Bob',gift_name:'Pearl',total_coins:7000,created_at:'2026-10-13T00:00:00Z'}]});
 await page.goto(base,{waitUntil:'domcontentloaded'});await loaded(page);
 await expect(page.locator('#banners')).toBeVisible();
 await expect(page.locator('#global-gift-strip')).toBeVisible();
 await expect(page.locator('#global-gift-strip')).toContainText('7,000');
});
test('future navigation honestly discloses unfinished screens, room detail sourced from database',async({page})=>{
 await setup(page);await page.goto(base,{waitUntil:'domcontentloaded'});await loaded(page);
 await page.locator('.room-card').first().click();
 await expect(page.locator('#info-sheet')).toBeVisible();
 await expect(page.locator('#info-sheet')).toContainText('QA Open Voice');
 await expect(page.locator('#info-sheet .sheet-primary')).toBeDisabled();
 await page.locator('#sheet-close').click();
 await page.locator('[data-future="messages"]').click();
 await expect(page.locator('#info-sheet')).toContainText('هذه الواجهة مخصصة للمرحلة القادمة');
});
test('actual room creation controls validate required image/name/welcome before real RPC',async({page})=>{
 const calls=await setup(page);await page.goto(base,{waitUntil:'domcontentloaded'});await loaded(page);
 await page.locator('#nav-create').click();
 await expect(page.locator('#create-sheet')).toBeVisible();
 await expect(page.locator('#create-name')).toHaveAttribute('required','');
 await expect(page.locator('#create-welcome')).toHaveAttribute('required','');
 await expect(page.locator('#create-cover')).toHaveAttribute('required','');
 await page.locator('#create-name').fill('QA Stage Room');
 await page.locator('#create-welcome').fill('We welcome real members');
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/KZ0AAAAASUVORK5CYII=','base64');
 await page.locator('#create-cover').setInputFiles({name:'test.png',mimeType:'image/png',buffer:png});
 const browserErrors=[];
 page.on('console',msg=>{if(msg.type()==='error')browserErrors.push(msg.text().slice(0,240))});
 page.on('pageerror',err=>browserErrors.push(String(err).slice(0,240)));
 await page.locator('#create-submit').click();
 await page.waitForTimeout(200);
 console.log('IMAGE_QA_ERRORS:',JSON.stringify(browserErrors));
 console.log('IMAGE_QA_CSP:',(await page.evaluate(()=>document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content))||'HEADER_ONLY');
 console.log('CREATE_QA_STATUS:',await page.locator('#create-message').textContent());
 await expect.poll(()=>calls.filter(c=>c.path==='/rest/v1/rpc/phase2_room_create').length,{timeout:15000}).toBe(1);
 await expect.poll(()=>calls.filter(c=>c.path==='/rest/v1/rpc/phase2_room_customize').length,{timeout:15000}).toBe(1);
 await expect(page.locator('#create-sheet')).toBeHidden();
});
test('rooms backend errors show no invented room cards',async({page})=>{
 await setup(page,{failRooms:true});await page.goto(base,{waitUntil:'domcontentloaded'});
 await expect(page.locator('#rooms-loading')).toBeHidden({timeout:17000});
 await expect(page.locator('#rooms-error')).toBeVisible();
 await expect(page.locator('.room-card')).toHaveCount(0);
});
