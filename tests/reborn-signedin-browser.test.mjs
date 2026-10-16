import assert from 'node:assert/strict';
import {chromium} from '@playwright/test';
import {existsSync} from 'node:fs';
const executablePath=['/usr/bin/google-chrome','/usr/bin/chromium','/usr/bin/chromium-browser'].find(existsSync);
if(!executablePath)throw Error('Browser unavailable');
const browser=await chromium.launch({headless:true,executablePath,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844}});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
function mockAuth(){
 const user={id:'11111111-1111-4111-8111-111111111111',email:'mock@test.invalid'};
 const profile={id:user.id,display_name:'Contract QA',bio:'',avatar_url:null};
 const room={id:'22222222-2222-4222-8222-222222222222',title:'Room Contract Fixture',
  owner_id:user.id,is_private:false,cover_path:null,created_at:new Date().toISOString(),welcome_message:'Welcome QA'};
 const members=[{user_id:user.id,display_name:'Contract QA',seat_no:1,is_muted:true}];
 window.TotiPhase2Auth={
  state:()=>({signedIn:true,user,profile}),resume:async()=>true,
  requestData:async(path,options)=>{
   if(path.includes('home_banners'))return [];
   if(path.includes('/rooms?'))return [room];
   if(path.includes('/room_messages?'))return [];
   if(path.includes('/wallets?'))return [{user_id:user.id,coins:125,diamonds:4,silver:0}];
   if(path.includes('phase3_admin_session'))return {role:'user',isOwner:false,isMainPartner:false,canManageCatalogs:false,canReadReports:false};
   if(path.includes('phase2_room_join'))return true;
   if(path.includes('phase2_room_members_visual'))return members;
   if(path.includes('phase2_room_take_seat'))return 1;
   if(path.includes('phase2_room_leave'))return true;
   return [];
  },
  watchRoomUpdates:()=>({close(){}}),providers:async()=>({google:true}),
  signInWithProvider:async()=>true,signOut:async()=>true,
  requestVoiceToken:async()=>{throw Error('Voice disabled in UI-only fixture')}
 };
}
await page.route('**/app/phase2-auth.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:'('+mockAuth.toString()+')();'}));
await page.goto('http://127.0.0.1:8765/',{waitUntil:'domcontentloaded'});
await page.getByText('Room Contract Fixture').waitFor({timeout:11000});
assert.equal(await page.locator('.room-tile').count(),1);
assert.equal(await page.locator('.promo').count(),0,'Never render invented banners in live home');
await page.locator('[data-nav="explore"]').first().click();
await page.getByText('Room Contract Fixture').waitFor();
assert.equal(await page.locator('[data-input="search"]').count(),1);
await page.locator('.room-tile').first().click();
await page.locator('.seats .seat').first().waitFor();
assert.equal(await page.locator('.seats .seat').count(),15);
assert.equal(await page.locator('#chat-form').count(),1);
assert.equal(await page.locator('[data-act="voice"]').count(),1);
await page.locator('[data-act="roomMenu"]').first().click();
assert.equal(await page.getByText('تصغير الغرفة').count(),1);
assert.equal(await page.getByText('مغادرة الغرفة').count(),1);
await page.getByText('تصغير الغرفة').click();
assert.equal(await page.locator('.mini-room').count(),1,'Minimized room must stay accessible');
await page.locator('[data-nav="me"]').first().click();
assert.equal(await page.getByText('مركز الإدارة').count(),0,'Regular member cannot see Admin entry');
await page.locator('[data-nav="wallet"]').first().click();
await page.getByText('125').waitFor();
assert.deepEqual(errors,[]);
await page.screenshot({path:'/tmp/totichat-reborn-signedin.png',fullPage:true});
await browser.close();
console.log('PASS: REBORN real-API-shaped UI contract: home, rooms, 15 seats, room menu, minimize, wallet and role.');
