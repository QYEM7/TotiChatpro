/* Receipts and effects originate only from committed, participant-visible gifts. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
const sound=new Audio(new URL('../assets/audio/gift-chime.wav',document.baseURI).href);sound.preload='auto';
let enabled=false,generation=0,cursor=null,timer=null,polling=null,historyBusy=null;
const owner=()=>auth.state().user?.id;
function status(text){const node=document.querySelector('[data-gift-history-status]');if(node)node.textContent=text;}
async function play(){if(!enabled)return;try{sound.currentTime=0;await sound.play();}catch{enabled=false;status('اضغط تفعيل صوت الهدايا للسماح بالتشغيل');}}
function animate(gift){
 const node=document.createElement('div');node.className='gift-animation';node.setAttribute('role','status');node.textContent=gift?.icon||'🎁';node.setAttribute('aria-label',gift?.name||'هدية مستلمة');Object.assign(node.style,{position:'fixed',inset:'30% 0 auto',textAlign:'center',fontSize:'96px',zIndex:'99999',pointerEvents:'none'});document.body.appendChild(node);setTimeout(()=>node.remove(),1700);
}
async function history(){
 if(historyBusy===generation)return;const version=generation,user=owner();historyBusy=version;status('جارٍ تحميل سجل الهدايا…');
 try{const rows=await auth.requestData('/rest/v1/gift_events?select=id,sender_id,recipient_id,quantity,amount,created_at,gift_catalog(name,icon)&order=created_at.desc,id.desc&limit=50');if(version!==generation||owner()!==user)return;
  const node=document.querySelector('[data-gift-history-rows]');if(!node)return;node.replaceChildren();
  for(const row of rows){const p=document.createElement('p');p.textContent=(row.sender_id===user?'أرسلت':'استلمت')+' '+(row.gift_catalog?.name||'هدية')+' × '+row.quantity+' · '+row.amount+' · '+row.created_at;node.appendChild(p);}status(rows.length?'آخر '+rows.length+' هدية مسجّلة':'لا توجد هدايا مرسلة أو مستلمة.');
 }catch(e){if(version===generation&&owner()===user)status(e.message+'؛ اضغط تحديث لإعادة المحاولة');}finally{if(historyBusy===version)historyBusy=null;}
}
async function poll(version,user){
 if(polling===version||version!==generation||!user||owner()!==user)return;polling=version;
 try{
  const prefix='/rest/v1/gift_events?select=id,room_id,created_at,gift_catalog(name,icon)&recipient_id=eq.'+encodeURIComponent(user);
  if(!cursor){const rows=await auth.requestData(prefix+'&order=created_at.desc,id.desc&limit=1');if(version!==generation||owner()!==user)return;cursor=rows[0]?{time:rows[0].created_at,id:rows[0].id}:{time:'1970-01-01T00:00:00Z',id:'00000000-0000-0000-0000-000000000000'};}
  else{
   const filter='(created_at.gt.'+cursor.time+',and(created_at.eq.'+cursor.time+',id.gt.'+cursor.id+'))';
   const rows=await auth.requestData(prefix+'&or='+encodeURIComponent(filter)+'&order=created_at.asc,id.asc&limit=100');if(version!==generation||owner()!==user)return;
   for(const row of rows){cursor={time:row.created_at,id:row.id};window.dispatchEvent(new CustomEvent('totichat-gift-received',{detail:row}));if(window.TotiPhase2Rooms?.getRoomSummary?.()?.id===row.room_id){animate(row.gift_catalog);void play();}showToast('استلمت '+(row.gift_catalog?.name||'هدية'));}
   if(rows.length){void window.TotiPhase2Wallet?.refresh?.();if(screen==='wallet')void history();}
  }
 }catch(e){if(version===generation&&owner()===user)status('تعذر تحديث إشعارات الهدايا؛ ستتم إعادة المحاولة');}
 finally{if(polling===version)polling=null;if(version===generation&&owner()===user)timer=setTimeout(()=>void poll(version,user),5000);}
}
function hydrate(){
 if(screen!=='wallet'||!auth.state().signedIn)return;
 const parent=document.querySelector('#app .visual-hero')?.parentElement;if(!parent||parent.querySelector('[data-gift-history-panel]'))return;
 const node=document.createElement('section');node.className='tc-wallet-transfer';node.dataset.giftHistoryPanel='';node.innerHTML='<h3>الهدايا المرسلة والمستلمة</h3><button class="primary" data-gift-receipt-action="audio">تفعيل صوت الهدايا</button><button class="primary" data-gift-receipt-action="refresh">تحديث السجل</button><p role="status" data-gift-history-status></p><div data-gift-history-rows></div>';parent.appendChild(node);void history();
}
window.addEventListener('click',e=>{
 const b=e.target.closest('[data-gift-receipt-action]');if(!b)return;e.preventDefault();e.stopImmediatePropagation();
 if(b.dataset.giftReceiptAction==='refresh'){void history();return;}
 enabled=!enabled;if(enabled){sound.currentTime=0;void sound.play().then(()=>{if(enabled)b.textContent='إيقاف صوت الهدايا';}).catch(()=>{enabled=false;b.textContent='تفعيل صوت الهدايا';status('المتصفح منع الصوت؛ اضغط مجدداً للسماح');});}else{sound.pause();b.textContent='تفعيل صوت الهدايا';}
},true);
window.addEventListener('totichat-gift-completed',()=>{void play();if(screen==='wallet')void history();});
const renderBefore=render;render=function(){const result=renderBefore.apply(this,arguments);hydrate();return result;};
window.addEventListener('totichat-phase2-auth',()=>{generation++;clearTimeout(timer);cursor=null;enabled=false;sound.pause();document.querySelector('[data-gift-history-panel]')?.remove();hydrate();if(auth.state().signedIn)void poll(generation,owner());});
if(auth.state().signedIn)void poll(generation,owner());
})();
