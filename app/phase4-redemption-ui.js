/* Tracked diamonds are exchanged using a server-confirmed quote and rate. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
let generation=0,busy=false,quote=null,pending=null;
const rpc=(name,body={})=>auth.requestData('/rest/v1/rpc/phase4_'+name,{method:'POST',body});
function status(text){const node=document.querySelector('[data-redemption-status]');if(node)node.textContent=text;}
async function refresh(){
 const version=++generation,owner=auth.state().user?.id;
 try{const state=await rpc('diamond_state');if(version!==generation||owner!==auth.state().user?.id)return;
  const node=document.querySelector('[data-redemption-sources]');if(!node)return;
  const f=x=>Number.isSafeInteger(Number(x))?Number(x).toLocaleString('en-US'):'—';
  node.textContent='ماس الهدايا الثابتة: '+f(state.fixed)+' · ماس الحظ: '+f(state.lucky)+(state.untracked?' · ماس غير قابل للاستبدال لغياب مصدره: '+f(state.untracked):'');
 }catch(e){if(version===generation)status(String(e.message).slice(0,160));}
}
function hydrate(){
 if(screen!=='wallet'||!auth.state().signedIn)return;
 const parent=document.querySelector('#app .visual-hero')?.parentElement;if(!parent||parent.querySelector('[data-redemption-panel]'))return;
 const panel=document.createElement('section');panel.className='tc-wallet-transfer';panel.dataset.redemptionPanel='';
 panel.innerHTML='<h3>استبدال الماس بعملات</h3><p data-redemption-sources>جارٍ تحميل مصادر الماس…</p><form data-redemption-preview><label>عدد الماسات<input type="number" name="diamonds" min="1" max="9007199254740991" step="1" required></label><button class="primary">عرض قيمة الاستبدال</button></form><div data-redemption-quote></div><p data-redemption-status role="status"></p><button class="primary" data-redemption-action="refresh">تحديث مصادر الماس</button>';
 parent.appendChild(panel);quote=null;void refresh();
}
async function run(button,task){if(busy)return;busy=true;button.disabled=true;const owner=auth.state().user?.id;status('جارٍ التنفيذ…');try{await task();}catch(e){if(owner===auth.state().user?.id)status(String(e.message).slice(0,160));}finally{busy=false;if(button.isConnected)button.disabled=false;}}
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-redemption-preview]'))return;
 event.preventDefault();event.stopImmediatePropagation();if(!form.reportValidity())return;
 const amount=Number(new FormData(form).get('diamonds')),owner=auth.state().user?.id;
 if(!Number.isSafeInteger(amount)||amount<=0){status('عدد الماسات غير صالح');return;}
 void run(form.querySelector('button'),async()=>{
  const result=await rpc('preview_redemption',{p_diamonds:amount});if(owner!==auth.state().user?.id)return;
  if(!Number.isSafeInteger(Number(result.coins))||Number(result.coins)<=0)throw Error('عرض الاستبدال غير صالح');
  quote=result;pending=null;
  const node=document.querySelector('[data-redemption-quote]');if(!node)return;node.replaceChildren();
  const text=document.createElement('p');text.textContent='استبدال '+result.diamonds+' ماسة مقابل '+result.coins+' عملة · النسبة '+(100*result.numerator/result.denominator)+'% (تقريب كل مصدر على حدة)';
  const button=document.createElement('button');button.className='primary';button.type='button';button.dataset.redemptionAction='confirm';button.textContent='تأكيد الاستبدال';node.append(text,button);status('راجع القيمة قبل التأكيد');
 });
},true);
window.addEventListener('click',event=>{
 const button=event.target.closest('[data-redemption-action]');if(!button)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(button.dataset.redemptionAction==='refresh'){void refresh();return;}
 if(!quote||busy)return;const confirmed={...quote},owner=auth.state().user?.id;
 void run(button,async()=>{
  const signature=JSON.stringify([owner,confirmed.diamonds,confirmed.coins]);
  if(!pending||pending.signature!==signature){if(!confirm('استبدال '+confirmed.diamonds+' ماسة مقابل '+confirmed.coins+' عملة؟'))return;pending={signature,key:crypto.randomUUID()};}
  const result=await rpc('redeem_diamonds',{p_diamonds:confirmed.diamonds,p_expected_coins:confirmed.coins,p_request_id:pending.key});
  if(owner!==auth.state().user?.id)return;
  if(result?.status!=='completed')throw Error('لم يؤكد الخادم إتمام الاستبدال');
  quote=null;pending=null;document.querySelector('[data-redemption-quote]')?.replaceChildren();status('تم الاستبدال · '+result.id);void refresh();void window.TotiPhase2Wallet?.refresh?.();
 });
},true);
window.addEventListener('input',event=>{if(event.target.matches('[data-redemption-preview] input')){quote=null;pending=null;document.querySelector('[data-redemption-quote]')?.replaceChildren();}});
const before=render;render=function(){const result=before.apply(this,arguments);hydrate();return result;};
window.addEventListener('totichat-phase2-auth',()=>{generation++;quote=null;pending=null;document.querySelector('[data-redemption-panel]')?.remove();hydrate();});
})();
