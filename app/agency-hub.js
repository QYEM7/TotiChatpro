/* TotiChat agency/recharge complete UI flow. LOCAL DEMO ONLY; never transfer coins, charge users or write backend data. */
(function(){
'use strict';
const KEY='totichat.agency.prototype.v2';
const packs=[4900,24500,49000,122500,245000,490000];
const demoAgents=[
 {id:'AG-1001',name:'وكالة الرافدين · نموذج',city:'بغداد',rating:'4.8',count:125,balance:500000,online:true,active:true},
 {id:'AG-1002',name:'وكالة النخيل · نموذج',city:'البصرة',rating:'4.7',count:84,balance:180000,online:true,active:true},
 {id:'AG-1003',name:'وكالة الندى · نموذج',city:'أربيل',rating:'—',count:0,balance:0,online:false,active:true}
];
const initial=()=>({role:'user',section:'overview',pack:24500,agent:'',orders:[],tickets:[],ratings:[],staff:[{id:'S-1001',uid:'8123900',name:'موظف تجريبي',role:'staff',shift:'on',enabled:true,perTx:25000,daily:100000}],hires:[],payroll:[],agencyOnline:true,coins:500000,search:'',selectedOrder:null,notice:''});
let state=initial();
try{const o=JSON.parse(localStorage.getItem(KEY)||'null');if(o&&typeof o==='object')state={...state,...o,staff:Array.isArray(o.staff)?o.staff:state.staff,orders:Array.isArray(o.orders)?o.orders:[],tickets:Array.isArray(o.tickets)?o.tickets:[],ratings:Array.isArray(o.ratings)?o.ratings:[],hires:Array.isArray(o.hires)?o.hires:[],payroll:Array.isArray(o.payroll)?o.payroll:[]};}catch(e){}
const E=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));
const fmt=n=>Number(n||0).toLocaleString('en-US');
const persist=()=>{try{localStorage.setItem(KEY,JSON.stringify(state));}catch(e){}};
const note='<div class="tca-demo" role="note">معاينة Frontend محلية فقط: الوكلاء، الصلاحيات، الأرصدة، الرسائل والعمليات هنا تجريبية. لا توجد مدفوعات أو تحويل كونزات حقيقية.</div>';
const btn=(label,action,value='',cls='')=>'<button type="button" class="tca-btn '+cls+'" data-tca="'+E(action)+'" data-id="'+E(value)+'">'+label+'</button>';
const title=(v,small='')=>'<div class="tca-heading"><h3>'+v+'</h3>'+(small?'<span>'+small+'</span>':'')+'</div>';
const panel=v=>'<section class="tca-card">'+v+'</section>';
const line=(label,value)=>'<div class="tca-line"><span>'+label+'</span><strong>'+value+'</strong></div>';
const stateText={waiting:'بانتظار قبول الوكيل',payment:'بانتظار الدفع',paid:'تم الإبلاغ عن الدفع',review:'قيد مراجعة الدعم',done:'مكتمل · معاينة',cancelled:'ملغى'};
const now=()=>Date.now();
const orderBy=id=>state.orders.find(o=>o.id===id);
const agentBy=id=>demoAgents.find(a=>a.id===id);
const badge=s=>'<span class="tca-badge">'+E(s)+'</span>';
const saveRender=()=>{persist();render();};
const notify=t=>{showToast(t);};
function countDown(t){let secs=Math.max(0,Math.ceil((t-now())/1000));return String(Math.floor(secs/60)).padStart(2,'0')+':'+String(secs%60).padStart(2,'0');}
function expired(o){if(o.status==='waiting'&&now()-o.created>=900000){o.status='cancelled';o.history.push('انتهت مهلة قبول الوكيل');return true;}
if(o.status==='payment'&&now()-(o.accepted||o.created)>=900000){o.status='cancelled';o.history.push('انتهت مهلة الدفع قبل الإبلاغ');return true;}
if(o.status==='paid'&&now()-(o.paidAt||o.created)>=900000){o.status='review';o.history.push('تصعيد تلقائي للدعم بعد 15 دقيقة');return true;}return false;}
function updateDeadlines(){let changed=false;state.orders.forEach(o=>{if(expired(o))changed=true});if(changed)persist();}
function staffAssigned(){const active=state.staff.filter(s=>s.enabled&&s.shift==='on');if(active.length===0)return 'الوكيل الرئيسي';const tally={};state.orders.filter(o=>o.status!=='done'&&o.status!=='cancelled').forEach(o=>{tally[o.assignee]=(tally[o.assignee]||0)+1});return active.slice().sort((a,b)=>(tally[a.name]||0)-(tally[b.name]||0))[0].name;}
function agentList(){
 const available=demoAgents.filter(a=>a.active&&a.online&&a.balance>=state.pack);
 return '<div class="tca-sheet" dir="rtl">'+title('اختيار وكيل الشحن','حزمة '+fmt(state.pack)+' كونز')+note+
 '<p class="tca-muted">يظهر الوكلاء المفعّلون الذين يملكون رصيداً كافياً فقط. هذه أسماء وأرصدة توضيحية للمعاينة.</p>'+
 (available.length?available.map(a=>panel('<div class="tca-agrow"><div class="tca-avatar">◈</div><div class="tca-flex"><b>'+E(a.name)+'</b><small>'+E(a.city)+' · وكيل تجريبي معتمد</small><small>★ '+E(a.rating)+' · '+fmt(a.count)+' تقييم</small></div>'+btn('اختيار','choose-agent',a.id,'small')+'</div>')).join(''):panel('ماكو وكلاء تجريبيين متاحين لهذه الحزمة حالياً.'))+
 '<div class="tca-actions">'+btn('طلباتي','go-section','orders','muted')+btn('إغلاق','close','','outline')+'</div></div>';
}
function chooseAgent(id){const a=agentBy(id);if(!a||!a.active||!a.online||a.balance<state.pack){notify('الوكيل غير متاح لهذه الحزمة');return;}
state.agent=id;persist();showSheet('<div class="tca-sheet" dir="rtl">'+title('تأكيد الطلب')+note+panel(line('الوكيل',E(a.name))+line('الكمية',fmt(state.pack)+' كونز')+line('السعر','حسب تسعيرة الإدارة — غير مهيّأ في المعاينة')+line('القبول','15 دقيقة')+line('إتمام الدفع بعد القبول','15 دقيقة'))+'<p class="tca-muted">لا تحوّل أي أموال بناءً على بيانات هذه المعاينة. يظهر حساب الدفع المعتمد فقط عند ربط الإدارة والنظام الحقيقي.</p>'+btn('إنشاء طلب تجريبي وفتح المحادثة','new-order',id,'wide')+btn('رجوع للوكلاء','agent-list','','outline wide')+'</div>',true);}
function createOrder(agentId){
 const agent=agentBy(agentId);
 if(!agent||agent.balance<state.pack)return notify('الوكيل ليس متاحاً الآن');
 const id='TC-'+String(now()).slice(-9);
 const o={id,agentId,qty:state.pack,uid:'7273804',status:'waiting',created:now(),accepted:null,paidAt:null,assignee:staffAssigned(),messages:[{by:'system',text:'تم إنشاء طلب الشحن. انتظر قبول الوكيل قبل الدفع.',at:now()}],history:['إنشاء طلب تجريبي'],rating:0};
 state.orders.unshift(o);state.selectedOrder=id;state.section='order';closeSheet();go('agencyDesk');persist();notify('تم إنشاء طلب محلي للتجربة، بدون أي دفع حقيقي');
}
const homeMenu=[
 ['طلبات الشحن','orders','📋'],['محادثات الشحن','chats','💬'],
 ['الشحن عبر User ID','direct','🪙'],['محفظة الوكالة','wallet','👛'],
 ['الموظفون والمشرفون','staff','👥'],['دوام الفريق','shifts','🕒'],
 ['الرواتب والمستحقات','payroll','💼'],['التقييمات','ratings','⭐'],
 ['الشكاوى والنزاعات','tickets','🛡️'],['التقارير والأداء','reports','📊'],
 ['الموافقات الإدارية','approvals','✅'],['حسابات الدفع','payments','🏦'],
 ['الانتقال والاستقالة','transfers','🔄'],['الاعتراضات والاستئناف','appeals','📝']
];
function overview(){
 return panel('<div class="tca-banner"><strong>مركز الوكالات</strong><small>واجهة موحّدة حسب الصلاحيات · لا تغيير في التصميم الأساسي للغرف</small></div>'+
 line('الدور التجريبي',E({user:'مستخدم',agent:'وكيل',supervisor:'مشرف',staff:'موظف',admin:'إدارة',owner:'مالك'}[state.role]||state.role))+
 (state.role==='user'?'<div class="tca-actions">'+btn('شراء كونزات','to-recharge')+btn('تقديم طلب وكالة','to-apply','','outline')+'</div>':line('طلبات الشحن في المعاينة',fmt(state.orders.length))))+
 '<div class="tca-grid">'+homeMenu.filter(x=>{
 if(state.role==='user')return ['orders','chats','ratings','tickets','approvals'].includes(x[1]);
 if(state.role==='staff')return !['wallet','staff','payroll','approvals','payments','reports'].includes(x[1]);
 if(state.role==='supervisor')return !['wallet','payroll','approvals','payments'].includes(x[1]);
 return true;
 }).map(x=>'<button class="tca-tile" data-tca="section" data-id="'+x[1]+'"><span>'+x[2]+'</span><b>'+x[0]+'</b><small>فتح القسم ←</small></button>').join('')+'</div>';
}
function orderList(){
 return title('طلبات الشحن','جميع الطلبات محفوظة محلياً')+
 panel('<div class="tca-actions">'+btn('شراء حزمة جديدة','to-recharge')+btn('تحديث الحالات','refresh','','outline')+'</div>')+
 (state.orders.length?state.orders.map(o=>panel(
 line('#'+E(o.id),badge(stateText[o.status]||o.status))+
 line('الكونزات',fmt(o.qty))+line('الوكيل',E(agentBy(o.agentId)?.name||'وكيل تجريبي'))+
 line('المسؤول',E(o.assignee))+((o.status==='waiting')?line('الوقت المتبقي',countDown(o.created+900000)):'')+
 ((o.status==='payment')?line('مهلة الدفع',countDown(o.accepted+900000)):'')+
 btn('فتح المحادثة وتفاصيل الطلب','open-order',o.id,'wide')
 )).join(''):panel('<div class="tca-empty">ماكو طلبات بعد. افتح المحفظة واختار حزمة حتى تبدأ التجربة.</div>'));
}
function orderScreen(o){
 const a=agentBy(o.agentId)||{name:'وكيل تجريبي'};
 const rows=o.messages.map(m=>'<div class="tca-msg '+(m.by==='user'?'mine':'')+'"><small>'+E(m.by==='user'?'المستخدم':m.by==='agent'?'الوكيل / الموظف':'النظام')+'</small><p>'+E(m.text)+'</p></div>').join('');
 let actions='';
 if(o.status==='waiting')actions=btn('قبول الطلب (محاكاة الوكيل)','accept',o.id)+btn('إلغاء قبل الدفع','cancel',o.id,'outline');
 if(o.status==='payment')actions=btn('تم الدفع (محاكاة فقط)','paid',o.id)+btn('إلغاء الطلب غير المدفوع','cancel',o.id,'outline');
 if(o.status==='paid')actions=btn('تأكيد استلام المبلغ وإتمام شحن تجريبي','complete',o.id)+btn('فتح شكوى','ticket',o.id,'outline');
 if(o.status==='review')actions=btn('متابعة المراجعة','ticket',o.id)+btn('إتمام المحاكاة بعد التحقق','complete',o.id,'outline');
 if(o.status==='cancelled')actions=btn('دفعت لكن انتهت المهلة','late',o.id)+btn('طلب جديد','to-recharge','','outline');
 if(o.status==='done')actions=btn('تقييم الوكالة','rate',o.id)+btn('عرض الإيصال','receipt',o.id,'outline');
 return title('محادثة شحن رسمية',E(o.id))+
 panel(line('الحالة',badge(stateText[o.status]))+line('الوكيل',E(a.name))+line('حزمة الكونزات',fmt(o.qty))+line('السعر','يحدده المالك من لوحة الإدارة')+
 line('المسؤول الحالي',E(o.assignee))+
 (o.status==='waiting'?line('وقت قبول الطلب',countDown(o.created+900000)):o.status==='payment'?line('وقت الدفع',countDown(o.accepted+900000)):o.status==='paid'?line('مهلة تصعيد الدعم',countDown(o.paidAt+900000)):'')+
 '<div class="tca-chat">'+rows+'</div><label class="tca-label" for="tca-message">رسالة خاصة مرتبطة بالطلب</label><div class="tca-compose"><input id="tca-message" maxlength="400" placeholder="اكتب رسالتك...">'+btn('إرسال','send',o.id)+'</div>'+
 '<div class="tca-actions">'+actions+'</div>'+
 (o.status==='payment'?'<p class="tca-muted">لا توجد تعليمات دفع حقيقية هنا. إثبات الدفع اختياري، وتسجيل الاستلام ضمن هذه المعاينة لا يحرك الأموال.</p><label class="tca-upload">إرفاق وصل تجريبي (اختياري)<input id="tca-receipt" type="file" accept="image/*"></label>':'')+
 '<div class="tca-actions">'+btn('إبلاغ عن مشكلة','ticket',o.id,'outline')+btn('قائمة الطلبات','section','orders','muted')+'</div>')+
 panel(title('سجل الطلب')+o.history.map(x=>'<div class="tca-history">'+E(x)+'</div>').join(''));
}
function staffScreen(){
 return title('الموظفون والمشرفون','تعيين بموافقة الإدارة')+note+
 panel('<label class="tca-label">User ID المراد تعيينه<input id="tca-staff-id" inputmode="numeric" placeholder="معرّف الموظف"></label>'+
 '<label class="tca-label">الوظيفة<select id="tca-staff-rank"><option value="staff">موظف شحن</option><option value="supervisor">مشرف وكالة</option></select></label>'+btn('إرسال طلب تعيين للإدارة','hire','','wide'))+
 state.staff.map(s=>panel(line('الموظف',E(s.name)+' · '+E(s.uid))+line('الرتبة',s.role==='supervisor'?'مشرف':'موظف')+
 line('الحالة',badge(s.enabled?'مفعّل':'موقوف'))+line('حد العملية',fmt(s.perTx))+line('الحد اليومي',fmt(s.daily))+
 '<div class="tca-actions">'+btn(s.enabled?'إيقاف فوري':'إعادة التفعيل','staff-toggle',s.id)+btn('طلب زيادة الصلاحيات','staff-request',s.id,'outline')+btn('طلب فصل','staff-dismiss',s.id,'outline')+'</div>')).join('')+
 (state.hires.length?panel(title('طلبات التعيين')+state.hires.map(h=>line(E(h.uid),badge(h.status))).join('')):'');
}
function shiftScreen(){
 return title('دوام فريق الوكالة')+panel(line('الوكالة',badge(state.agencyOnline?'متاح لاستقبال الطلبات':'غير متاح'))+
 btn(state.agencyOnline?'إيقاف استقبال الطلبات':'بدء استقبال الطلبات','toggle-agency','','wide'))+
 state.staff.map(s=>panel(line(E(s.name),badge({on:'على رأس العمل',break:'استراحة',off:'خارج الدوام'}[s.shift]||''))+
 '<div class="tca-actions">'+btn('على رأس العمل','shift',s.id+':on')+btn('استراحة','shift',s.id+':break','outline')+btn('خارج الدوام','shift',s.id+':off','muted')+'</div>')).join('');
}
function moneyScreen(){
 return title('محفظة الوكالة','رصيد المعاينة لا يمثل أموالاً')+
 panel(line('الرصيد التجريبي',fmt(state.coins)+' كونز')+line('الجهة الوحيدة المصرّح لها بالتعبئة','مالك TotiChat')+
 (state.role==='owner'?'<label class="tca-label">قيمة تعبئة تجريبية<input id="tca-topup" type="number" min="1" max="1000000" value="100000"></label>'+btn('محاكاة تعبئة محفظة الوكالة','topup','','wide'):'<p class="tca-muted">تعبئة الرصيد مقصورة على المالك. هذا العرض لا ينفذ تعبئة حقيقية.</p>'));
}
function directScreen(){
 return title('شحن مباشر عبر User ID','صلاحية منفصلة وحدود مستقلة')+note+
 panel('<label class="tca-label">User ID<input id="tca-direct-id" inputmode="numeric" maxlength="15" placeholder="ID المستلم"></label>'+
 '<label class="tca-label">كمية الكونزات<input id="tca-direct-qty" type="number" min="1000" max="500000" placeholder="اختر حزمة أو كمية مخصصة"></label>'+
 '<div class="tca-actions">'+[4900,24500,49000].map(n=>btn(fmt(n),'direct-pack',String(n),'outline')).join('')+'</div>'+
 '<p class="tca-muted">السعر الرسمي يُحسب من إعدادات الإدارة عند الربط؛ لا تظهر أسعار مفترضة كأنها معتمدة. العمليات هنا للتجربة فقط.</p>'+
 btn('التحقق من المستلم ومعاينة العملية','direct-check','','wide'));
}
function payrollScreen(){
 return title('الرواتب والمستحقات','مسؤولية الوكيل وليس محفظة الكونزات')+note+
 panel('<label class="tca-label">معرّف الموظف<input id="tca-pay-id" placeholder="S-1001" value="S-1001"></label>'+
 '<label class="tca-label">الراتب / المبلغ المسجل بالدينار<input id="tca-pay-amount" type="number" min="1" placeholder="مثال 400000"></label>'+
 btn('إنشاء كشف مستحقات محلي','pay-add','','wide'))+
 (state.payroll.length?state.payroll.map(p=>panel(line('كشف '+E(p.id),badge(p.confirmed?'استلام مؤكد':p.disputed?'نزاع لدى الإدارة':'بانتظار التأكيد'))+
 line('الموظف',E(p.staff))+line('المبلغ',fmt(p.amount)+' د.ع')+
 '<div class="tca-actions">'+btn('تأكيد استلام الموظف','pay-confirm',p.id)+btn('الاعتراض على الراتب','pay-dispute',p.id,'outline')+'</div>')).join(''):panel('ماكو كشوف تجريبية بعد. الموظف يحتفظ بحق الاعتراض حتى بعد الفصل.'));
}
function ratingsScreen(){
 return title('تقييمات الوكالة','معدل علني · أداء الموظفين داخلي')+
 panel(line('تقييم الوكالة الافتراضي','★ 4.8 / 5')+line('تقييمات مؤهلة داخل المعاينة',fmt(state.ratings.length))+
 '<p class="tca-muted">التقييم مسموح مرة واحدة لكل عملية شراء مكتملة وموثقة. يمكن للمشتري تعديل تقييمه ويُحفظ تاريخ التعديل.</p>')+
 (state.ratings.length?state.ratings.map(r=>panel(line('معاملة',E(r.order))+line('تقييم العميل','★ '+r.stars)+
 '<p>'+E(r.comment||'بدون تعليق')+'</p>'+
 (r.reply?'<div class="tca-history">رد الوكالة: '+E(r.reply)+'</div>':'')+
 '<label class="tca-label">رد الوكالة الرسمي<input id="tca-reply-'+E(r.order)+'" placeholder="رد دون بيانات شخصية"></label>'+btn('حفظ الرد','reply',r.order))).join(''):panel('لا توجد تقييمات من عمليات المعاينة بعد.'));
}
function complaintsScreen(){
 return title('الشكاوى والنزاعات','شكاوى مالية أو مخالفات سلوك')+
 panel('<label class="tca-label">نوع البلاغ<select id="tca-ticket-type"><option>مشكلة عملية شحن</option><option>مخالفة أو سلوك الوكيل</option><option>نزاع رواتب</option><option>اعتراض على قرار</option></select></label>'+
 '<label class="tca-label">وصف المشكلة<textarea id="tca-ticket-body" rows="3" placeholder="اشرح المشكلة بدون نشر بيانات حساسة"></textarea></label>'+
 btn('تقديم البلاغ للإدارة (معاينة)','submit-ticket','','wide'))+
 (state.tickets.length?state.tickets.map(t=>panel(line('بلاغ '+E(t.id),badge(t.status))+line('النوع',E(t.type))+'<p>'+E(t.body)+'</p>')).join(''):panel('لا توجد بلاغات محلية.'));
}
function approvalsScreen(){
 return title('طلبات الاعتماد والموافقات')+note+
 (state.hires.length?state.hires.map(h=>panel(line('طلب '+E(h.uid),badge(h.status))+line('الوظيفة',h.role==='supervisor'?'مشرف':'موظف')+
 (state.role==='admin'||state.role==='owner'?'<div class="tca-actions">'+btn('موافقة تجريبية','hire-approve',h.id)+btn('رفض','hire-reject',h.id,'outline')+'</div>':''))).join(''):panel('لا توجد طلبات تعيين تجريبية.'))+
 panel('إضافة وتغيير وسائل استلام الأموال يحتاج موافقة المالك النهائية، وتعبئة محفظة الوكالة حصرية للمالك.');
}
function paymentsScreen(){return title('وسائل دفع الوكالة')+panel(
 '<p>تحدد إدارة TotiChat وحدها وسائل الدفع وحسابات الاستلام لكل وكيل، ويوافق المالك نهائياً على تعديلها.</p>'+
 '<p class="tca-muted">لا نعرض أي أرقام مالية تجريبية يمكن أن يخطئ المستخدم ويحوّل إليها المال.</p>'+btn('مراجعة الموافقات','section','approvals','wide'));}
function transfersScreen(){return title('النقل والاستقالة')+
 panel('<p>الموظف يرتبط بوكالة واحدة فقط. الانتقال يوقف صلاحيات الشحن فوراً، ويبدأ مراجعة إدارية خلال 24 ساعة، ثم يُصعّد للمالك.</p>'+
 '<div class="tca-actions">'+btn('طلب نقل وكالة','transfer')+btn('استقالة مباشرة','resign','','outline')+'</div>')+
 panel('استحقاقات الموظف محفوظة حتى بعد إنهاء الارتباط. إعادة التعيين تتطلب طلباً جديداً وموافقة الإدارة والموظف، دون استعادة الصلاحيات القديمة تلقائياً.');
}
function appealScreen(){return title('الاعتراضات والاستئناف')+
 panel('<p>القرارات الأولية تصدر من الإداري المخوّل، ويحق للموظف والوكيل الاستئناف أمام المالك خلال 7 أيام، أو طلب إعادة فتح القضية لأدلة جديدة.</p>'+
 '<label class="tca-label">سبب الاستئناف<textarea id="tca-appeal" placeholder="تفاصيل الاستئناف والأدلة" rows="3"></textarea></label>'+btn('تسجيل استئناف تجريبي','appeal','','wide')); }
function reportsScreen(){
 const done=state.orders.filter(o=>o.status==='done');
 return title('التقارير والأداء','لوحة تشغيلية داخلية')+
 panel(line('طلبات مكتملة',fmt(done.length))+line('طلبات مفتوحة',fmt(state.orders.filter(o=>!['done','cancelled'].includes(o.status)).length))+
 line('شكاوى محلية',fmt(state.tickets.length))+line('عدد الموظفين',fmt(state.staff.length)))+
 panel('<p class="tca-muted">تقارير الأداء الفردية سرية، وبيانات الرواتب لا تظهر للمشرفين. لا يمكن استنتاج أرباح فعلية من بيانات المعاينة.</p>');
}
function view(){
 updateDeadlines();
 let body=note;
 const roles=[['user','مستخدم'],['agent','وكيل'],['staff','موظف'],['supervisor','مشرف'],['admin','إداري'],['owner','مالك']];
 body+='<div class="tca-role"><label for="tca-role">عرض واجهة الدور (للمراجعة فقط)</label><select id="tca-role" aria-label="تبديل الدور للمعاينة">'+roles.map(r=>'<option value="'+r[0]+'" '+(state.role===r[0]?'selected':'')+'>'+r[1]+'</option>').join('')+'</select></div>';
 if(state.section!=='overview')body+='<div class="tca-backbar">'+btn('‹ مركز الوكالات','section','overview','outline')+'</div>';
 const pages={overview,orders:orderList,chats:orderList,direct:directScreen,wallet:moneyScreen,staff:staffScreen,shifts:shiftScreen,payroll:payrollScreen,ratings:ratingsScreen,tickets:complaintsScreen,reports:reportsScreen,approvals:approvalsScreen,payments:paymentsScreen,transfers:transfersScreen,appeals:appealScreen};
 if(state.section==='order')body+=orderScreen(orderBy(state.selectedOrder)||state.orders[0]||{id:'-',agentId:'',qty:0,status:'cancelled',history:[],messages:[],assignee:'-'});
 else body+=(pages[state.section]||overview)();
 return page('مركز الوكالات', '<main class="tca-root" dir="rtl">'+body+'</main>');
}
const previousRender=render;
render=function(){
 if(screen==='agencyDesk'){
  document.getElementById('app').innerHTML=view();
  document.body.style.background='#edf6ef';
  document.documentElement.classList.remove('in-room');
  window.scrollTo(0,0);
 } else previousRender();
};
const originalAgency=vAgency;
vAgency=function(){
 const html=originalAgency();
 return html.replace('<main class="ag-screen">','<main class="ag-screen"><div class="tca-hub-entry">'+btn('فتح مركز الوكالات وإدارة الشحن والموظفين','hub','','wide')+'</div>');
};
function rechargePatch(){
 const previous=vRecharge;
 vRecharge=function(){
  return previous().replace(/سعر عرض: \$[0-9.]+/g,'السعر الرسمي بعد ربط الإدارة').replace('تأكيد الشحن — عرض فقط','اختيار وكيل الشحن');
 };
}
rechargePatch();
function openDesk(section='overview'){state.section=section;saveRender();if(screen!=='agencyDesk')go('agencyDesk');else render();}
function askRate(o){
 showSheet('<div class="tca-sheet" dir="rtl">'+title('تقييم عملية الشحن')+note+
 panel(line('المعاملة',E(o.id))+'<label class="tca-label">التقييم من 1 إلى 5<select id="tca-stars">'+[5,4,3,2,1].map(n=>'<option value="'+n+'" '+(n===o.rating?'selected':'')+'>'+n+' ★</option>').join('')+'</select></label>'+
 '<label class="tca-label">التعليق<textarea id="tca-rating-note" rows="3" placeholder="كيف كانت تجربة الشحن؟">'+E(state.ratings.find(r=>r.order===o.id)?.comment||'')+'</textarea></label>'+btn('حفظ التقييم التجريبي','rate-save',o.id,'wide'))+'</div>',true);
}
function displayReceipt(o){
 showSheet('<div class="tca-sheet" dir="rtl">'+title('إيصال شحن تجريبي')+note+
 panel(line('رقم العملية',E(o.id))+line('حالة الشحن',E(stateText[o.status]))+line('المستلم','7273804')+line('الوكالة',E(agentBy(o.agentId)?.name||''))+
 line('الكونزات',fmt(o.qty))+'<p class="tca-muted">لا يعد هذا إثبات دفع أو تحويل رصيد حقيقي.</p>')+btn('إغلاق','close','','wide')+'</div>',true);
}
function handleClick(e){
 const el=e.target.closest('[data-tca], [data-a="chargePick"],[data-a="sheet"][data-v="rechargeSummary"]');
 if(!el)return;
 const a=el.dataset.tca|| (el.dataset.a==='chargePick'?'select-pack':'agent-list'),id=el.dataset.id||el.dataset.v||'';
 e.preventDefault();e.stopImmediatePropagation();
 if(a==='select-pack'){
  const idx=Number(id);state.pack=packs[idx]||packs[0];vt.chargePack=idx;persist();showSheet(agentList(),true);return;
 }
 if(a==='agent-list'){showSheet(agentList(),true);return;}
 if(a==='choose-agent'){chooseAgent(id);return;}
 if(a==='new-order'){createOrder(id);return;}
 if(a==='close'){closeSheet();return;}
 if(a==='hub'){closeSheet();openDesk();return;}
 if(a==='section'||a==='go-section'){closeSheet();openDesk(id);return;}
 if(a==='to-recharge'){closeSheet();go('rechargePreview');return;}
 if(a==='to-apply'){closeSheet();go('agencyApply');return;}
 if(a==='refresh'){updateDeadlines();render();return;}
 if(a==='open-order'){state.selectedOrder=id;openDesk('order');return;}
 if(a==='direct-pack'){const q=document.getElementById('tca-direct-qty');if(q)q.value=id;return;}
 if(a==='direct-check'){
  const uid=(document.getElementById('tca-direct-id')?.value||'').trim();
  const qty=Number(document.getElementById('tca-direct-qty')?.value||0);
  if(!/^[0-9]{4,15}$/.test(uid)||!Number.isSafeInteger(qty)||qty<1000||qty>500000){notify('تحقق من User ID والكمية (1,000–500,000)');return;}
  if(qty>state.coins){notify('الرصيد التجريبي غير كافٍ');return;}
  showSheet('<div class="tca-sheet" dir="rtl">'+title('تأكيد المستلم')+note+panel(line('ID',E(uid))+line('الاسم والصورة','يتطلبان استعلام حساب حقيقي من الـBackend')+line('الكمية',fmt(qty)+' كونز')+
  '<p class="tca-muted">لحماية المستخدم، لا ننفّذ حتى التحويل التجريبي قبل وجود تأكيد هوية حقيقي؛ هذه شاشة مراجعة فقط.</p>')+btn('فهمت','close','','wide')+'</div>',true);return;
 }
 if(a==='toggle-agency'){state.agencyOnline=!state.agencyOnline;saveRender();return;}
 if(a==='topup'){if(state.role!=='owner')return notify('محاكاة التعبئة متاحة في واجهة المالك فقط');const n=Number(document.getElementById('tca-topup')?.value);if(!Number.isSafeInteger(n)||n<=0||n>1000000)return notify('كمية غير صالحة');state.coins+=n;saveRender();notify('تم تحديث رصيد المعاينة فقط');return;}
 if(a==='hire'){
  if(!['agent','owner','admin'].includes(state.role))return notify('الطلب يحتاج حساب الوكيل');
  const uid=(document.getElementById('tca-staff-id')?.value||'').trim();
  const rank=document.getElementById('tca-staff-rank')?.value||'staff';
  if(!/^[0-9]{4,15}$/.test(uid))return notify('أدخل User ID صحيح');
  if(state.staff.some(s=>s.uid===uid)||state.hires.some(h=>h.uid===uid&&h.status==='قيد المراجعة'))return notify('هذا الموظف موجود أو لديه طلب');
  state.hires.unshift({id:'H-'+now(),uid,role:rank,status:'قيد المراجعة'});saveRender();notify('تم إنشاء طلب تعيين تجريبي للمراجعة');return;
 }
 if(a==='hire-approve'||a==='hire-reject'){
  if(!['admin','owner'].includes(state.role))return notify('للموافقة الإدارية فقط');
  const h=state.hires.find(h=>h.id===id);if(!h)return;
  if(h.status!=='قيد المراجعة')return notify('الطلب محسوم');
  h.status=a==='hire-approve'?'مقبول تجريبياً':'مرفوض';
  if(a==='hire-approve')state.staff.push({id:'S-'+now(),uid:h.uid,name:'موظف '+h.uid,role:h.role,shift:'off',enabled:false,perTx:0,daily:0});
  saveRender();return;
 }
 if(a==='staff-toggle'||a==='staff-request'||a==='staff-dismiss'){
  const s=state.staff.find(x=>x.id===id);if(!s)return;
  if(a==='staff-toggle'){s.enabled=!s.enabled;saveRender();return;}
  if(a==='staff-request'){state.hires.unshift({id:'H-'+now(),uid:s.uid,role:s.role,status:'قيد المراجعة',type:'زيادة صلاحيات'});saveRender();notify('طلب تعديل الصلاحيات قيد المراجعة');return;}
  state.hires.unshift({id:'H-'+now(),uid:s.uid,role:s.role,status:'قيد المراجعة',type:'فصل موظف'});s.enabled=false;saveRender();return;
 }
 if(a==='shift'){const [sid,v]=id.split(':');const s=state.staff.find(x=>x.id===sid);if(!s)return;s.shift=v;saveRender();return;}
 if(a==='pay-add'){
  if(!['agent','owner','admin'].includes(state.role))return notify('إدارة الرواتب للوكيل والإدارة');
  const staff=(document.getElementById('tca-pay-id')?.value||'').trim();
  const amount=Number(document.getElementById('tca-pay-amount')?.value);
  if(!staff||!Number.isSafeInteger(amount)||amount<1)return notify('أكمل بيانات الراتب');
  state.payroll.unshift({id:'P-'+now(),staff,amount,confirmed:false,disputed:false});saveRender();return;
 }
 if(a==='pay-confirm'||a==='pay-dispute'){
  const p=state.payroll.find(x=>x.id===id);if(!p)return;
  if(a==='pay-confirm'){p.confirmed=true;p.disputed=false;}else{p.confirmed=false;p.disputed=true;state.tickets.unshift({id:'T-'+now(),type:'نزاع رواتب',body:'اعتراض على كشف '+p.id,status:'قيد مراجعة الإدارة'})}
  saveRender();return;
 }
 if(a==='submit-ticket'){const type=document.getElementById('tca-ticket-type')?.value||'';const body=(document.getElementById('tca-ticket-body')?.value||'').trim();if(body.length<8)return notify('اكتب تفاصيل كافية');state.tickets.unshift({id:'T-'+now(),type,body,status:'قيد مراجعة الإدارة'});saveRender();return;}
 if(a==='transfer'||a==='resign'||a==='appeal'){let input=a==='appeal'?(document.getElementById('tca-appeal')?.value||'').trim():'';if(a==='appeal'&&input.length<8)return notify('اكتب أسباب الاستئناف');state.tickets.unshift({id:'T-'+now(),type:a==='transfer'?'طلب انتقال':a==='resign'?'استقالة':'استئناف',body:input||'طلب مقدم من الموظف، يحتفظ بجميع مستحقاته.',status:'قيد مراجعة الإدارة'});if(a==='transfer'||a==='resign')state.staff.forEach(s=>s.enabled=false);saveRender();return;}
 const o=orderBy(id);
 if(!o)return;
 if(a==='send'){const input=document.getElementById('tca-message');const value=(input?.value||'').trim();if(!value)return notify('اكتب رسالة');o.messages.push({by:state.role==='user'?'user':'agent',text:value.slice(0,400),at:now()});o.history.push('رسالة جديدة محفوظة بالمعاينة');saveRender();return;}
 if(a==='accept'){if(o.status!=='waiting')return;o.status='payment';o.accepted=now();o.history.push('قبول الوكيل في المعاينة');saveRender();return;}
 if(a==='cancel'){if(!['waiting','payment'].includes(o.status))return;o.status='cancelled';o.history.push('إلغاء طلب لم يبلّغ عن دفعه');saveRender();return;}
 if(a==='paid'||a==='late'){if(a==='paid'&&o.status!=='payment')return;if(a==='late'&&o.status!=='cancelled')return;o.status=a==='late'?'review':'paid';o.paidAt=now();o.history.push(a==='late'?'إبلاغ متأخر عن الدفع ومراجعة الدعم':'إبلاغ عن الدفع (تجريبي)');saveRender();return;}
 if(a==='complete'){if(!['paid','review'].includes(o.status))return;/* No actual wallet mutation */
 o.status='done';o.history.push('إغلاق الطلب داخل المعاينة فقط — لا تحويل كونزات حقيقي');saveRender();notify('نجحت محاكاة الواجهة فقط، دون تحويل أي رصيد');return;}
 if(a==='ticket'){state.tickets.unshift({id:'T-'+now(),type:'مشكلة عملية شحن',body:'طلب '+o.id+' يحتاج مراجعة',status:'قيد مراجعة الإدارة'});openDesk('tickets');return;}
 if(a==='receipt'){displayReceipt(o);return;}
 if(a==='rate'){askRate(o);return;}
 if(a==='rate-save'){
  const stars=Number(document.getElementById('tca-stars')?.value||0);
  if(o.status!=='done'||stars<1||stars>5)return notify('التقييم متاح فقط لعملية مؤهلة مكتملة');
  const comment=(document.getElementById('tca-rating-note')?.value||'').trim().slice(0,350);
  let r=state.ratings.find(r=>r.order===id);
  if(r){r.history=r.history||[];r.history.push({stars:r.stars,comment:r.comment});r.stars=stars;r.comment=comment;}
  else state.ratings.push({order:id,stars,comment,history:[],reply:''});
  o.rating=stars;persist();closeSheet();render();return;
 }
 if(a==='reply'){const r=state.ratings.find(x=>x.order===id);if(!r)return;r.reply=(document.getElementById('tca-reply-'+id)?.value||'').trim().slice(0,400);saveRender();return;}
}
document.addEventListener('click',handleClick,true);
document.addEventListener('change',e=>{if(e.target.id==='tca-role'){state.role=e.target.value;state.section='overview';saveRender();}});
const oldOnGo=go;
const query=new URLSearchParams(location.search);
if(query.get('view')==='agency-center')openDesk(query.get('section')||'overview');
window.TotiChatAgencyDemo=Object.freeze({openCenter:openDesk,getSummary:()=>({orders:state.orders.length,tickets:state.tickets.length,staff:state.staff.length}),version:'2.0-ui-only'});
setInterval(()=>{if(screen==='agencyDesk'&&state.section==='order'){const o=orderBy(state.selectedOrder);if(o&&['waiting','payment','paid'].includes(o.status)){if(expired(o)){persist();render();}else document.querySelectorAll('.tca-line strong').forEach(el=>{if(el.previousElementSibling?.textContent?.includes('وقت')||el.previousElementSibling?.textContent?.includes('مهلة'))el.textContent=countDown((o.status==='waiting'?o.created:o.status==='payment'?o.accepted:o.paidAt)+900000);});}}},1000);
})();