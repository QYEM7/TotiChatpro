/* Keep approved page/card/tab styles. Replace catalog CONTENT in live mode.
 * Selecting an item never sends a gift, charges coins or grants an entitlement.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth,data=window.TotiPhase2Catalogs;
if(!auth||!data||!window.TotiLiveMode?.enabled)return;
const live=()=>auth.state().signedIn;
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num=x=>Number.isSafeInteger(Number(x))?Number(x).toLocaleString('en-US'):String(x);
const categories={frames:'الإطارات',cars:'المركبات',bubbles:'الفقاعات',badges:'الأوسمة',vip:'VIP',entrances:'الدخول',cards:'CP'};
let storeFilter='',giftCategory='',giftId='',recipientId='',viewVersion=0,giftBusy=false,pendingGift=null;
function shell(title,type){
 return page(title,'<section class="visual-dark" data-live-catalog="'+type+'"><p class="visual-warn">الخيارات والأسعار من قاعدة TotiChat الجديدة. الاختيار لا يخصم رصيداً؛ الشراء والإرسال يتطلبان تأكيدك وتأكيد الخادم.</p><div class="tc-catalog-content" role="status">جارٍ جلب الخيارات من الخادم…</div></section>');
}
const prevStore=vStore,prevRecharge=vRecharge,prevCP=cp,prevGifts=showGifts;
vStore=function(){return live()?shell('متجر TotiChat','store'):prevStore.apply(this,arguments);};
vRecharge=function(){return live()?shell('باقات الشحن عبر الوكلاء','recharge'):prevRecharge.apply(this,arguments);};
cp=function(){return live()?shell('رفقاء الروح · CP','cp'):prevCP.apply(this,arguments);};
showGifts=function(){
 if(!live())return prevGifts.apply(this,arguments);
 giftId='';recipientId='';
 showSheet(head('صندوق الهدايا')+'<section data-live-catalog="gift"><p class="vip-noteonly">إرسال الهدايا يخصم السعر الحقيقي ويضيف الماس للمستلم بعد تأكيد الخادم.</p><div class="tc-catalog-content" role="status">جارٍ تحميل الهدايا…</div></section>');
 void paint();
};
function button(label,action,value,selected=false){
 return '<button type="button" data-catalog-action="'+action+'" data-catalog-value="'+esc(value)+'"'+(selected?' class="'+(action==='recipient'?'selected':'active')+'"':'')+'>'+esc(label)+'</button>';
}
function itemDetails(item){
 showSheet(head(item.name)+'<div class="cardwhite"><p>'+esc(item.description||'لا يوجد وصف إضافي')+'</p><p>'+esc(num(item.price))+' '+esc(item.currency==='silver'?'عملة فضية':item.currency==='gold'?'عملة ذهبية':'عملة')+'</p>'+
 (item.duration_days?'<p>المدة: '+esc(item.duration_days)+' يوم</p>':'')+
 (item.is_reward?'<p>عنصر مكافأة؛ ليس للبيع.</p>':'')+
 (item.is_reward||item.relationship_type_id?'':'<button type="button" class="primary" data-catalog-action="store-buy" data-catalog-value="'+esc(item.id)+'">شراء</button>')+'<div data-store-ownership data-item="'+esc(item.id)+'"></div><button type="button" class="primary" data-a="close">إغلاق</button></div>',true);
 const owner=auth.state().user?.id;
 if(owner)void auth.requestData('/rest/v1/store_ownership?user_id=eq.'+encodeURIComponent(owner)+'&item_id=eq.'+encodeURIComponent(item.id)+'&select=item_id,equipped,expires_at&limit=1').then(rows=>{
  if(auth.state().user?.id!==owner)return;
  const node=document.querySelector('[data-store-ownership]');if(!node||node.dataset.item!==item.id||!Array.isArray(rows)||!rows.length)return;
  const row=rows[0];if(row.expires_at&&Date.parse(row.expires_at)<=Date.now()){node.textContent='انتهت ملكية العنصر';return;}
  node.innerHTML='<p>العنصر في مخزونك'+(row.expires_at?' حتى '+esc(new Date(row.expires_at).toLocaleDateString('ar-IQ')):'')+'</p><button type="button" class="primary" data-catalog-action="store-equip" data-catalog-value="'+esc(item.id)+'" data-equipped="'+String(!row.equipped)+'">'+(row.equipped?'إلغاء التجهيز':'تجهيز')+'</button>';
 }).catch(()=>{const node=document.querySelector('[data-store-ownership]');if(node)node.textContent='تعذر تحميل الملكية؛ أعد فتح التفاصيل للمحاولة.';});

}
let visibleStore=[],storeBusy=false,pendingPurchase=null;
async function purchaseStore(target,item){
 if(storeBusy)return;
 const owner=auth.state().user?.id;if(!owner||!item)return;
 const signature=owner+':'+item.id;
 if(!pendingPurchase||pendingPurchase.signature!==signature){
  if(!confirm('شراء '+item.name+' مقابل '+num(item.price)+' '+(item.currency==='gold'?'عملة ذهبية':'عملة فضية')+'؟'))return;
  pendingPurchase={signature,requestId:crypto.randomUUID()};
 }
 storeBusy=true;target.disabled=true;target.textContent='جارٍ الشراء…';
 try{
  const result=await auth.requestData('/rest/v1/rpc/phase3_purchase_store',{method:'POST',body:{p_item_id:item.id,p_request_id:pendingPurchase.requestId,p_expected_price:item.price,p_expected_currency:item.currency}});
  if(auth.state().user?.id!==owner)return;
  if(result?.status!=='completed')throw Error('لم يؤكد الخادم الشراء');
  pendingPurchase=null;showToast('تم شراء '+item.name);void window.TotiPhase2Wallet?.refresh?.();itemDetails(item);
 }catch(e){if(auth.state().user?.id===owner)showToast(String(e.message).slice(0,150));}
 finally{storeBusy=false;if(target.isConnected){target.disabled=false;target.textContent='شراء';}}
}

async function paint(){
 const root=document.querySelector('#sheet [data-live-catalog]')||document.querySelector('#app [data-live-catalog]');
 if(!root||!live())return;
 const version=++viewVersion,owner=auth.state().user.id,type=root.dataset.liveCatalog;
 const content=root.querySelector('.tc-catalog-content');
 try{
  let markup='';
  if(type==='store'){
   const rows=await data.list('store_catalog');
   const available=Object.keys(categories).filter(c=>rows.some(r=>r.category===c));
   const search=root.querySelector('[data-catalog-search]')?.value||'';
   const filtered=rows.filter(r=>(!storeFilter||r.category===storeFilter)&&r.name.toLowerCase().includes(search.toLowerCase()));
   visibleStore=rows;
   markup='<input class="search" data-catalog-search placeholder="ابحث في المتجر" value="'+esc(search)+'"><div class="visual-tab">'+button('الكل','store-filter','',!storeFilter)+available.map(c=>button(categories[c],'store-filter',c,storeFilter===c)).join('')+'</div><div class="visual-inventory">'+filtered.map(r=>'<button type="button" data-catalog-action="store-item" data-catalog-value="'+esc(r.id)+'"><span>'+esc(r.icon)+'</span>'+esc(r.name)+'<br><small>'+esc(r.is_reward?'مكافأة':num(r.price)+' '+(r.currency==='gold'?'🪙 ذهب':'فضة'))+'</small></button>').join('')+'</div>';
   if(!filtered.length)markup+='<p>لا توجد عناصر مطابقة.</p>';
  }else if(type==='recharge'){
   const [packs,tiers]=await Promise.all([data.list('recharge_packages'),data.list('recharge_reward_tiers')]);
   markup='<div class="visual-product-grid">'+packs.map(r=>'<button type="button" class="visual-product" data-catalog-action="package" data-catalog-value="'+esc(r.id)+'"><b>'+esc(num(r.gold_amount))+' 🪙</b><small>$'+esc(r.price_usd)+'</small></button>').join('')+'</div><h3>مستويات مكافآت الشحن</h3>'+tiers.map(r=>'<details class="cardwhite"><summary>'+esc(r.label)+' · $'+esc(r.threshold_usd)+'</summary><ul>'+r.rewards.map(reward=>'<li>'+esc(typeof reward==='string'?reward:reward.name||reward.label||reward.type||JSON.stringify(reward))+'</li>').join('')+'</ul></details>').join('');
   if(!packs.length)markup+='<p>لا توجد باقات شحن منشورة.</p>';
  }else if(type==='cp'){
   const state=await auth.requestData('/rest/v1/rpc/phase4_cp_state',{method:'POST',body:{}}),rows=state.types;
   if(!Array.isArray(rows)||!Array.isArray(state.relations))throw Error('تعذر التحقق من بيانات العلاقات');
   markup=rows.map(r=>'<div class="cardwhite"><h3>'+esc(r.presentation?.icon||'💗')+' '+esc(r.label)+'</h3></div>').join('')||'<p>لا توجد أنواع علاقات مفعّلة.</p>';
   if(rows.length)markup+='<form data-cp-search><label>ابحث عن الشريك<input name="query" maxlength="40" required></label><button class="primary">بحث</button></form><form data-cp-request><label>نوع العلاقة<select name="type">'+rows.map(r=>'<option value="'+esc(r.id)+'">'+esc(r.label)+'</option>').join('')+'</select></label><label>الشريك<select name="partner" required><option value="">ابحث عن شريك أولاً</option></select></label><button class="primary">إرسال طلب علاقة</button></form>';
   markup+='<p data-cp-status role="status"></p><h3>علاقاتي وطلباتي</h3>'+state.relations.map(r=>'<article class="cardwhite"><b>'+esc(r.partner.display_name)+' · '+esc(r.type_label)+'</b><p>'+(r.accepted_at?'علاقة مؤكدة · المستوى '+esc(r.level)+' · هدايا بقيمة '+esc(num(r.gift_gold)):'بانتظار قبول '+esc(r.requested_by===owner?r.partner.display_name:'طلبك'))+'</p>'+
    (!r.accepted_at&&r.requested_by!==owner?'<button class="primary" data-cp-action="accept" data-partner="'+esc(r.partner.id)+'" data-type="'+esc(r.type_id)+'">قبول</button><button class="primary" data-cp-action="reject" data-partner="'+esc(r.partner.id)+'" data-type="'+esc(r.type_id)+'">رفض</button>':'<button class="primary" data-cp-action="end" data-partner="'+esc(r.partner.id)+'" data-type="'+esc(r.type_id)+'">'+(r.accepted_at?'إنهاء العلاقة':'إلغاء الطلب')+'</button>')+'</article>').join('')+(!state.relations.length?'<p>لا توجد علاقات أو طلبات.</p>':'')+button('تحديث العلاقات','retry','');
  }else if(type==='gift'){
   const [cats,gifts]=await Promise.all([data.list('gift_categories'),data.list('gift_catalog')]);
   if(!cats.some(c=>c.id===giftCategory))giftCategory=cats.find(c=>c.id==='gift')?.id||cats.find(c=>gifts.some(g=>g.category_id===c.id))?.id||cats[0]?.id||'';
   const recipients=(window.TotiPhase2Rooms?.getMembers?.()||[]).filter(r=>r.user_id!==owner);
   if(!recipients.some(r=>r.user_id===recipientId))recipientId='';
   const rows=gifts.filter(g=>g.category_id===giftCategory);
   if(!rows.some(g=>g.id===giftId))giftId='';
   markup='<div class="recipient">'+recipients.map(r=>button(r.display_name||'مستخدم','recipient',r.user_id,recipientId===r.user_id)).join('')+'</div>'+
    (!recipients.length?'<p>لا يوجد أعضاء في غرفة حقيقية مفتوحة.</p>':'')+
    '<div class="giftTabs">'+cats.map(c=>button(c.label,'gift-category',c.id,giftCategory===c.id)).join('')+'</div>'+
    '<div class="giftgrid">'+rows.map(g=>'<button type="button" class="giftitem '+(giftId===g.id?'selected':'')+'" data-catalog-action="gift-item" data-catalog-value="'+esc(g.id)+'"><span class="gicon">'+esc(g.icon)+'</span><b>'+esc(g.name)+'</b><small>🪙 '+esc(num(g.price))+'</small></button>').join('')+'</div>'+
    (!rows.length?'<p>لا توجد هدايا منشورة في هذا التصنيف.</p>':'')+
    '<div class="sendrow"><span>'+esc(giftId&&recipientId?'تم تحديد المستلم والهدية':'حدد المستلم والهدية')+'</span><button type="button" class="primary" data-catalog-action="gift-send">إرسال هدية</button></div>';
  }
  if(version!==viewVersion||owner!==auth.state().user?.id||!root.isConnected)return;
  const focused=root.querySelector('[data-catalog-search]');
  const restore=focused&&document.activeElement===focused;
  const caret=focused?.selectionStart;
  content.innerHTML=markup;
  if(restore){const next=root.querySelector('[data-catalog-search]');next?.focus();if(next&&caret!==null)next.setSelectionRange(caret,caret);}
 }catch(error){
  if(version!==viewVersion||owner!==auth.state().user?.id||!root.isConnected)return;
  content.textContent='تعذر تحميل الخيارات: '+String(error.message||'خطأ اتصال').slice(0,120);
  const retry=document.createElement('button');retry.type='button';retry.className='primary';
  retry.dataset.catalogAction='retry';retry.textContent='إعادة المحاولة';content.appendChild(retry);
 }
}
async function sendGift(target){
 if(giftBusy)return;
 const room=window.TotiPhase2Rooms?.getRoomSummary?.(),owner=auth.state().user?.id;
 if(!room||!giftId||!recipientId){showToast('حدد الغرفة والمستلم والهدية');return;}
 const chosenGift=giftId,chosenRecipient=recipientId;
 let gifts;try{gifts=await data.list('gift_catalog');}catch(e){showToast(String(e.message));return;}
 if(giftBusy||auth.state().user?.id!==owner||room.id!==window.TotiPhase2Rooms?.getRoomSummary?.()?.id)return;
 const gift=gifts.find(g=>g.id===chosenGift);
 if(!gift){showToast('الهدية غير متاحة');return;}
 const payload={p_room_id:room.id,p_recipient_id:chosenRecipient,p_gift_id:chosenGift,p_quantity:1,p_expected_price:gift.price};
 const signature=JSON.stringify([owner,payload]);
 if(!pendingGift||pendingGift.signature!==signature){
  if(!confirm('إرسال '+gift.name+' مقابل '+num(gift.price)+' عملة؟'))return;
  pendingGift={signature,requestId:crypto.randomUUID()};
 }
 giftBusy=true;target.disabled=true;target.textContent='جارٍ إرسال الهدية…';
 try{
  const result=await auth.requestData('/rest/v1/rpc/phase3_send_gift',{method:'POST',body:{...payload,p_request_id:pendingGift.requestId}});
  if(auth.state().user?.id!==owner)return;
  if(result?.status!=='completed')throw Error('لم يؤكد الخادم إتمام المعاملة');
  pendingGift=null;showToast('تم إرسال '+gift.name);void window.TotiPhase2Wallet?.refresh?.();
  window.dispatchEvent(new CustomEvent('totichat-gift-completed',{detail:result}));
  const animation=document.createElement('div');animation.textContent=gift.icon||'🎁';
  animation.setAttribute('aria-label',gift.name);Object.assign(animation.style,{position:'fixed',inset:'30% 0 auto',textAlign:'center',fontSize:'96px',zIndex:'99999',pointerEvents:'none'});
  document.body.appendChild(animation);animation.animate([{transform:'scale(.3)',opacity:0},{transform:'scale(1)',opacity:1},{transform:'translateY(-100px)',opacity:0}],{duration:1600});setTimeout(()=>animation.remove(),1600);
 }catch(e){if(auth.state().user?.id===owner)showToast('تعذر إرسال الهدية: '+String(e.message).slice(0,120)+'؛ أعد المحاولة. إذا تغير السعر أعد فتح صندوق الهدايا.');}
 finally{giftBusy=false;if(target.isConnected){target.disabled=false;target.textContent='إرسال هدية';}}
}
const originalRender=render;
render=function(){const result=originalRender.apply(this,arguments);if(live())void paint();return result;};
window.addEventListener('click',event=>{
 const target=event.target?.closest?.('[data-catalog-action]');
 if(!target||!live())return;
 event.preventDefault();event.stopImmediatePropagation();
 const action=target.dataset.catalogAction,value=target.dataset.catalogValue;
 if(action==='store-filter')storeFilter=value;
 else if(action==='store-item'){const item=visibleStore.find(r=>r.id===value);if(item)itemDetails(item);return;}
 else if(action==='store-buy'){void purchaseStore(target,visibleStore.find(r=>r.id===value));return;}
 else if(action==='store-equip'){target.disabled=true;void auth.requestData('/rest/v1/rpc/phase3_equip_store',{method:'POST',body:{p_item_id:value,p_equipped:target.dataset.equipped==='true'}}).then(()=>{showToast('تم تحديث التجهيز');const item=visibleStore.find(r=>r.id===value);if(item)itemDetails(item);}).catch(e=>showToast(String(e.message))).finally(()=>{target.disabled=false;});return;}
 else if(action==='package'){showToast('الباقة من إعدادات الخادم. الشحن عبر الوكيل غير مفعّل بعد؛ لم يتغير رصيدك.');return;}
 else if(action==='gift-send'){void sendGift(target);return;}
 else if(action==='gift-category'){giftCategory=value;giftId='';}
 else if(action==='gift-item')giftId=value;
 else if(action==='recipient')recipientId=value;
 void paint();
},true);
document.addEventListener('input',event=>{if(event.target?.matches?.('[data-catalog-search]'))void paint();});
window.addEventListener('totichat-phase2-auth',()=>{if(!live()){viewVersion++;pendingGift=null;pendingPurchase=null;visibleStore=[];giftId='';recipientId='';storeFilter='';}else void paint();});
})();
