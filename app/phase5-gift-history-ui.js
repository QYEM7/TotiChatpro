/* Authenticated personal gift receipts from actual ledger-backed events only.
 * Never claims the gift cost is payroll, a wallet balance or lucky prize.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=selector=>document.querySelector(selector);
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
const validUUID=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
let owner='',epoch=0,loadedAt=0,summary=null,loadingSummary=false;
let view='received',entries=[],cursorAt=null,cursorId=null,more=false,loadingPage=false,requestSeq=0;
const dirs=Object.freeze({received:'المستلمة',sent:'المرسلة'});
const txt=(tag,str,klass)=>{
 const n=document.createElement(tag);n.textContent=String(str??'');
 if(klass)n.className=klass;return n;
};
function signed(){return auth.state().signedIn===true&&auth.state().user?.id===owner}
function sheet(){return $('#tc-real-gift-history')&&$('#overlay')?.classList.contains('show')}
function resetIfDifferent(){
 const id=auth.state().user?.id||'';
 if(owner===id)return;
 if(sheet()&&typeof closeSheet==='function')closeSheet();
 owner=id;epoch++;requestSeq++;summary=null;loadedAt=0;loadingSummary=false;
 entries=[];cursorAt=null;cursorId=null;more=false;loadingPage=false;
}
const num=s=>{
 if(!/^(?:0|[1-9][0-9]{0,29})$/.test(String(s||'')))return '—';
 try{return BigInt(s).toLocaleString('ar-IQ')}catch(_){return '—'}
};
function paintSummary(){
 if(!signed())return;
 const line=summary&&summary.userId===owner&&
  Number.isSafeInteger(summary.receivedCount)&&summary.receivedCount>=0
  ?'🎁 هدايا مستلمة: '+num(String(summary.receivedCount)):'🎁 الهدايا · جارٍ التحقق';
 if(screen==='profilePreview'){
  const banner=$('.pr-event span');if(banner)banner.textContent=line;
 }
}
async function loadSummary(force=false){
 if(!signed()||loadingSummary||(!force&&loadedAt&&Date.now()-loadedAt<30000))return;
 const id=owner,stamp=epoch;
 loadingSummary=true;
 try{
  const result=await rpc('phase5_gift_summary',{});
  if(stamp!==epoch||!signed()||id!==owner)return;
  if(!result||result.userId!==id||
   !Number.isSafeInteger(result.sentCount)||result.sentCount<0||
   !Number.isSafeInteger(result.receivedCount)||result.receivedCount<0||
   !['sentGiftCoins','receivedGiftCoins','receivedGiftDiamonds'].every(k=>
    /^(0|[1-9][0-9]{0,29})$/.test(result[k]))||result.isSalaryReport!==false)
    throw Error('Invalid account gift totals');
  summary=result;loadedAt=Date.now();
  paintSummary();paintPageHeader();
 }catch(_){
  if(stamp===epoch&&signed()){summary=null;loadedAt=Date.now();paintSummary();paintPageHeader()}
 }finally{if(stamp===epoch)loadingSummary=false}
}
function button(){
 if(!signed()||screen!=='me')return;
 const panel=$('#app .me-more');
 if(!panel||panel.querySelector('[data-tc-gift-history]'))return;
 const b=document.createElement('button');b.type='button';b.dataset.tcGiftHistory='';
 b.setAttribute('aria-label','تاريخ الهدايا الحقيقي');
 for(const [name,value] of [['more-icon','🎁'],['','تاريخ هداياي الحقيقي'],['chev','‹']]){
  const node=txt('span',value,name);b.append(node);
 }
 panel.append(b);
}
function pageStatus(value){
 const p=$('#tc-gift-history-status');if(p)p.textContent=String(value||'').slice(0,175);
}
function paintPageHeader(){
 if(!sheet())return;
 const header=$('#tc-gift-history-totals');
 if(!header)return;
 header.replaceChildren();
 if(!summary){
  header.append(txt('p','الإجمالي غير متاح حالياً.'));return;
 }
 const count=view==='received'?summary.receivedCount:summary.sentCount;
 const coins=view==='received'?summary.receivedGiftCoins:summary.sentGiftCoins;
 header.append(txt('p',num(String(count))+' عملية حقيقية · قيمة الهدايا '+num(coins)+' كوينز'));
 if(view==='received')
  header.append(txt('small','ماس تم إصداره من الهدايا: '+num(summary.receivedGiftDiamonds)+
   ' · هذا ليس رصيدك الحالي ولا مستحقات راتبك.'));
}
function paintItems(){
 if(!signed()||!sheet())return;
 const list=$('#tc-gift-history-rows');if(!list)return;
 list.replaceChildren();
 for(const item of entries){
  if(!validUUID(item.id)||!validUUID(item.counterparty_id))continue;
  const card=document.createElement('article');card.className='tc-gift-receipt';
  const name=txt('strong',(item.gift_icon||'🎁')+' '+String(item.gift_name||'هدية موثقة'));
  const person=txt('span',(view==='received'?'المرسل: ':'المستلم: ')+
    (item.counterparty_name||item.counterparty_id.slice(0,8).toUpperCase()));
  const value=txt('span','×'+item.quantity+' · '+num(item.gift_coins)+' كوينز');
  const date=txt('small',String(item.created_at||'').slice(0,19).replace('T',' ')+' UTC');
  card.append(name,person,value,date);
  if(view==='received'&&item.delivered_diamonds!==null){
   card.append(txt('small','الماس الصادر من هذه الهدية: '+num(item.delivered_diamonds)));
  }
  list.append(card);
 }
 if(entries.length===0&&!loadingPage)
  list.append(txt('p','لا توجد هدايا حقيقية ضمن السجل الحالي.','tc-gift-history-empty'));
 const moreButton=$('#tc-gift-history-more');
 if(moreButton)moreButton.hidden=!more;
}
async function fetchPage(reset=false){
 if(!signed()||!sheet()||loadingPage)return;
 loadingPage=true;
 const gen=epoch,seq=++requestSeq,id=owner,direction=view;
 const beforeAt=reset?null:cursorAt,beforeId=reset?null:cursorId;
 pageStatus('جارٍ قراءة الإيصالات من خادم TotiChat…');
 try{
  const result=await rpc('phase5_gift_history',{
   p_direction:direction,p_limit:25,p_before_at:beforeAt,p_before_id:beforeId
  });
  if(gen!==epoch||seq!==requestSeq||!signed()||!sheet()||view!==direction||id!==owner)return;
  if(!result||result.direction!==direction||!Array.isArray(result.items)||
   result.items.length>25||
   result.items.some(item=>!validUUID(item.id)||!validUUID(item.counterparty_id)||
    !/^(0|[1-9][0-9]{0,29})$/.test(item.gift_coins)||
    !Number.isInteger(item.quantity)||item.quantity<1||
    !['sent','received'].includes(item.direction)))
   throw Error('Invalid gift receipt response');
  entries=reset?result.items:entries.concat(
   result.items.filter(x=>!entries.some(y=>y.id===x.id)));
  cursorAt=result.nextAt||null;cursorId=result.nextId||null;
  more=Boolean(cursorAt&&validUUID(cursorId));
  pageStatus('');
 }catch(e){
  if(gen===epoch&&signed()&&sheet())
   pageStatus('تعذر عرض الإيصالات: '+String(e.message).slice(0,105));
 }finally{
  if(gen===epoch){loadingPage=false;paintItems()}
 }
}
function open(){
 if(!signed()||typeof showSheet!=='function')return;
 view='received';entries=[];more=false;cursorAt=null;cursorId=null;requestSeq++;
 showSheet('<section id="tc-real-gift-history" class="tc-real-gift-history" dir="rtl">'+
 '<header><h3>🎁 سجل الهدايا الحقيقي</h3><button type="button" data-a="close" aria-label="إغلاق">✕</button></header>'+
 '<p>الإيصالات من الهدايا المنفذة فعلياً. لا يعرض رواتب أو جوائز تخمينية.</p>'+
 '<div class="tc-gift-history-tabs"><button type="button" data-tc-gift-tab="received">المستلمة</button>'+
 '<button type="button" data-tc-gift-tab="sent">المرسلة</button></div>'+
 '<div id="tc-gift-history-totals"></div><p id="tc-gift-history-status" aria-live="polite"></p>'+
 '<div id="tc-gift-history-rows"></div><button data-tc-gift-more id="tc-gift-history-more" hidden type="button">المزيد من الإيصالات</button>'+
 '</section>',true);
 paintPageHeader();void loadSummary();void fetchPage(true);
}
function mount(){
 resetIfDifferent();
 if(!signed())return;
 if(screen==='me')button();
 if(screen==='profilePreview'){paintSummary();void loadSummary()}
}
const previous=window.render;
window.render=function(){const v=previous.apply(this,arguments);mount();return v};
document.addEventListener('click',e=>{
 const b=e.target?.closest?.('[data-tc-gift-history],[data-tc-gift-tab],[data-tc-gift-more]');
 if(!b)return;
 e.preventDefault();e.stopImmediatePropagation();
 if(b.hasAttribute('data-tc-gift-history')){open();return}
 if(!sheet()||!signed())return;
 if(b.hasAttribute('data-tc-gift-tab')){
  const next=b.dataset.tcGiftTab;
  if(!Object.hasOwn(dirs,next))return;
  view=next;entries=[];cursorAt=null;cursorId=null;more=false;requestSeq++;
  paintPageHeader();paintItems();void fetchPage(true);
 }else if(b.hasAttribute('data-tc-gift-more'))void fetchPage();
},true);
window.addEventListener('totichat-phase2-auth',()=>{resetIfDifferent();if(signed())mount()});
window.addEventListener('focus',()=>{if(signed())void loadSummary(true)});
window.TotiGiftHistory=Object.freeze({open,refresh:()=>loadSummary(true),isInstalled:()=>true});
queueMicrotask(mount);
})();
