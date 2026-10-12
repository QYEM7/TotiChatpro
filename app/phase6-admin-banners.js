/* TotiChat Owner/partner banners. Reads/updates only audited Staging data.
   No preseeded advertising or sample campaigns. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const qs=(s,r=document)=>r.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
let entries=[],locked=false,pending=null;
const routeChoices=['home','room','ranks','cp','agencyPreview','agency','storePreview','vip','wallet','me','tour','profilePreview','rechargePreview','discoverPreview'];
const api=(fn,body={})=>auth.requestData('/rest/v1/rpc/'+fn,{method:'POST',body});
function notice(s){const n=qs('#tcac-banner-status');if(n)n.textContent=String(s||'').slice(0,200);}
function formMarkup(){
 return '<section class="tcac-module" id="tcac-banner-editor" dir="rtl">'+
 '<h3>إدارة البنرات الحقيقية</h3><p>أنشئ إعلاناً موثقاً أو اختر واحداً من السجلات أعلاه للتعديل. لا تُنشر صور أو روابط نموذجية.</p>'+
 '<form id="tcac-banner-form">'+
 '<label class="tcac-field">الإجراء<select name="action"><option value="create">إنشاء إعلان جديد</option><option value="update">تعديل الإعلان المحدد</option><option value="delete">حذف إعلان غير منشور</option></select></label>'+
 '<label class="tcac-field">معرّف الإعلان الحالي<input name="id" readonly placeholder="يُملأ عند اختيار إعلان موجود"></label>'+
 '<label class="tcac-field">عنوان الإعلان<input name="title" maxlength="120" required></label>'+
 '<label class="tcac-field">صورة حقيقية (PNG/JPEG/WebP حتى 5 MB)<input type="file" name="image" accept="image/png,image/jpeg,image/webp"></label>'+
 '<label class="tcac-field">نوع الرابط<select name="link_kind"><option value="none">بدون رابط</option><option value="screen">صفحة داخل التطبيق</option></select></label>'+
 '<label class="tcac-field">الوجهة داخل التطبيق<select name="link_target">'+routeChoices.map(x=>'<option value="'+esc(x)+'">'+esc(x)+'</option>').join('')+'</select></label>'+
 '<label class="tcac-field">الحالة<select name="status"><option value="draft">مسودة</option><option value="published">منشور</option><option value="archived">مؤرشف</option></select></label>'+
 '<label class="tcac-field">ترتيب العرض<input type="number" name="sort_order" min="0" max="10000" step="1" value="0" required></label>'+
 '<label class="tcac-field">يبدأ (اختياري)<input type="datetime-local" name="starts_at"></label>'+
 '<label class="tcac-field">ينتهي (اختياري)<input type="datetime-local" name="ends_at"></label>'+
 '<button class="tcac-primary" type="submit">حفظ القرار في Supabase</button></form>'+
 '<p id="tcac-banner-status" role="status" aria-live="polite">لا توجد بيانات إعلانية تجريبية.</p>'+
 '</section>';
}
function setRows(rows){entries=Array.isArray(rows)?rows.filter(x=>uuid.test(x?.id)):[];}
function edit(id){
 const form=qs('#tcac-banner-form'),item=entries.find(x=>x.id===id);
 if(!form||!item)return;
 form.elements.action.value='update';
 for(const [key,value] of Object.entries({id:item.id,title:item.title||'',link_kind:item.link_kind||'none',
   link_target:item.link_target||'home',status:item.status||'draft',sort_order:item.sort_order??0})){
  if(form.elements[key])form.elements[key].value=String(value);
 }
 for(const key of ['starts_at','ends_at']){
  if(form.elements[key])form.elements[key].value=item[key]?
    new Date(item[key]).toISOString().slice(0,16):'';
 }
 form.elements.image.value='';
 form.scrollIntoView({block:'start',behavior:'smooth'});
 notice('تعديل الإعلان المحدد: '+item.id);
}
function pathFromImageUrl(url){
 try{
  const u=new URL(String(url));
  const match=u.pathname.match(/\/storage\/v1\/object\/public\/totichat-admin-banners\/([a-f0-9-]{36}\/[a-f0-9-]{36}\.webp)$/i);
  return u.protocol==='https:'?match?.[1]||'':'';
 }catch{return '';}
}
async function webp(file){
 if(!(file instanceof File)||!['image/webp','image/jpeg','image/png'].includes(file.type)||
   file.size<1||file.size>5242880)throw Error('اختر صورة PNG/JPEG/WebP حقيقية أصغر من 5 MB');
 const bitmap=await createImageBitmap(file);
 try{
  const scale=Math.min(1,1800/Math.max(bitmap.width,bitmap.height));
  const canvas=document.createElement('canvas');
  canvas.width=Math.max(1,Math.round(bitmap.width*scale));
  canvas.height=Math.max(1,Math.round(bitmap.height*scale));
  canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',0.83));
  if(!blob||blob.type!=='image/webp'||blob.size>2097152||blob.size<1)
   throw Error('فشل تحويل الصورة إلى WebP بحجم مقبول');
  return blob;
 }finally{bitmap.close?.();}
}
async function save(form){
 if(locked)return;
 const id=auth.state().user?.id||'',staff=await api('phase3_admin_session');
 if(!id||!(staff?.isOwner===true||staff?.isMainPartner===true))throw Error('هذا الإجراء خاص بالمالك والشريك الرئيسي');
 const f=new FormData(form),get=k=>String(f.get(k)||'').trim();
 const action=get('action'),bannerId=get('id')||null;
 if(!['create','update','delete'].includes(action)||action!=='create'&&!uuid.test(bannerId))throw Error('اختر إعلاناً صحيحاً');
 const selected=entries.find(x=>x.id===bannerId);
 if(action!=='create'&&!selected)throw Error('اختر إعلاناً موجوداً من القائمة');
 const title=get('title'),kind=get('link_kind'),target=kind==='screen'?get('link_target'):null;
 const status=get('status'),order=get('sort_order');
 const a=get('starts_at'),b=get('ends_at');
 if(action!=='delete'&&(!title||title.length>120||!['none','screen'].includes(kind)||
  !['draft','published','archived'].includes(status)||!routeChoices.includes(get('link_target'))||
  !/^[0-9]{1,5}$/.test(order)||Number(order)>10000))throw Error('بيانات الإعلان غير صالحة');
 const starts=a?new Date(a).toISOString():null,ends=b?new Date(b).toISOString():null;
 if(starts&&ends&&starts>=ends)throw Error('تاريخ النهاية يجب أن يكون بعد البداية');
 const file=f.get('image');
 if(action==='create'&&(!(file instanceof File)||file.size===0))throw Error('ارفع صورة الإعلان أولاً');
 if(!window.confirm(action==='delete'?'تأكيد حذف الإعلان غير المنشور نهائياً؟':
   status==='published'?'تأكيد نشر هذا الإعلان الحقيقي للمستخدمين في Staging؟':'تأكيد حفظ الإعلان في Staging؟'))return;
 const signature=JSON.stringify({id,action,bannerId,title,kind,target,status,order,starts,ends,
  file:file instanceof File&&file.size?[file.name,file.size,file.lastModified]:null});
 if(!pending||pending.signature!==signature)pending={signature,requestId:crypto.randomUUID(),path:null};
 const current=pending,button=form.querySelector('button[type="submit"]');
 locked=true;if(button)button.disabled=true;
 try{
  let imagePath=action==='create'?'':pathFromImageUrl(selected?.image_url);
  if(action!=='delete'&&file instanceof File&&file.size){
   if(!current.path){
    notice('جارٍ تحويل ورفع الصورة الحقيقية…');
    current.path=await auth.uploadAdminBannerImage(await webp(file));
   }
   imagePath=current.path;
  }
  if(action!=='delete'&&!imagePath)throw Error('لا توجد صورة بنر حقيقية في المخزن');
  const data=action==='delete'?{}:{title,image_path:imagePath,link_kind:kind,link_target:target,
   status,sort_order:Number(order),starts_at:starts,ends_at:ends};
  const outcome=await api('phase6_admin_banner_action',{p_action:action,p_id:action==='create'?null:bannerId,
    p_data:data,p_request_id:current.requestId});
  if(action==='delete'?outcome?.deleted!==true:outcome?.saved!==true)throw Error('لم يؤكد Supabase حفظ القرار');
  pending=null;
  if(id!==auth.state().user?.id||!qs('#tcac-banner-form'))return;
  form.reset();form.elements.id.value='';
  notice(status==='published'?'تم نشر البنر الحقيقي بعد تأكيد الخادم.':'تم حفظ البنر في قاعدة البيانات.');
  // Live home must react to an approved real banner immediately, never show a dummy ad.
  void window.TotiBannerData?.refresh?.();
  document.querySelector('#tcac-root [data-tcac="refresh"]')?.click();
 }finally{locked=false;if(button?.isConnected)button.disabled=false;}
}
document.addEventListener('click',e=>{
 const btn=e.target.closest('#tcac-root [data-tcac-banner-edit]');
 if(!btn)return;
 e.preventDefault();e.stopImmediatePropagation();
 edit(btn.dataset.tcacBannerEdit);
},true);
document.addEventListener('submit',e=>{
 if(e.target?.id!=='tcac-banner-form')return;
 e.preventDefault();e.stopImmediatePropagation();
 if(!e.target.reportValidity())return;
 void save(e.target).catch(err=>notice('تعذر حفظ الإعلان: '+String(err.message).slice(0,160)));
},true);
window.TotiAdminBanners=Object.freeze({formMarkup,setRows});
})();
