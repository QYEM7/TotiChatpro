/* Real TotiChat social: mutual follow becomes friend; verified identities only.
 * Extends approved Profile UI without changing its markup, frames or 15 seats.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!window.TotiLiveMode?.enabled||!auth)return;
const $=s=>document.querySelector(s);
const $$=s=>[...document.querySelectorAll(s)];
const validId=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
const types=Object.freeze({followers:'المتابعون',following:'المتابَعون',friends:'الأصدقاء'});
let owner='',generation=0,loadId=0,overview=null,openTab='friends',rows=[],cursor=null,more=false,busy=false;
const current=()=>auth.state().signedIn===true&&auth.state().user?.id===owner;
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
const text=(tag,s,cls)=>{
 const n=document.createElement(tag);n.textContent=String(s??'');if(cls)n.className=cls;return n;
};
function show(){return !!$('#tc-real-social')&&!!$('#overlay')?.classList.contains('show')}
function status(s){const n=$('#tc-social-status');if(n)n.textContent=String(s||'').slice(0,170)}
function syncOwner(){
 const id=auth.state().user?.id||'';
 if(id===owner)return;
 owner=id;generation++;loadId++;
 overview=null;openTab='friends';rows=[];cursor=null;more=false;busy=false;
 if(show())closeSheet();
 paintStats();
}
function paintStats(){
 if(screen!=='me'||!current())return;
 const nums=$$('.me-statcard button b');
 if(nums.length>=3){
  for(const [i,key] of ['followers','friends','following'].entries()){
   const value=overview?.[key];
   nums[i].textContent=Number.isSafeInteger(value)&&value>=0
    ?value.toLocaleString('ar-IQ'):'—';
  }
 }
}
async function refreshOverview(){
 if(!current())return;
 const id=owner,token=generation,serial=++loadId;
 try{
  const data=await rpc('phase5_social_overview',{p_target:id});
  if(token!==generation||serial!==loadId||!current()||owner!==id)return;
  if(!data||data.userId!==id||!['followers','following','friends'].every(k=>
   Number.isSafeInteger(data[k])&&data[k]>=0))throw Error('البيانات غير مكتملة');
  overview=data;paintStats();
 }catch(e){
  if(token!==generation||serial!==loadId||!current())return;
  overview=null;paintStats();
  if(show())status('لم يتم تحميل أرقام المتابعين: '+String(e.message).slice(0,85));
 }
}
function entry(){
 if(!auth.state().signedIn||screen!=='me')return;
 syncOwner();
 const panel=$('#app .me-more');if(!panel||panel.querySelector('[data-tc-social-open]'))return;
 const b=document.createElement('button');b.type='button';b.dataset.tcSocialOpen='';
 b.setAttribute('aria-label','العلاقات والمتابعون الحقيقيون');
 const ico=text('span','👥','more-icon'),title=text('span','المتابعون والأصدقاء');
 const arrow=text('span','‹','chev');
 b.append(ico,title,arrow);panel.append(b);
 paintStats();
 void refreshOverview();
}
function open(){
 if(!current()||typeof showSheet!=='function')return;
 rows=[];cursor=null;more=false;openTab='friends';
 showSheet('<section id="tc-real-social" class="tc-real-social" dir="rtl" aria-label="العلاقات الحقيقية">'+
 '<header><h3>👥 المتابعون والأصدقاء</h3><button type="button" data-a="close" aria-label="إغلاق">✕</button></header>'+
 '<p id="tc-social-status" role="status"></p>'+
 '<div class="tc-social-tabs"><button data-tc-social-tab="friends" type="button">الأصدقاء</button>'+
 '<button data-tc-social-tab="followers" type="button">المتابعون</button>'+
 '<button data-tc-social-tab="following" type="button">أتابعهم</button></div>'+
 '<form id="tc-social-search" autocomplete="off"><label for="tc-social-query">ابحث بالاسم الحقيقي</label>'+
 '<input id="tc-social-query" name="prefix" minlength="2" maxlength="40" required placeholder="اسم الحساب">'+
 '<button type="submit">بحث</button></form>'+
 '<div id="tc-social-people"></div>'+
 '<button type="button" data-tc-social-more hidden>المزيد</button></section>',true);
 void refreshOverview();
 void loadList(true);
}
function paintList(){
 if(!show()||!current())return;
 const root=$('#tc-social-people');if(!root)return;
 root.replaceChildren();
 for(const row of rows){
  if(!validId(row.user_id))continue;
  const item=document.createElement('article');item.className='tc-social-person';
  const name=text('strong',row.display_name||'مستخدم');
  const id=text('small','ID: '+row.user_id.slice(0,8).toUpperCase());
  item.append(name,id);
  if(row.user_id!==owner){
   const follow=text('button',row.followedByMe?'إلغاء المتابعة':'متابعة');
   follow.type='button';follow.dataset.tcSocialFollow=row.user_id;
   follow.dataset.tcSocialDesired=row.followedByMe?'false':'true';
   item.append(follow);
  }
  root.append(item);
 }
 if(rows.length===0)root.append(text('p','لا توجد علاقات حقيقية ضمن هذه القائمة.','tc-social-empty'));
 const button=$('[data-tc-social-more]');
 if(button)button.hidden=!more;
}
async function loadList(reset=false){
 if(!show()||!current()||busy)return;
 busy=true;const id=owner,stamp=generation,token=++loadId;
 const before=reset?null:cursor;
 status('جارٍ قراءة العلاقات من الخادم…');
 try{
  const result=await rpc('phase5_social_list',{
   p_kind:openTab,p_limit:25,p_before:before
  });
  if(stamp!==generation||token!==loadId||!current()||!show())return;
  if(!result||!Array.isArray(result.items)||result.items.length>25)
   throw Error('استجابة علاقات غير صحيحة');
  // Lists are always for the logged-in account; known follow state derives
  // from list type; for "followers" we query status on-demand on tap.
  const newRows=result.items.filter(x=>validId(x.user_id)).map(x=>({
   ...x,followedByMe:openTab!=='followers'
  }));
  rows=reset?newRows:rows.concat(newRows.filter(x=>!rows.some(y=>y.user_id===x.user_id)));
  cursor=result.items.length?result.items[result.items.length-1].created_at:before;
  more=result.items.length===25;
  paintList();status('');
 }catch(e){
  if(stamp===generation&&show())status('تعذّر جلب العلاقات: '+String(e.message).slice(0,110));
 }finally{busy=false}
}
async function search(form){
 if(!current()||!show()||busy)return;
 const prefix=String(form.elements.prefix.value||'').trim();
 if(prefix.length<2||prefix.length>40)return;
 busy=true;const stamp=generation;
 status('جارٍ البحث عن الحسابات…');
 try{
  const result=await rpc('phase5_social_search',{p_prefix:prefix,p_limit:15});
  if(stamp!==generation||!current()||!show())return;
  if(!result||!Array.isArray(result.items)||result.items.length>15)throw Error('بحث غير صالح');
  rows=result.items.filter(x=>validId(x.user_id)).map(x=>({...x,followedByMe:false}));
  more=false;cursor=null;paintList();status('');
 }catch(e){if(stamp===generation&&show())status('فشل البحث: '+String(e.message).slice(0,100))}
 finally{busy=false}
}
async function changeFollow(button){
 const target=button.dataset.tcSocialFollow,desired=button.dataset.tcSocialDesired==='true';
 if(!validId(target)||target===owner||!current()||busy)return;
 busy=true;button.disabled=true;const token=generation;
 status('جارٍ تسجيل قرار المتابعة…');
 try{
  const result=await rpc('phase5_social_follow',{p_target:target,p_follow:desired,
   p_request_id:crypto.randomUUID()});
  if(token!==generation||!current()||!show())return;
  if(result?.targetId!==target||result?.followed!==desired)
   throw Error('الخادم لم يؤكد العملية');
  // A search row remains visible and updates immediately; lists are refreshed
  // from server instead of inventing a follower count.
  const row=rows.find(x=>x.user_id===target);
  if(row)row.followedByMe=desired;
  paintList();status(desired?'تمت المتابعة على الخادم':'تم إلغاء المتابعة على الخادم');
  void refreshOverview();
 }catch(e){if(token===generation&&show())status('تعذّر تحديث المتابعة: '+String(e.message).slice(0,100))}
 finally{busy=false;if(button.isConnected)button.disabled=false}
}
const prev=window.render;
window.render=function(){
 const result=prev.apply(this,arguments);entry();return result;
};
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-tc-social-open],[data-tc-social-tab],[data-tc-social-more],[data-tc-social-follow]');
 if(!b||!auth.state().signedIn)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(b.hasAttribute('data-tc-social-open')){open();return}
 if(!show()||!current())return;
 if(b.hasAttribute('data-tc-social-tab')){
  const next=b.dataset.tcSocialTab;if(!Object.hasOwn(types,next))return;
  openTab=next;rows=[];cursor=null;more=false;void loadList(true);
 }else if(b.hasAttribute('data-tc-social-more'))void loadList();
 else if(b.hasAttribute('data-tc-social-follow'))void changeFollow(b);
},true);
document.addEventListener('submit',event=>{
 if(event.target?.id!=='tc-social-search')return;
 event.preventDefault();event.stopImmediatePropagation();
 void search(event.target);
},true);
window.addEventListener('totichat-phase2-auth',()=>{syncOwner();if(current())void refreshOverview()});
window.addEventListener('focus',()=>{if(current()&&screen==='me')void refreshOverview()});
window.TotiSocial=Object.freeze({refresh:refreshOverview,isInstalled:()=>true});
queueMicrotask(entry);
})();
