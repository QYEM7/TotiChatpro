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
let storeFilter='',giftCategory='',giftId='',recipientId='',viewVersion=0;
function shell(title,type){
 return page(title,'<section class="visual-dark" data-live-catalog="'+type+'"><p class="visual-warn">الخيارات والأسعار من قاعدة TotiChat الجديدة. التنفيذ المالي قيد الربط؛ الاختيار لا يخصم رصيداً.</p><div class="tc-catalog-content" role="status">جارٍ جلب الخيارات من الخادم…</div></section>');
}
const prevStore=vStore,prevRecharge=vRecharge,prevCP=cp,prevGifts=showGifts;
vStore=function(){return live()?shell('متجر TotiChat','store'):prevStore.apply(this,arguments);};
vRecharge=function(){return live()?shell('باقات الشحن عبر الوكلاء','recharge'):prevRecharge.apply(this,arguments);};
cp=function(){return live()?shell('رفقاء الروح · CP','cp'):prevCP.apply(this,arguments);};
showGifts=function(){
 if(!live())return prevGifts.apply(this,arguments);
 giftId='';recipientId='';
 showSheet(head('صندوق الهدايا')+'<section data-live-catalog="gift"><p class="vip-noteonly">كتالوج حقيقي. إرسال الهدايا غير مفعّل بعد.</p><div class="tc-catalog-content" role="status">جارٍ تحميل الهدايا…</div></section>');
 void paint();
};
function button(label,action,value,selected=false){
 return '<button type="button" data-catalog-action="'+action+'" data-catalog-value="'+esc(value)+'"'+(selected?' class="'+(action==='recipient'?'selected':'active')+'"':'')+'>'+esc(label)+'</button>';
}
function itemDetails(item){
 showSheet(head(item.name)+'<div class="cardwhite"><p>'+esc(item.description||'لا يوجد وصف إضافي')+'</p><p>'+esc(num(item.price))+' '+esc(item.currency==='silver'?'عملة فضية':item.currency==='gold'?'عملة ذهبية':'عملة')+'</p>'+
 (item.duration_days?'<p>المدة: '+esc(item.duration_days)+' يوم</p>':'')+
 (item.is_reward?'<p>عنصر مكافأة؛ ليس للبيع.</p>':'')+
 '<p>الشراء والتجهيز غير مفعّلين بعد. لن يُخصم رصيد.</p><button type="button" class="primary" data-a="close">إغلاق</button></div>',true);
}
let visibleStore=[];
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
   const rows=await data.list('cp_types');
   markup=rows.map(r=>'<div class="cardwhite"><h3>'+esc(r.presentation?.icon||'💗')+' '+esc(r.label)+'</h3><p>نوع علاقة متاح في الإعدادات. إنشاء العلاقة والمستويات قيد الربط.</p></div>').join('')||'<p>لا توجد أنواع علاقات مفعّلة.</p>';
  }else if(type==='gift'){
   const [cats,gifts]=await Promise.all([data.list('gift_categories'),data.list('gift_catalog')]);
   if(!cats.some(c=>c.id===giftCategory))giftCategory=cats.find(c=>c.id==='gift')?.id||cats.find(c=>gifts.some(g=>g.category_id===c.id))?.id||cats[0]?.id||'';
   const recipients=window.TotiPhase2Rooms?.getMembers?.()||[];
   if(!recipients.some(r=>r.user_id===recipientId))recipientId='';
   const rows=gifts.filter(g=>g.category_id===giftCategory);
   if(!rows.some(g=>g.id===giftId))giftId='';
   markup='<div class="recipient">'+recipients.map(r=>button(r.display_name||'مستخدم','recipient',r.user_id,recipientId===r.user_id)).join('')+'</div>'+
    (!recipients.length?'<p>لا يوجد أعضاء في غرفة حقيقية مفتوحة.</p>':'')+
    '<div class="giftTabs">'+cats.map(c=>button(c.label,'gift-category',c.id,giftCategory===c.id)).join('')+'</div>'+
    '<div class="giftgrid">'+rows.map(g=>'<button type="button" class="giftitem '+(giftId===g.id?'selected':'')+'" data-catalog-action="gift-item" data-catalog-value="'+esc(g.id)+'"><span class="gicon">'+esc(g.icon)+'</span><b>'+esc(g.name)+'</b><small>🪙 '+esc(num(g.price))+'</small></button>').join('')+'</div>'+
    (!rows.length?'<p>لا توجد هدايا منشورة في هذا التصنيف.</p>':'')+
    '<div class="sendrow"><span>'+esc(giftId&&recipientId?'تم تحديد المستلم والهدية':'حدد المستلم والهدية')+'</span><button type="button" class="primary" disabled>الإرسال قيد الربط</button></div>';
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
const originalRender=render;
render=function(){const result=originalRender.apply(this,arguments);if(live())void paint();return result;};
window.addEventListener('click',event=>{
 const target=event.target?.closest?.('[data-catalog-action]');
 if(!target||!live())return;
 event.preventDefault();event.stopImmediatePropagation();
 const action=target.dataset.catalogAction,value=target.dataset.catalogValue;
 if(action==='store-filter')storeFilter=value;
 else if(action==='store-item'){const item=visibleStore.find(r=>r.id===value);if(item)itemDetails(item);return;}
 else if(action==='package'){showToast('الباقة من إعدادات الخادم. الشحن عبر الوكيل غير مفعّل بعد؛ لم يتغير رصيدك.');return;}
 else if(action==='gift-category'){giftCategory=value;giftId='';}
 else if(action==='gift-item')giftId=value;
 else if(action==='recipient')recipientId=value;
 void paint();
},true);
document.addEventListener('input',event=>{if(event.target?.matches?.('[data-catalog-search]'))void paint();});
window.addEventListener('totichat-phase2-auth',()=>{if(!live()){viewVersion++;visibleStore=[];giftId='';recipientId='';storeFilter='';}else void paint();});
})();
