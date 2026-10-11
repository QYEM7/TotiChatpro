/* Real worldwide gift announcements, never random animations or simulated sends.
 * The database emits one event only after verified sender debit and receiver credit. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
let account='',generation=0,rows=[],initialized=false,busy=false,stream=null;
const seen=new Set();
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const valid=row=>row&&uuid.test(row.id)&&uuid.test(row.room_id)&&
 Number.isSafeInteger(Number(row.total_coins))&&Number(row.total_coins)>0;
function title(row){
 return '🎁 '+String(row.sender_name||'مستخدم').slice(0,55)+' أرسل '+String(row.gift_name||'هدية').slice(0,60)+
 ' × '+Number(row.quantity)+' إلى '+String(row.recipient_name||'مستخدم').slice(0,55);
}
function decorateTicker(view){
 const node=view?.querySelector?.('.giftTicker .tickerBody');
 const count=view?.querySelector?.('.giftTicker .orb b');
 const current=rows[0];
 if(node)node.textContent=current?title(current):'🎁 لا توجد إعلانات هدايا مؤكدة حالياً';
 if(count)count.textContent=current?String(current.quantity):'0';
}
function refreshTicker(){
 if(screen!=='room')return;
 decorateTicker($('.roomview.room-v2'));
}
function celebrate(row){
 if(screen!=='room'||!document.body||!valid(row))return;
 const card=document.createElement('div');
 card.className='tc-gift-global-live';
 card.setAttribute('role','status');
 card.setAttribute('aria-live','polite');
 const icon=document.createElement('span');icon.className='tc-gift-global-art';
 icon.textContent=String(row.gift_icon||'🎁').slice(0,4);
 const text=document.createElement('b');text.textContent=title(row);
 const amount=document.createElement('small');amount.textContent=Number(row.total_coins).toLocaleString('en-US')+' كوينز — عملية مؤكدة';
 card.append(icon,text,amount);document.body.appendChild(card);
 card.animate([{opacity:0,transform:'translate(-50%,15px) scale(.8)'},{opacity:1,transform:'translate(-50%,0) scale(1)'},{opacity:1},{opacity:0,transform:'translate(-50%,-25px)'}],{duration:4200,easing:'ease-out'});
 setTimeout(()=>card.remove(),4300);
}
async function refresh(){
 const user=auth.state().user?.id||'';
 if(!user||busy||document.hidden)return;
 busy=true;const stamp=generation;
 try{
  const data=await auth.requestData('/rest/v1/gift_global_announcements?select=id,room_id,sender_id,recipient_id,gift_id,gift_name,gift_icon,sender_name,recipient_name,quantity,unit_price,total_coins,created_at&order=created_at.desc&limit=12');
  if(stamp!==generation||user!==auth.state().user?.id||!Array.isArray(data))return;
  const confirmed=data.filter(valid);
  if(!initialized){
   for(const row of confirmed)seen.add(row.id);
   initialized=true;
  }else{
   // Animate only newly verified events that were not seen on this account.
   for(const row of confirmed.slice().reverse()){
    if(!seen.has(row.id)){seen.add(row.id);celebrate(row);}
   }
  }
  rows=confirmed;
  if(seen.size>500){const recent=new Set(confirmed.map(r=>r.id));seen.clear();for(const id of recent)seen.add(id);}
  refreshTicker();
 }catch(error){console.warn('TotiChat global gift feed:',String(error.message||'network failure').slice(0,120));}
 finally{busy=false;}
}
function start(){
 const user=auth.state().user?.id||'';
 if(user===account)return;
 generation++;account=user;rows=[];seen.clear();initialized=false;
 stream?.close?.();stream=null;refreshTicker();
 if(user){
  void refresh();
  stream=auth.watchSocialUpdates?.(table=>{
   if(account!==auth.state().user?.id)return;
   if(table==='gift_global_announcements')void refresh();
   if(table==='direct_messages')window.dispatchEvent(new CustomEvent('totichat-private-message-update'));
  })||null;
 }
}
window.addEventListener('totichat-phase2-auth',start);
window.addEventListener('totichat-gift-completed',()=>{if(account)void refresh();});
window.addEventListener('online',()=>{if(account)void refresh();});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&account)void refresh();});
setInterval(()=>{if(account&&!document.hidden)void refresh();},8500);
window.TotiGlobalGiftFeed=Object.freeze({refresh,decorateTicker,getLatest:()=>rows[0]?Object.freeze({...rows[0]}):null});
start();
})();
