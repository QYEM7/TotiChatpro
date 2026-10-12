/* Real read-only host agency monthly preflight, not a payroll engine.
 * Explicitly cannot zero diamonds, pay salaries, or invent agreed commission rates.
 * Only the verified Owner / designated main partner sees the review entry.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const rpc=(name,body)=>auth.requestData('/rest/v1/rpc/'+name,{method:'POST',body});
const validUUID=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
const node=(tag,value,cls)=>{
 const n=document.createElement(tag);n.textContent=String(value??'');if(cls)n.className=cls;return n;
};
let owner='',epoch=0,authority=null,authorityAt=0,verifying=false,loading=false,requestSerial=0;
let month='',offset=0,total=0,entries=[];
let snapshotBusy=false;
function current(){return auth.state().signedIn===true&&auth.state().user?.id===owner}
function trustedAuthority(){return authority?.isOwner===true||authority?.isMainPartner===true}
function sheet(){return $('#tc-host-month-sheet')&&$('#overlay')?.classList.contains('show')}
function changeUser(){
 const uid=auth.state().user?.id||'';
 if(owner===uid)return;
 if(sheet()&&typeof closeSheet==='function')closeSheet();
 owner=uid;epoch++;requestSerial++;authority=null;authorityAt=0;verifying=false;loading=false;
 month='';offset=0;total=0;entries=[];snapshotBusy=false;
}
function entry(){
 if(window.TotiInAppAdmin)return; // New unified center owns the Profile entry.
 if(!current()||!trustedAuthority()||screen!=='me')return;
 const panel=$('#app .me-more');
 if(!panel||panel.querySelector('[data-tc-host-month]'))return;
 const b=document.createElement('button');b.type='button';b.dataset.tcHostMonth='';
 b.setAttribute('aria-label','تقرير الماس الشهري للتحقق فقط');
 for(const [cls,label] of [['more-icon','📊'],['','مراجعة ماس وكالات المضيفين'],['chev','‹']])
  b.append(node('span',label,cls));
 panel.append(b);
}
async function inspect(force=false){
 if(!current()||verifying||(!force&&Date.now()-authorityAt<60000))return;
 const uid=owner,stamp=epoch;verifying=true;authorityAt=Date.now();
 try{
  const result=await rpc('phase3_admin_session',{});
  if(stamp!==epoch||!current()||uid!==owner)return;
  authority=result||null;entry();
 }catch(_){if(stamp===epoch)authority=null}
 finally{if(stamp===epoch)verifying=false}
}
function previousMonth(){
 const d=new Date(),first=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()-1,1));
 return first.toISOString().slice(0,7);
}
const format=x=>{
 if(!Number.isSafeInteger(x)||x<0)return 'غير قابل للتحقق بدقة';
 return BigInt(x).toLocaleString('ar-IQ');
};
function message(txt){
 const n=$('#tc-host-month-message');if(n)n.textContent=String(txt||'').slice(0,210);
}
function paint(){
 if(!sheet()||!current())return;
 const out=$('#tc-host-month-lines'),stats=$('#tc-host-month-count');
 if(!out||!stats)return;
 out.replaceChildren();
 stats.textContent='مدخلات مضيفين/وكالات: '+format(total)+' · شهر UTC: '+month;
 for(const e of entries){
  if(!validUUID(e.agency_id)||!validUUID(e.user_id))continue;
  const article=document.createElement('article');article.className='tc-host-month-entry';
  article.append(
   node('strong','الوكالة '+e.agency_id.slice(0,8).toUpperCase()),
   node('span','المضيف '+e.user_id.slice(0,8).toUpperCase()),
   node('span','ماس صادر من هدايا الشهر: '+format(e.earned_diamonds)),
   node('span','الماس المتبقي حالياً من الدفعات: '+format(e.remaining_diamonds)),
   node('span','ماس حُوّل أو خُصص: '+format(e.converted_or_allocated_diamonds))
  );out.append(article);
 }
 if(!entries.length&&!loading)out.append(node('p','لا توجد هدايا مضيفين موثقة في الشهر المحدد.','tc-host-month-empty'));
 const next=$('#tc-host-month-more');
 if(next)next.hidden=entries.length>=total;
}
async function load(reset=false){
 if(!sheet()||!current()||!trustedAuthority()||loading)return;
 const input=$('#tc-host-month-value'),value=input?.value||'';
 if(!/^20[2-9][0-9]-(?:0[1-9]|1[0-2])$/.test(value)||value>previousMonth()){
  message('حدد شهراً مغلقاً بصيغة سنة/شهر، وليس الشهر الحالي.');
  return;
 }
 if(reset){month=value;offset=0;entries=[];total=0;}
 else if(month!==value)return;
 loading=true;const uid=owner,stamp=epoch,seq=++requestSerial,start=offset;
 message('جارٍ تحميل أرقام الماس الحقيقية من سجلات الهدايا…');
 try{
  const data=await rpc('phase5_host_month_preflight',{
   p_month:month+'-01',p_offset:start,p_limit:25
  });
  if(stamp!==epoch||seq!==requestSerial||uid!==owner||!sheet()||!current())return;
  if(!data||data.month!==month+'-01'||data.isDraftPreflight!==true||
   data.canZeroDiamonds!==false||data.paysSalaries!==false||
   data.hasPayrollRates!==false||
   !Number.isSafeInteger(data.totalHostEntries)||data.totalHostEntries<0||
   !Array.isArray(data.entries)||data.entries.length>25||
   data.entries.some(e=>!validUUID(e.agency_id)||!validUUID(e.user_id)||
    !['earned_diamonds','remaining_diamonds','converted_or_allocated_diamonds'].every(k=>
      Number.isSafeInteger(e[k])&&e[k]>=0)||
    e.earned_diamonds!==e.remaining_diamonds+e.converted_or_allocated_diamonds))
   throw Error('بيانات ماس غير مكتملة أو أعلى من دقة المتصفح');
  total=data.totalHostEntries;
  entries=reset?data.entries:entries.concat(data.entries);
  offset=start+data.entries.length;
  message('هذه مراجعة قرائية فقط. لا تُصرف رواتب ولا يُصفّر الماس قبل تثبيت المستحقات والنسب المعتمدة.');
 }catch(e){if(stamp===epoch&&sheet())message('تعذرت المراجعة: '+String(e.message).slice(0,105))}
 finally{if(stamp===epoch){loading=false;paint()}}
}
function snapshotMessage(s){
 const n=$('#tc-host-snapshot-message');
 if(n)n.textContent=String(s||'').slice(0,240);
}
const positiveCount=x=>(Number.isSafeInteger(x)&&x>=0)||
 (typeof x==='string'&&/^(0|[1-9][0-9]{0,28})$/.test(x));
async function snapshotRead(){
 if(!sheet()||!current()||!trustedAuthority()||snapshotBusy)return;
 const input=$('#tc-host-month-value'),selected=input?.value||'';
 if(!/^20[2-9][0-9]-(?:0[1-9]|1[0-2])$/.test(selected)||
   selected>previousMonth()){
  snapshotMessage('اختر شهراً مغلقاً للتحقق من كشف الاستحقاق.');
  return;
 }
 snapshotBusy=true;const uid=owner,stamp=epoch;
 snapshotMessage('جارٍ قراءة كشف الاستحقاق الثابت من الخادم…');
 try{
  const result=await rpc('phase5_host_month_snapshot_state',{
   p_month:selected+'-01',p_offset:0,p_limit:1});
  if(stamp!==epoch||uid!==owner||!current()||!sheet())return;
  if(!result||typeof result.captured!=='boolean'||result.isAccrualEvidenceOnly!==true||
    result.paysSalaries!==false||result.canZeroDiamonds!==false||
    result.hasPayrollRates!==false||!positiveCount(result.entries))
   throw Error('استجابة كشف الاستحقاق غير صالحة');
  snapshotMessage(result.captured?
   'كشف أرباح الماس التاريخية محفوظ دون تعديل · عدد مدخلاته: '+String(result.entries)+
    ' · إجمالي الماس المثبت: '+String(result.totalDiamonds):
   'لا يوجد كشف استحقاق محفوظ لهذا الشهر. لا توجد تسوية أو تصفير.');
 }catch(e){
  if(stamp===epoch&&sheet()&&current())
   snapshotMessage('تعذرت قراءة الكشف: '+String(e.message||'خطأ').slice(0,115));
 }finally{if(stamp===epoch)snapshotBusy=false}
}
async function snapshotCapture(){
 if(!sheet()||!current()||!trustedAuthority()||snapshotBusy)return;
 const selected=$('#tc-host-month-value')?.value||'';
 if(!/^20[2-9][0-9]-(?:0[1-9]|1[0-2])$/.test(selected)||
   selected>previousMonth()){
  snapshotMessage('حدد شهراً مغلقاً قبل إنشاء كشف الاستحقاق.');return;
 }
 if(typeof confirm==='function'&&!confirm(
  'تأكيد حفظ كشف استحقاقات الماس التاريخية لشهر '+selected+
  ' بشكل ثابت لا يقبل التعديل؟ هذا لا يدفع رواتب، ولا يصفر الماس.'))return;
 snapshotBusy=true;const uid=owner,stamp=epoch;
 snapshotMessage('جارٍ حفظ أرباح الهدايا الحقيقية لشهر مغلق…');
 try{
  const result=await rpc('phase5_host_month_snapshot_capture',{
   p_month:selected+'-01',p_request_id:crypto.randomUUID()});
  if(stamp!==epoch||uid!==owner||!current()||!sheet())return;
  if(!result||result.captured!==true||result.isAccrualEvidenceOnly!==true||
   result.paysSalaries!==false||result.canZeroDiamonds!==false||
   result.hasPayrollRates!==false||!positiveCount(result.giftCount)||
   !positiveCount(result.entries)||!positiveCount(result.totalDiamonds))
   throw Error('لم يؤكد الخادم حفظ الكشف الثابت');
  snapshotMessage((result.alreadyCaptured?'الكشف موجود مسبقاً · ':'تم حفظ كشف ثابت · ')+
   'الهدايا: '+String(result.giftCount)+', المدخلات: '+String(result.entries)+
   '، الماس الأصلي: '+String(result.totalDiamonds)+'. لا رواتب ولا تصفير.');
 }catch(e){
  if(stamp===epoch&&sheet()&&current())
   snapshotMessage('تعذر إنشاء الكشف: '+String(e.message||'خطأ').slice(0,105));
 }finally{if(stamp===epoch)snapshotBusy=false}
}
function open(){
 if(!current()||!trustedAuthority()||typeof showSheet!=='function')return;
 month=previousMonth();offset=0;total=0;entries=[];
 showSheet('<section id="tc-host-month-sheet" class="tc-host-month" dir="rtl">'+
  '<header><h3>📊 مراجعة ماس وكالات المضيفين</h3><button data-a="close" type="button" aria-label="إغلاق">✕</button></header>'+
  '<p>للمالك الرئيسي وشريكه المعتمد فقط. المسودة قرائية: لا تحويل كوينز، لا تسوية رواتب، لا تصفير.</p>'+
  '<label>الشهر المغلق (UTC)<input type="month" id="tc-host-month-value"></label>'+
  '<button data-tc-host-month-load type="button">قراءة البيانات</button>'+
  '<p id="tc-host-month-message" role="status"></p><p id="tc-host-month-count"></p>'+
  '<div id="tc-host-month-lines"></div>'+
  '<button type="button" id="tc-host-month-more" data-tc-host-month-more hidden>مدخلات أخرى</button>'+
  '<p>الرواتب والعمولات والتارجت تحتاج نسباً معتمدة وتسوية مستحقات مثبتة قبل أي تصفير.</p>'+
  '<p id="tc-host-snapshot-message" role="status">لا توجد تسوية أو تصفير من هنا.</p>'+
  '<button type="button" data-tc-host-snapshot-read>عرض الكشف الشهري المحفوظ</button>'+
  '<button type="button" data-tc-host-snapshot-capture>تثبيت سجل أرباح الماس التاريخية فقط</button>'+
 '</section>',true);
 const input=$('#tc-host-month-value');if(input){input.value=month;input.max=month;}
 void load(true);
}
function mount(){
 changeUser();if(!current())return;
 if(screen==='me'){entry();void inspect()}
}
const previous=window.render;
window.render=function(){const result=previous.apply(this,arguments);mount();return result};
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-tc-host-month],[data-tc-host-month-load],[data-tc-host-month-more],[data-tc-host-snapshot-read],[data-tc-host-snapshot-capture]');
 if(!b)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(b.hasAttribute('data-tc-host-month')){open();return}
 if(!sheet()||!current()||!trustedAuthority())return;
 if(b.hasAttribute('data-tc-host-month-load'))void load(true);
 if(b.hasAttribute('data-tc-host-month-more'))void load(false);
 if(b.hasAttribute('data-tc-host-snapshot-read'))void snapshotRead();
 if(b.hasAttribute('data-tc-host-snapshot-capture'))void snapshotCapture();
},true);
window.addEventListener('totichat-phase2-auth',()=>{changeUser();if(current())mount()});
window.TotiHostMonth=Object.freeze({isInstalled:()=>true});
queueMicrotask(mount);
})();
