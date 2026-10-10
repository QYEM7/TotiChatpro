/* Permission-gated SQL reports; XLSX cells are typed values, never formulas. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;if(!auth||!window.TotiLiveMode?.enabled)return;
const enc=new TextEncoder(),xml=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c])).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,'');
function zip(files){
 const chunks=[],directory=[];let offset=0;
 const crc=data=>{let c=0xffffffff;for(const b of data){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (c^0xffffffff)>>>0;};
 for(const [name,text] of Object.entries(files)){
  const n=enc.encode(name),d=enc.encode(text),sum=crc(d),h=new Uint8Array(30+n.length),v=new DataView(h.buffer);
  v.setUint32(0,0x04034b50,true);v.setUint16(4,20,true);v.setUint16(12,33,true);v.setUint32(14,sum,true);v.setUint32(18,d.length,true);v.setUint32(22,d.length,true);v.setUint16(26,n.length,true);h.set(n,30);chunks.push(h,d);
  const c=new Uint8Array(46+n.length),w=new DataView(c.buffer);w.setUint32(0,0x02014b50,true);w.setUint16(4,20,true);w.setUint16(6,20,true);w.setUint16(14,33,true);w.setUint32(16,sum,true);w.setUint32(20,d.length,true);w.setUint32(24,d.length,true);w.setUint16(28,n.length,true);w.setUint32(42,offset,true);c.set(n,46);directory.push(c);offset+=h.length+d.length;
 }
 const end=new Uint8Array(22),v=new DataView(end.buffer),size=directory.reduce((n,x)=>n+x.length,0);v.setUint32(0,0x06054b50,true);v.setUint16(8,directory.length,true);v.setUint16(10,directory.length,true);v.setUint32(12,size,true);v.setUint32(16,offset,true);
 return new Blob([...chunks,...directory,end],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
}
function xlsx(rows){
 const cols=[...new Set(rows.flatMap(r=>Object.keys(r)))],grid=[cols,...rows.map(r=>cols.map(c=>r[c]))];
 const sheet='<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0" rightToLeft="1"/></sheetViews><sheetData>'+grid.map((r,i)=>'<row r="'+(i+1)+'">'+r.map(value=>typeof value==='number'&&Number.isFinite(value)?'<c><v>'+value+'</v></c>':'<c t="inlineStr"><is><t xml:space="preserve">'+xml(typeof value==='object'&&value!==null?JSON.stringify(value):value)+'</t></is></c>').join('')+'</row>').join('')+'</sheetData></worksheet>';
 return zip({'[Content_Types].xml':'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>','_rels/.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>','xl/workbook.xml':'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="المعاملات" sheetId="1" r:id="rId1"/></sheets></workbook>','xl/_rels/workbook.xml.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>','xl/worksheets/sheet1.xml':sheet});
}
window.TotiPhase4Exports=Object.freeze({xlsx});
let generation=0,state=null,filters=null,offset=0,busy=false,reportOwner=null;
const status=x=>{const n=document.querySelector('[data-report-status]');if(n)n.textContent=x;};
async function load(){
 const version=++generation,owner=auth.state().user?.id;status('جارٍ تحميل التقرير…');
 try{const r=await auth.requestData('/rest/v1/rpc/phase4_admin_report',{method:'POST',body:{...filters,p_offset:offset,p_limit:100}});if(version!==generation||owner!==auth.state().user?.id)return;
  if(!Array.isArray(r.rows)||!r.summary)throw Error('استجابة التقرير غير صالحة');state=r;
  const n=document.querySelector('[data-report-results]');if(!n)return;n.replaceChildren();
  const labels={users:'المستخدمون',verified_users:'البريد المؤكد',coins:'إجمالي العملات',diamonds:'إجمالي الماس',gift_count:'عدد الهدايا',gift_amount:'قيمة الهدايا',relationships:'العلاقات المؤكدة',operation_statuses:'حالات المعاملات'};
  for(const [key,value] of Object.entries(r.summary)){const p=document.createElement('p');p.textContent=(labels[key]||key)+': '+(typeof value==='object'?JSON.stringify(value):value);n.appendChild(p);}
  const h=document.createElement('h4');h.textContent='المعاملات: '+r.total+' · صفحة '+(1+offset/100);n.appendChild(h);
  for(const row of r.rows){const p=document.createElement('p');p.textContent=row.created_at+' · '+row.operation+' · '+row.status+' · '+row.id;n.appendChild(p);}
  if(!r.rows.length){const p=document.createElement('p');p.textContent='لا توجد معاملات تطابق الفلاتر.';n.appendChild(p);}status('تم تحميل بيانات القاعدة؛ إجمالي الأرصدة يشمل جميع الحسابات، والهدايا والمعاملات للفترة المحددة.');
 }catch(e){if(version===generation&&owner===auth.state().user?.id)status(e.message+'؛ استخدم تحديث لإعادة المحاولة');}
}
function open(){
 reportOwner=auth.state().user?.id;
 const now=new Date(),from=new Date(now.getTime()-30*86400000);filters={p_from:from.toISOString(),p_to:now.toISOString(),p_status:null};offset=0;state=null;
 showSheet('<section dir="rtl" class="tc-phase2-account-sheet"><h3>التقارير والمعاملات</h3><form data-report-filters><label>من<input type="date" name="from" value="'+from.toISOString().slice(0,10)+'" required></label><label>إلى (يشمل اليوم)<input type="date" name="to" value="'+now.toISOString().slice(0,10)+'" required></label><label>الحالة<select name="status"><option value="">الكل</option><option>pending</option><option>completed</option><option>failed</option><option>refunded</option></select></label><button class="primary">تطبيق الفلاتر</button></form><p role="status" data-report-status></p><div data-report-results></div><button class="primary" data-report-action="refresh">تحديث</button><button class="primary" data-report-action="previous">السابق</button><button class="primary" data-report-action="next">التالي</button><button class="primary" data-report-action="export">تصدير الصفحة Excel</button><button class="primary" data-a="close">إغلاق</button></section>',true);void load();
}
window.addEventListener('submit',e=>{if(!e.target.matches('[data-report-filters]'))return;e.preventDefault();e.stopImmediatePropagation();if(!e.target.reportValidity())return;const data=new FormData(e.target),start=new Date(data.get('from')+'T00:00:00Z'),end=new Date(data.get('to')+'T00:00:00Z');end.setUTCDate(end.getUTCDate()+1);if(end<=start||end-start>366*86400000){status('اختر فترة صحيحة لا تتجاوز 366 يوماً (UTC)');return;}filters={p_from:start.toISOString(),p_to:end.toISOString(),p_status:data.get('status')||null};offset=0;void load();},true);
window.addEventListener('click',e=>{
 const b=e.target.closest('[data-reports-open],[data-report-action]');if(!b)return;e.preventDefault();e.stopImmediatePropagation();if(b.hasAttribute('data-reports-open')){open();return;}if(busy)return;
 if(b.dataset.reportAction==='export'){if(!state?.rows.length){status('لا توجد بيانات للتصدير');return;}const url=URL.createObjectURL(xlsx(state.rows)),a=document.createElement('a');a.href=url;a.download='totichat-transactions-'+new Date().toISOString().slice(0,10)+'.xlsx';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);return;}
 if(b.dataset.reportAction==='previous'){if(offset===0)return;offset=Math.max(0,offset-100);}if(b.dataset.reportAction==='next'){if(!state||offset+100>=state.total)return;offset+=100;}
 busy=true;b.disabled=true;void load().finally(()=>{busy=false;if(b.isConnected)b.disabled=false;});
},true);
window.addEventListener('totichat-phase2-auth',()=>{generation++;state=null;filters=null;if(reportOwner!==auth.state().user?.id){document.querySelector('[data-report-results]')?.replaceChildren();document.querySelector('[data-report-filters]')?.remove();status('تم تغيير الحساب؛ افتح التقارير مجدداً للتحقق من الصلاحية');}reportOwner=auth.state().user?.id;});
})();
