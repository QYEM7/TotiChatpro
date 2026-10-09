/* TotiChat Phase 2 — read-only REAL wallet.
 * No browser minting, no locally invented balances, no agent payment writes.
 * All balance and ledger values must be read from the independent Supabase DB.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=(s,r=document)=>r.querySelector(s);
const $$=(s,r=document)=>Array.from(r.querySelectorAll(s));
let wallet=null,ledger=null,error='',busy=false,owner='';
const format=x=>{
 const n=Number(x);
 return Number.isSafeInteger(n)&&n>=0?n.toLocaleString('en-US'):'—';
};
const status=()=>({
  ownerId:owner||null,loaded:!!wallet,
  coins:wallet?format(wallet.coins):null,
  diamonds:wallet?format(wallet.diamonds):null,
  entries:ledger?.length??null,
  error:error||null
});
function paint(){
 if(screen!=='wallet'||!auth.state().signedIn)return;
 const hero=$('#app .visual-hero');
 if(!hero)return;
 const user=auth.state().user;
 if(!user||owner!==user.id)return;
 const container=hero.parentElement;
 if(!container)return;
 const oldWarn=$('.visual-warn',container);
 if(oldWarn)oldWarn.textContent='✓ الأرصدة والمعاملات أدناه تُقرأ من خادم TotiChat. الشحن والهدايا والتحويلات غير مفعّلة بعد.';
 const small=$('small',hero);
 if(small)small.textContent=error?'فشل الاتصال بخادم المحفظة':wallet?'الرصيد الحقيقي':'جارٍ تحميل الرصيد الحقيقي…';
 const coin=$('h2',hero);if(coin)coin.textContent=(wallet?format(wallet.coins):'—')+' 🪙';
 const diamond=$('p',hero);if(diamond)diamond.textContent=(wallet?format(wallet.diamonds):'—')+' ماسة 💎';
 // The old static wallet panel/tabs render demo data. Replace only their
 // contents with a server-backed ledger, preserving the hero and royal layout.
 $$('.visual-tab,.cardwhite,.empty',container).forEach(n=>n.remove());
 let card=$('#tc-live-wallet-records',container);
 if(!card){
  card=document.createElement('section');
  card.id='tc-live-wallet-records';card.className='cardwhite tc-live-wallet-records';
  container.appendChild(card);
 }
 card.replaceChildren();
 const heading=document.createElement('h3');heading.textContent='📄 سجل معاملات المحفظة الحقيقية';card.appendChild(heading);
 if(error){
  const p=document.createElement('p');p.setAttribute('role','alert');
  p.textContent='تعذّر جلب المحفظة من الخادم: '+error.slice(0,100);card.appendChild(p);
 }else if(!wallet){
  const p=document.createElement('p');p.textContent='جارٍ قراءة المحفظة من قاعدة البيانات…';card.appendChild(p);
 }else if(!ledger?.length){
  const p=document.createElement('p');p.textContent='لا توجد معاملات حقيقية مسجّلة لهذا الحساب.';
  card.appendChild(p);
 }else{
  for(const row of ledger){
   const item=document.createElement('div');item.className='tc-wallet-journal-line';
   const label=document.createElement('b');label.textContent=String(row.kind||'عملية');
   const number=document.createElement('span');
   number.textContent=(row.amount_change>0?'+':'')+String(row.amount_change)+
    (row.currency==='diamonds'?' 💎':' 🪙');
   item.append(label,number);card.appendChild(item);
  }
 }
 const info=document.createElement('p');
 info.className='tc-wallet-read-only';
 info.textContent='لا يمكن للواجهة تعديل العملات أو الماس. عمليات الشحن عبر الوكلاء ستُفعّل فقط بعد اكتمال نظام الخزينة والصلاحيات.';
 card.appendChild(info);
 const refresh=document.createElement('button');
 refresh.type='button';refresh.className='primary';refresh.dataset.liveWallet='refresh';
 refresh.textContent=busy?'جارٍ التحديث…':'تحديث الرصيد من الخادم';
 refresh.disabled=busy;card.appendChild(refresh);
}
async function load(){
 const user=auth.state().user;
 if(!user||busy)return;
 const current=user.id;
 owner=current;busy=true;error='';wallet=null;ledger=null;paint();
 try{
  const id=encodeURIComponent(current);
  const [w,j]=await Promise.all([
   auth.requestData('/rest/v1/wallets?user_id=eq.'+id+
    '&select=user_id,coins,diamonds,updated_at&limit=1'),
   auth.requestData('/rest/v1/wallet_ledger?user_id=eq.'+id+
    '&select=id,currency,amount_change,kind,created_at&order=created_at.desc&limit=50')
  ]);
  if(auth.state().user?.id!==current)return;
  if(!Array.isArray(w)||w.length!==1||w[0].user_id!==current)
    throw new Error('لم يعثر الخادم على محفظة الحساب');
  wallet=w[0];ledger=Array.isArray(j)?j:[];error='';
 }catch(e){if(auth.state().user?.id===current){
    wallet=null;ledger=null;error=String(e?.message||'فشل الاتصال');}}
 finally{busy=false;paint();}
}
const original=render;
render=function(){
 const result=original.apply(this,arguments);
 if(screen==='wallet'&&auth.state().signedIn){
  const current=auth.state().user?.id;
  if(current!==owner){owner=current;wallet=null;ledger=null;error='';void load();}
  paint();
 }
 return result;
};
window.addEventListener('totichat-phase2-auth',()=>{
 if(!auth.state().signedIn){owner='';wallet=null;ledger=null;error='';busy=false;}
 else if(owner!==auth.state().user?.id){void load();}
});
window.addEventListener('click',e=>{
 const item=e.target?.closest?.('[data-live-wallet]');
 if(!item||item.dataset.liveWallet!=='refresh')return;
 e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
 void load();
},true);
window.TotiPhase2Wallet=Object.freeze({status,refresh:load});
})();
