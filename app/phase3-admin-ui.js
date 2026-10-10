/* Restricted live catalog administration. Authority is decided by server RPCs. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
const names={gift_categories:'تصنيفات الهدايا',gift_catalog:'الهدايا',store_catalog:'المتجر',cp_types:'أنواع CP',recharge_packages:'باقات الشحن',recharge_reward_tiers:'مكافآت الشحن'};
const labels={id:'المعرّف',name:'الاسم',label:'العنوان',price:'السعر',currency:'العملة',category:'الفئة',category_id:'تصنيف الهدية',relationship_type_id:'نوع علاقة CP',sort_order:'ترتيب العرض',enabled:'مفعّل',is_active:'نشط',is_reward:'مكافأة',is_primary:'أساسي',icon:'الرمز',description:'الوصف',preview_url:'رابط العرض',duration_days:'المدة بالأيام',vip_level:'مستوى VIP',gold_amount:'عدد العملات',price_usd:'السعر بالدولار',threshold_usd:'حد المكافأة بالدولار',rewards:'قائمة المكافآت',presentation:'إعدادات العرض',level_thresholds:'حدود المستويات',diamond_source_type:'مصدر الماس',global_announcement_enabled:'إعلان عام',animation_type:'حركة الهدية',rarity:'الندرة'};
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let table='gift_catalog',offset=0,state=null,generation=0,busy=false,pending=null,editing=null,authority=null;
const rpc=(name,body={})=>auth.requestData('/rest/v1/rpc/phase3_'+name,{method:'POST',body});
function status(text){const node=document.querySelector('[data-admin-status]');if(node)node.textContent=text;}
async function open(){
 const user=auth.state().user?.id;if(!user)return;
 showSheet('<section dir="rtl" class="tc-phase2-account-sheet" data-admin-sheet><h3>إدارة الإعدادات</h3><p data-admin-status role="status">جارٍ التحقق من الصلاحيات…</p><div data-admin-body></div><button class="primary" data-a="close">إغلاق</button></section>',true);
 const version=++generation;
 try{authority=await rpc('admin_session');if(version!==generation||auth.state().user?.id!==user)return;
 if(!authority.canManageCatalogs)throw Error('لا تملك صلاحية إدارة الإعدادات');await load();}catch(e){status(e.message);}
}
async function load(){
 const version=++generation,user=auth.state().user?.id;status('جارٍ تحميل السجلات…');
 try{const result=await rpc('catalog_list',{p_table:table,p_offset:offset,p_limit:20});
 if(version!==generation||auth.state().user?.id!==user)return;state=result;
 const body=document.querySelector('[data-admin-body]');if(!body)return;
 body.innerHTML='<label>القسم<select data-admin-table>'+Object.keys(names).map(n=>'<option value="'+n+'"'+(n===table?' selected':'')+'>'+names[n]+'</option>').join('')+'</select></label><button class="primary" data-admin-action="new">إضافة سجل</button><button class="primary" data-admin-action="export">تصدير CSV</button><p>'+result.total+' سجل</p><div data-admin-records>'+result.rows.map((r,i)=>'<article><strong>'+esc(r.name||r.label||r.id)+'</strong><span> · '+esc(r.id)+'</span><button class="primary" data-admin-action="edit" data-index="'+i+'">تعديل</button><button class="primary" data-admin-action="delete" data-index="'+i+'">حذف</button></article>').join('')+'</div>'+(!result.rows.length?'<p>لا توجد سجلات.</p>':'')+'<button class="primary" data-admin-action="previous">السابق</button><button class="primary" data-admin-action="next">التالي</button><div data-admin-editor></div>'+(authority.isOwner?'<button class="primary" data-admin-action="roles">إدارة الصلاحيات</button>':'');status('تم تحميل البيانات الفعلية');
 }catch(e){status(e.message+'؛ أعد فتح الإدارة لإعادة المحاولة');}
}
async function editor(row){
 editing=row||null;pending=null;
 const node=document.querySelector('[data-admin-editor]');if(!node)return;
 const capturedTable=table,version=generation;
 const [cats,types]=await Promise.all([rpc('catalog_list',{p_table:'gift_categories',p_limit:100}),rpc('catalog_list',{p_table:'cp_types',p_limit:100})]);
 if(table!==capturedTable||version!==generation)return;
 node.innerHTML='<form data-admin-form><h4>'+(row?'تعديل السجل':'سجل جديد')+'</h4>'+state.columns.filter(c=>!(row&&c.name==='id')).map(c=>{
  const value=row?.[c.name],required=!c.nullable&&!c.hasDefault?' required':'',common=' name="'+c.name+'"'+required;
  let input;
  const options=c.name==='category_id'?cats.rows:c.name==='relationship_type_id'?types.rows:null;
  if(options)input='<select'+common+'><option value="">اختر</option>'+options.map(x=>'<option value="'+esc(x.id)+'"'+(value===x.id?' selected':'')+'>'+esc(x.label)+'</option>').join('')+'</select>';
  else if(c.type==='boolean')input='<input type="checkbox" name="'+c.name+'"'+(value===true||(!row&&c.defaultTrue)?' checked':'')+'>';
  else if(c.type==='jsonb'||c.type==='ARRAY')input='<textarea'+common+' rows="4">'+esc(value===undefined?'':JSON.stringify(value,null,2))+'</textarea>';
  else input='<input'+common+' type="'+(/integer|numeric/.test(c.type)?'number':'text')+'"'+(c.type==='numeric'?' step="any"':'')+' value="'+esc(value??'')+'">';
  return '<label>'+esc(labels[c.name]||c.name)+input+'</label>';
 }).join('')+'<button class="primary">حفظ</button></form>';
}
async function write(action,id,record){
 const signature=JSON.stringify([auth.state().user?.id,table,action,id,record]);
 if(!pending||pending.signature!==signature)pending={signature,key:crypto.randomUUID()};
 const result=await rpc('catalog_write',{p_table:table,p_action:action,p_id:id,p_record:record,p_request_id:pending.key});pending=null;
 window.dispatchEvent(new CustomEvent('totichat-catalog-changed'));await load();status('تم حفظ العملية في قاعدة البيانات');return result;
}
window.addEventListener('click',event=>{
 const target=event.target.closest('[data-admin-open],[data-admin-action]');if(!target)return;
 event.preventDefault();event.stopImmediatePropagation();if(target.hasAttribute('data-admin-open')){void open();return;}if(busy)return;
 busy=true;target.disabled=true;
 void (async()=>{switch(target.dataset.adminAction){
  case 'new':await editor(null);break;
  case 'edit':await editor(state.rows[Number(target.dataset.index)]);break;
  case 'delete':{const row=state.rows[Number(target.dataset.index)];if(confirm('حذف '+(row.name||row.label||row.id)+'؟ قد تمنع القاعدة حذف السجلات المستخدمة.'))await write('delete',String(row.id),null);break;}
  case 'previous':if(offset>0){offset=Math.max(0,offset-20);await load();}break;
  case 'next':if(offset+20<state.total){offset+=20;await load();}break;
  case 'roles':document.querySelector('[data-admin-editor]').innerHTML='<form data-admin-roles><h4>تعيين الصلاحيات</h4><label>معرّف المستخدم الكامل<input name="user" required></label><label>الدور<select name="role"><option value="admin">Admin</option><option value="super_admin">Super Admin</option><option value="db">DB</option></select></label><label><input type="checkbox" name="catalog">إدارة الإعدادات</label><label><input type="checkbox" name="partner">تعيين الشريك الرئيسي (Super Admin)</label><button class="primary">حفظ الصلاحيات</button></form>';break;
  case 'export':{
   let rows=[];for(let n=0;n<state.total;n+=100){const batch=await rpc('catalog_list',{p_table:table,p_offset:n,p_limit:100});rows.push(...batch.rows);}
   const keys=state.columns.map(c=>c.name),cell=v=>'"'+String(typeof v==='object'&&v!==null?JSON.stringify(v):v??'').replace(/^[\s]*[=+@-]/,"'$&").replaceAll('"','""')+'"';
   const csv='\uFEFF'+[keys,...rows.map(r=>keys.map(k=>r[k]))].map(row=>row.map(cell).join(',')).join('\r\n');
   const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'})),a=document.createElement('a');a.href=url;a.download=table+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);status('تم تصدير السجلات الفعلية');break;
  }
 }})().catch(e=>status(e.message)).finally(()=>{busy=false;if(target.isConnected)target.disabled=false;});
},true);
window.addEventListener('change',event=>{if(event.target.matches('[data-admin-table]')){table=event.target.value;offset=0;pending=null;void load();}});
window.addEventListener('submit',event=>{
 const form=event.target;if(!form.matches('[data-admin-form],[data-admin-roles]'))return;
 event.preventDefault();event.stopImmediatePropagation();if(busy||!form.reportValidity())return;
 busy=true;const button=form.querySelector('button');button.disabled=true;status('جارٍ الحفظ…');
 void (async()=>{
  const values=new FormData(form);
  if(form.matches('[data-admin-roles]')){if(!confirm('تأكيد تعديل صلاحيات هذا المستخدم؟'))return;await rpc('manage_access',{p_user_id:values.get('user'),p_role:values.get('role'),p_permissions:values.has('catalog')?['catalog.manage']:[],p_main_partner:values.has('partner')});status('تم تسجيل تغيير الصلاحيات');return;}
  const record={};for(const c of state.columns){if(editing&&c.name==='id')continue;
   const input=form.elements.namedItem(c.name);if(!input)continue;
   if(c.type==='boolean'){record[c.name]=input.checked;continue;}
   const value=input.value;if(value===''&&!editing&&c.hasDefault)continue;
   if(value===''&&c.nullable){record[c.name]=null;continue;}
   if(c.type==='jsonb'||c.type==='ARRAY')record[c.name]=JSON.parse(value);
   else if(/integer|numeric/.test(c.type)){const n=Number(value);if(!Number.isFinite(n)||(/integer/.test(c.type)&&!Number.isSafeInteger(n)))throw Error('قيمة رقمية غير صالحة: '+(labels[c.name]||c.name));record[c.name]=n;}
   else record[c.name]=value;
  }
  if(!confirm('تأكيد حفظ تعديلات '+names[table]+'؟'))return;
  await write(editing?'update':'create',editing?String(editing.id):null,record);
 })().catch(e=>status(e.message)).finally(()=>{busy=false;if(button.isConnected)button.disabled=false;});
},true);
window.addEventListener('totichat-phase2-auth',()=>{generation++;pending=null;authority=null;document.querySelector('[data-admin-sheet]')?.remove();});
window.TotiAdminCatalogs=Object.freeze({open});
})();
