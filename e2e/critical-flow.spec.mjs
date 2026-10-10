/* Real connected acceptance test. Never intercepts HTTP or fabricates balances. */
import {test,expect} from '@playwright/test';
import crypto from 'node:crypto';
function totp(secret){const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';let bits='';for(const c of secret.toUpperCase().replace(/[\s=]/g,'')){const n=alphabet.indexOf(c);if(n<0)throw Error('Invalid local TOTP secret');bits+=n.toString(2).padStart(5,'0');}const key=Buffer.from((bits.match(/.{8}/g)||[]).map(x=>parseInt(x,2))),counter=Buffer.alloc(8);counter.writeBigUInt64BE(BigInt(Math.floor(Date.now()/30000)));const h=crypto.createHmac('sha1',key).update(counter).digest(),o=h[19]&15;return ((h.readUInt32BE(o)&0x7fffffff)%1000000).toString().padStart(6,'0');}
async function login(page,n){
 await page.goto('/app/?mode=live');await page.locator('#fc-email').fill(process.env['TEST_USER'+n+'_EMAIL']);await page.locator('#fc-pass').fill(process.env['TEST_USER'+n+'_PASSWORD']);await page.locator('#tc-login-remember').check();await page.locator('[data-fc="validate-auth"]').click();
 await expect.poll(()=>page.evaluate(()=>window.TotiPhase2Auth.state().signedIn)).toBe(true);
 await expect.poll(()=>page.evaluate(()=>Boolean(window.TotiPhase2Auth.state().profile))).toBe(true);
 const state=await page.evaluate(()=>window.TotiPhase2Auth.securityState());expect(state.emailConfirmed).toBe(true);
 if(state.factors.some(f=>f.status==='verified')){
  const secret=process.env['TEST_USER'+n+'_TOTP_SECRET'];if(!secret)throw Error('BLOCKED: TEST_USER'+n+'_TOTP_SECRET required locally for the account with enabled 2FA');
  await page.evaluate(()=>go('me'));await page.locator('[data-phase2="account"]').click();await page.locator('[data-security-action="challenge"]').first().click();await page.locator('[data-security-code] input').fill(totp(secret));await page.locator('[data-security-code] button').click();await expect(page.locator('[data-security-status]')).toContainText('تم تأكيد');await page.evaluate(()=>closeSheet());
 }
 return page.evaluate(()=>({id:window.TotiPhase2Auth.state().user.id,name:window.TotiPhase2Auth.state().profile.display_name}));
}
async function wallet(page,id){return page.evaluate(async id=>(await window.TotiPhase2Auth.requestData('/rest/v1/wallets?select=coins,diamonds&user_id=eq.'+id))[0],id);}
async function enter(page){await page.evaluate(()=>go('home'));const id=process.env.TEST_ROOM_ID;if(await page.evaluate(()=>window.TotiPhase2Rooms.getStatus().activeRoomId)===id){await page.evaluate(()=>go('room'));return;}await page.locator('[data-phase2="open-room"][data-room="'+id+'"]').click();await expect.poll(()=>page.evaluate(()=>window.TotiPhase2Rooms.getStatus().activeRoomId)).toBe(id);}
test('two real accounts: remembered session, gift debit/credit/receipt, coin transfer',async({browser})=>{
 const c1=await browser.newContext(),c2=await browser.newContext();const s=await c1.newPage(),r=await c2.newPage();s.on('dialog',d=>d.accept());r.on('dialog',d=>d.accept());
 try{
  const u1=await login(s,1),u2=await login(r,2);expect(u1.id).not.toBe(u2.id);
  const p2=await c1.newPage();await p2.goto('/app/?mode=live');await expect.poll(()=>p2.evaluate(()=>window.TotiPhase2Auth.state().user?.id)).toBe(u1.id);await p2.close();
  await enter(s);await enter(r);await s.evaluate(()=>window.TotiPhase2Rooms.refreshRoom());
  await r.evaluate(()=>go('wallet'));await r.locator('[data-gift-receipt-action="audio"]').click();await expect(r.locator('[data-gift-receipt-action="audio"]')).toHaveText('إيقاف صوت الهدايا');await r.evaluate(()=>go('room'));
  const gifts=await s.evaluate(()=>window.TotiPhase2Auth.requestData('/rest/v1/gift_catalog?select=id,price,category_id,relationship_type_id&is_active=eq.true&order=price.asc'));
  const gift=gifts.find(g=>!g.relationship_type_id&&Number(g.price)>0);expect(gift,'Publish a real non-CP gift before E2E').toBeTruthy();
  const a=await wallet(s,u1.id),b=await wallet(r,u2.id);expect(Number(a.coins),'BLOCKED: sender must have genuine funded coins; no test minting').toBeGreaterThanOrEqual(Number(gift.price)+1);
  await r.evaluate(()=>{window.__realReceipt=null;window.addEventListener('totichat-gift-received',e=>{window.__realReceipt=e.detail;},{once:true});});
  await s.evaluate(()=>showGifts());await s.locator('[data-catalog-action="gift-category"][data-catalog-value="'+gift.category_id+'"]').click();await s.locator('[data-catalog-action="recipient"][data-catalog-value="'+u2.id+'"]').click();await s.locator('[data-catalog-action="gift-item"][data-catalog-value="'+gift.id+'"]').click();await s.locator('[data-catalog-action="gift-send"]').click();
  await expect.poll(async()=>Number((await wallet(s,u1.id)).coins)).toBe(Number(a.coins)-Number(gift.price));await expect.poll(async()=>Number((await wallet(r,u2.id)).diamonds)).toBe(Number(b.diamonds)+Number(gift.price));await expect.poll(()=>r.evaluate(()=>window.__realReceipt?.id),{timeout:15000}).toBeTruthy();
  await s.screenshot({path:'playwright-report/real-gift-sender.png'});await r.screenshot({path:'playwright-report/real-gift-recipient.png'});
  await s.evaluate(()=>{closeSheet();go('wallet');});await s.locator('[data-wallet-search] input').fill(u2.name);await s.locator('[data-wallet-search] button').click();await s.locator('[data-wallet-transfer-form] select').selectOption(u2.id);await s.locator('[data-wallet-transfer-form] input').fill('1');await s.locator('[data-wallet-transfer-form] button').click();await expect(s.locator('[data-wallet-transfer-status]')).toContainText('تم التحويل');
  await expect.poll(async()=>Number((await wallet(s,u1.id)).coins)).toBe(Number(a.coins)-Number(gift.price)-1);await expect.poll(async()=>Number((await wallet(r,u2.id)).coins)).toBe(Number(b.coins)+1);
  await s.screenshot({path:'playwright-report/real-transfer.png'});
 }finally{await c1.close();await c2.close();}
});
