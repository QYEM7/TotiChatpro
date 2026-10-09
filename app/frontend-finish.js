/* TotiChat frontend finishing pass. UI demo only: never process credentials/payments/coins. */
(function(){
'use strict';
const H=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const S={social:'friends',socialQuery:'',catalog:'all',catalogQuery:'',bag:'frames',alerts:'all',help:'faq',report:'bug',search:'',section:'overview'};
const note='<div class="fc-note" role="note">معاينة Frontend: المحتوى توضيحي ولم تُرسل بيانات أو مدفوعات أو تغييرات للحساب الحقيقي.</div>';
const btn=(t,a,v='',style='primary')=>'<button type="button" class="fc-btn fc-'+style+'" data-fc="'+a+'" data-v="'+H(v)+'">'+t+'</button>';
const head=(title,subtitle)=>'<div class="fc-heading"><h3>'+title+'</h3>'+(subtitle?'<small>'+subtitle+'</small>':'')+'</div>';
const card=(html,cls='')=>'<section class="fc-card '+cls+'">'+html+'</section>';
const tabs=(items,key,action)=>'<div class="fc-tabs">'+items.map(([v,n])=>'<button type="button" class="fc-tab '+(key===v?'active':'')+'" data-fc="'+action+'" data-v="'+v+'">'+n+'</button>').join('')+'</div>';
const empty=(symbol,title,description)=>'<div class="fc-empty"><span>'+symbol+'</span><strong>'+title+'</strong><p>'+description+'</p></div>';
const banner=(icon,title,description)=>'<header class="fc-hero"><span class="fc-hero-icon">'+icon+'</span><div><small>✦ TOTICHAT</small><h2>'+title+'</h2><p>'+description+'</p></div></header>';
const field=(label,id,type='text',placeholder='',more='')=>'<label class="fc-field">'+label+'<input id="'+id+'" type="'+type+'" placeholder="'+H(placeholder)+'" '+more+'></label>';
const dest=(icon,title,detail,target)=>'<button type="button" data-a="go" data-v="'+target+'" class="fc-row"><span class="fc-row-icon">'+icon+'</span><span><b>'+title+'</b><small>'+detail+'</small></span><i>‹</i></button>';
const view=(title,body)=>page(title,'<div class="fc-page" dir="rtl">'+body+'</div>');
const search=(id,hint,value)=>'<label class="fc-search"><span>⌕</span><input id="'+id+'" type="search" placeholder="'+hint+'" value="'+H(value)+'" autocomplete="off"></label>';
const sections=[
 ['all','الكل'],['frames','الإطارات'],['vehicles','المركبات'],['bubbles','الفقاعات'],
 ['effects','تأثيرات الدخول'],['badges','الشارات'],['cp','CP']
];
const products=[
 {id:'f1',name:'إطار نجمة الليل',tag:'frames',art:'🌠',desc:'إطار مضيء لصورة الحساب والغرفة'},
 {id:'f2',name:'إطار الزهور',tag:'frames',art:'🌺',desc:'إطار بتفاصيل ورود ناعمة'},
 {id:'v1',name:'المركبة الوردية',tag:'vehicles',art:'🏎️',desc:'مؤثر دخول قابل للتجهيز'},
 {id:'b1',name:'فقاعة القلوب',tag:'bubbles',art:'💌',desc:'فقاعة مميزة لرسائل الغرفة'},
 {id:'e1',name:'فراشات لامعة',tag:'effects',art:'🦋',desc:'تأثير دخول احتفالي'},
 {id:'g1',name:'نجمة التميز',tag:'badges',art:'🏅',desc:'شارة تتطلب استحقاقاً من الخادم'},
 {id:'c1',name:'علاقة الأصدقاء',tag:'cp',art:'💞',desc:'إطار علاقة حسب مستوى CP'}
];
function authPage(type){
 const signup=type==='signupPreview',reset=type==='passwordResetPreview',verify=type==='verifyAccountPreview';
 const title=signup?'إنشاء حساب جديد':reset?'استعادة كلمة المرور':verify?'تأكيد الحساب':'تسجيل الدخول';
 let form='';
 if(signup)form+=field('اسم المستخدم','fc-name','text','الاسم الذي سيظهر في التطبيق','autocomplete="nickname" maxlength="35"');
 if(!verify)form+=field('البريد الإلكتروني','fc-email','email','example@email.com','autocomplete="email"');
 if(!reset&&!verify)form+=field('كلمة المرور','fc-pass','password','ثمانية أحرف على الأقل','autocomplete="'+(signup?'new-password':'current-password')+'"');
 if(signup)form+=field('تأكيد كلمة المرور','fc-confirm','password','أعد كتابة كلمة المرور','autocomplete="new-password"');
 if(verify)form+=field('رمز تأكيد الحساب','fc-code','text','ستة أرقام','inputmode="numeric" maxlength="6"');
 if(signup)form+='<label class="fc-consent"><input type="checkbox" id="fc-terms"> أوافق على الشروط وسياسة الخصوصية عند تفعيلهما</label>';
 form+='<div class="fc-form-error" id="fc-form-status" role="status" aria-live="polite"></div>'+btn(signup?'مراجعة بيانات التسجيل':reset?'مراجعة الاستعادة':verify?'التحقق من الرمز':'مراجعة تسجيل الدخول','validate-auth',type,'wide');
 return view(title,banner('💗',title,signup?'ابدأ رحلتك في غرف TotiChat':reset?'واجهة استرداد الحساب قبل الربط':verify?'التحقق الحقيقي يتطلب خادم المصادقة':'أهلاً بعودتك إلى عالم TotiChat')+
 card(form+dest('🔐',signup||verify||reset?'عندي حساب':'إنشاء حساب','انتقل إلى المسار المناسب',signup||verify||reset?'loginPreview':'signupPreview')+
 (!reset&&!signup&&!verify?dest('🔑','نسيت كلمة المرور','استرجاع الوصول للحساب','passwordResetPreview'):'') )+
 card(head('خصوصية وأمان','نقطة ربط Backend')+'<p>لا نرسل كلمات المرور من هذه المعاينة ولا نحفظها. عند التكامل ستُفعّل المصادقة والتحقق من البريد ومعدلات المحاولات.</p>')+note);
}
function friendPage(){
 const kinds=[['friends','الأصدقاء'],['followers','المتابعون'],['following','أتابعهم'],['visitors','الزوار'],['requests','الطلبات']];
 const demo=[['خولة','female','friends'],['ريان','male','friends'],['شهد','female','followers'],['محمد','prince','following']];
 const filtered=demo.filter(a=>a[2]===S.social&&a[0].includes(S.socialQuery));
 const content=S.social==='requests'?empty('✉','طلبات الصداقة','تظهر هنا الطلبات المستلمة والمرسلة بعد ربط الحسابات'):
 filtered.length?filtered.map(a=>card('<div class="fc-person">'+im(a[1],'class="fc-avatar" alt=""')+'<span><b>'+a[0]+'</b><small>حساب توضيحي في المعاينة</small></span>'+btn('عرض','person-info',a[0],'soft')+'</div>')).join(''):
 empty('🔎','لا توجد نتائج','ابحث عن اسم مختلف أو غيّر تبويب الأصدقاء');
 return view('الأصدقاء',banner('🫶','الأصدقاء والمتابعة','العلاقات والبحث وطلبات الصداقة في مكان واحد')+
 tabs(kinds,S.social,'social-tab')+search('fc-social-q','بحث بالاسم أو ID',S.socialQuery)+
 card(content)+card(dest('🔎','اكتشف أشخاصاً','بحث وتصفية الأعضاء','searchPreview')+
 dest('💬','الرسائل','افتح المحادثات الرسمية','messages')+dest('🚫','المحظورون','إدارة قائمة الحظر','block'))+note);
}
function bagPage(){
 return view('الحقيبة',banner('🎒','مقتنياتك','الملكية والتجهيز وإزالة التجهيز من نفس المكان')+
 tabs(sections.slice(1),S.bag,'bag-tab')+
 card(empty('✨','ماكو مقتنيات فعلية محمّلة','عند اتصال Backend تظهر المقتنيات المملوكة، زر تجهيز/إزالة، وتاريخ صلاحيتها.')+
 btn('استعراض فئة المقتنيات','bag-browse',S.bag,'wide'))+
 card(dest('🛍️','المتجر','الإطارات والمؤثرات','storePreview')+
 dest('👑','امتيازات VIP','إطارات وشارات المستويات','vip')+
 dest('💞','علاقة CP','العلاقات والمكافآت','cp'))+note);
}
function storePage(){
 const choices=products.filter(p=>(S.catalog==='all'||p.tag===S.catalog)&&p.name.includes(S.catalogQuery));
 return view('متجر TotiChat',banner('🛍️','متجر الزينة','إطارات ومركبات وفقاعات وحركات دخول مميزة')+
 tabs(sections,S.catalog,'store-tab')+search('fc-store-q','ابحث عن عنصر...',S.catalogQuery)+
 card('<div class="fc-kv"><span>🪙 رصيدك</span><b>بانتظار Backend</b></div><p>الأسعار الفعلية والملكية والمخزون لا تُحَدَّد محلياً. زر التفاصيل لا يخصم الرصيد.</p>')+
 (choices.length?'<div class="fc-products">'+choices.map(p=>'<button type="button" data-fc="product" data-v="'+p.id+'" class="fc-product"><span class="fc-product-art">'+p.art+'</span><b>'+p.name+'</b><small>'+p.desc+'</small><i>عرض التفاصيل ‹</i></button>').join('')+'</div>':card(empty('⌕','لا توجد نتائج','غيّر كلمة البحث أو التصنيف')))+
 card(dest('🎒','الحقيبة','المقتنيات المملوكة والمجهزة','bagPreview'))+note);
}
function alertPage(){
 const filters=[['all','الكل'],['system','النظام'],['gifts','الهدايا'],['friends','الأصدقاء'],['agency','الوكالات']];
 return view('الإشعارات',banner('🔔','مركز الإشعارات','تنبيهات الحساب والغرف والمعاملات')+
 tabs(filters,S.alerts,'alert-tab')+
 card(empty('🔕','لا توجد إشعارات فعلية','ستظهر الإشعارات بعد ربط خدمة الأحداث مع التمييز بين المقروء وغير المقروء.'))+
 card(dest('💬','رسائل النظام','عرض محادثات الدعم والإشعارات','messages')+
 dest('👥','الأصدقاء','طلبات الصداقة والمتابعة','friendsPreview')+
 dest('👛','الوكالات','حالة الوكيل وطلبات الشحن','agencyPreview'))+note);
}
function welcomePage(){
 return view('مكافأة الترحيب',banner('🎁','أهلاً بك في TotiChat','باقة ترحيبية مصممة، بدون منح وهمي للكوينز أو امتيازات VIP')+
 card('<div class="fc-reward">👑 💗 ✨</div>'+head('رحلتك تبدأ من هنا','المكافآت تتحدد من نظام الخادم')+
 '<p>عند تفعيل النظام تظهر شروط أهلية الحساب والمكافآت التي حصلت عليها، ووقت انتهاء صلاحيتها.</p>'+
 btn('معرفة شروط المكافأة','reward-info','','wide'))+
 card(dest('🏠','استكشف الغرف','استمع وتفاعل مع أصدقائك','home')+
 dest('🎒','حقيبتك','عرض ما تملكه فعلاً','bagPreview'))+note);
}
function helpPage(){
 const kinds=[['faq','الأسئلة'],['payments','الشحن'],['agency','الوكالات'],['privacy','الخصوصية']];
 const data={
 faq:[['كيف أدخل غرفة؟','من الرئيسية اختر الغرفة ثم اضغط دخول. الأذونات الصوتية تتطلب تشغيل التطبيق الفعلي.'],['كيف أراسل الدعم؟','من الرسائل اختر الدعم الفني الرسمي، أو انتقل إلى نموذج البلاغ.']],
 payments:[['متى أدفع للوكيل؟','فقط بعد قبول الطلب الرسمي وظهور تعليمات الاستلام المعتمدة داخل التطبيق.'],['إذا دفعت بعد انتهاء المهلة؟','قدّم بلاغ «دفعت لكن انتهت المهلة» مع رقم الطلب؛ لا يعني انتهاء الوقت سقوط حق المراجعة.']],
 agency:[['من يشحن الرصيد؟','المالك وحده يمول محفظة الوكيل؛ الوكيل يصرف الرصيد وفق الطلبات والصلاحيات.'],['هل يستطيع المشرف رؤية الرواتب؟','لا. الرواتب والعمولات سرية لدى الأطراف المخولة فقط.']],
 privacy:[['كيف أحمي بياناتي؟','لا تضع كلمات المرور أو بيانات الدفع الخاصة في المحادثات العامة.'],['هل هذه المعاينة حقيقية؟','لا. الوظائف المالية والمحادثات والأرصدة المعروضة في نموذج Frontend ليست معاملات حقيقية.']]
 };
 return view('مركز المساعدة',banner('🛟','الدعم والمساعدة','إجابات واضحة ومسارات استفسار قابلة للتوسعة')+
 tabs(kinds,S.help,'help-tab')+data[S.help].map(q=>card('<details class="fc-faq"><summary>'+q[0]+'</summary><p>'+q[1]+'</p></details>')).join('')+
 card(dest('📝','إرسال بلاغ','مشكلة تقنية أو إساءة استخدام','report')+
 dest('💬','الرسائل الرسمية','الدعم الفني داخل التطبيق','messages')+
 dest('⚙️','الإعدادات','الحساب والإشعارات','settings'))+note);
}
function searchPage(){
 const routes=[['غرف صوتية','room','🎙️'],['وكالات الشحن','agencyPreview','💰'],['المتجر','storePreview','🛍️'],['الأصدقاء','friendsPreview','👥'],['VIP','vip','👑'],['المهام','missionsPreview','🎯'],['الإشعارات','notificationsPreview','🔔']];
 const results=routes.filter(x=>x[0].includes(S.search));
 return view('البحث',banner('🔎','استكشف عالم TotiChat','ابحث عن الخدمات والغرف والأصدقاء')+
 search('fc-global-q','ابحث عن قسم أو خدمة',S.search)+
 card(head('نتائج البحث','نتائج أقسام المعاينة فقط')+(results.length?results.map(x=>dest(x[2],x[0],'فتح القسم',x[1])).join(''):empty('🔍','ماكو نتائج','البحث عن الحسابات والغرف الفعلية يحتاج Backend')))+note);
}
function privacyPage(){
 return view('أمان الحساب',banner('🛡️','الخصوصية والأمان','التحكم بالجلسات والحظر والأذونات')+
 card(dest('🔑','تغيير كلمة المرور','الاستعادة والتحقق','passwordResetPreview')+
 dest('🚫','الحظر والخصوصية','إدارة الأشخاص المحظورين','block')+
 dest('📜','مركز المساعدة','الشروط وسياسات الخصوصية','helpCenterPreview'))+
 card(empty('🔐','الجلسات والأجهزة','عرض وإلغاء جلسات الحساب يتطلب خدمة مصادقة حقيقية، ولا يمكن تزوير صلاحيات الأمان في المعاينة.'))+note);
}
function reportPage(){
 return view('تقديم بلاغ',banner('📝','نسمع صوتك','سجل المشكلة أو الإساءة بشكل منظّم')+
 card('<label class="fc-field">نوع البلاغ<select id="fc-report-type"><option value="bug">مشكلة تقنية</option><option value="safety">بلاغ إساءة</option><option value="purchase">عملية شحن أو دفع</option><option value="feedback">اقتراح تحسين</option></select></label>'+
 '<label class="fc-field">الشرح<textarea id="fc-report-text" rows="5" maxlength="1000" placeholder="اشرح المشكلة بوضوح..."></textarea></label>'+
 field('رقم الطلب أو الغرفة (اختياري)','fc-report-ref','text','مثال: TC-123456')+
 '<label class="fc-field">مرفقات اختيارية — صورة واحدة في المعاينة<input type="file" id="fc-report-attachment" accept="image/png,image/jpeg,image/webp"></label>'+
 '<p class="fc-form-error" id="fc-report-status" role="status" aria-live="polite"></p>'+
 btn('مراجعة البلاغ قبل الإرسال','report-review','','wide'))+
 card('<p>لن تُرسل ملاحظتك إلى الإدارة من هذه المعاينة. بعد ربط Backend ستحتاج المنصة إلى رقم بلاغ، تأكيد الاستلام، متابعة الحالة، ورفع مرفقات آمن.</p>')+note);
}
const previousMore=vMore,previousStore=vStore,previousRender=render;
vMore=function(id){
 if(id==='loginPreview'||id==='signupPreview'||id==='passwordResetPreview'||id==='verifyAccountPreview')return authPage(id);
 if(id==='friendsPreview')return friendPage();
 if(id==='bagPreview')return bagPage();
 if(id==='notificationsPreview')return alertPage();
 if(id==='welcomePreview')return welcomePage();
 return previousMore(id);
};
vStore=function(){return storePage()};
const extraRoutes={
 helpCenterPreview:()=>helpPage(),
 searchPreview:()=>searchPage(),
 accountSafetyPreview:()=>privacyPage(),
 report:()=>reportPage(),
 passwordResetPreview:()=>authPage('passwordResetPreview'),
 verifyAccountPreview:()=>authPage('verifyAccountPreview')
};
render=function(){
 if(Object.prototype.hasOwnProperty.call(extraRoutes,screen)){
  const host=document.getElementById('app');
  host.innerHTML=extraRoutes[screen]();
  host.classList.add('rf-app');host.classList.remove('rf-room','rf-royal-home');
  host.dataset.route=screen;
  document.documentElement.classList.remove('in-room');
  document.body.style.background='#fff9fc';window.scrollTo(0,0);
  return;
 }
 previousRender();
 if(screen==='settings'||screen==='me'){
  const main=document.querySelector('#app .main')||document.querySelector('#app .me-royal');
  if(main&&!main.querySelector('[data-fc-entry]')){
   const block=document.createElement('section');block.className='fc-entry';block.setAttribute('data-fc-entry','true');
   block.innerHTML='<b>✦ خدمات TotiChat</b><div class="fc-entry-grid">'+
     dest('🛟','مركز المساعدة','حلول واستفسارات','helpCenterPreview')+
     dest('🔒','أمان الحساب','التحقق والحماية','accountSafetyPreview')+
     dest('🔎','البحث','الغرف والخدمات','searchPreview')+'</div>';
   main.appendChild(block);
  }
 }
};
function sheetProduct(id){
 const p=products.find(x=>x.id===id);if(!p)return;
 showSheet('<div class="fc-sheet" dir="rtl">'+head(p.name)+note+
 card('<div class="fc-detail-art">'+p.art+'</div><p>'+H(p.desc)+'</p>'+
 '<div class="fc-kv"><span>السعر</span><b>يحدده Backend</b></div>'+
 '<div class="fc-kv"><span>الأهلية والملكية</span><b>تُفحص من حساب المستخدم</b></div>'+
 '<div class="fc-kv"><span>المعاينة</span><b>لا يوجد خصم أو شراء</b></div>')+
 btn('عرض الحقيبة','close-product-bag','','wide')+btn('إغلاق','close','','soft wide')+'</div>',true);
}
function msg(text,err=false,place='fc-form-status'){
 const el=document.getElementById(place);
 if(el){el.textContent=text;el.classList.toggle('is-error',err);}
 else showToast(text);
}
document.addEventListener('input',event=>{
 const el=event.target;
 const ids={'fc-social-q':['socialQuery'],'fc-store-q':['catalogQuery'],'fc-global-q':['search']};
 const x=ids[el.id];if(!x)return;
 const start=el.selectionStart,end=el.selectionEnd;
 S[x[0]]=el.value.slice(0,80);
 render();
 const fresh=document.getElementById(el.id);
 if(fresh){fresh.focus();try{fresh.setSelectionRange(start,end)}catch(e){}}
},true);
document.addEventListener('click',event=>{
 const el=event.target.closest('[data-fc]');if(!el)return;
 const a=el.dataset.fc,v=el.dataset.v||'';
 event.preventDefault();event.stopImmediatePropagation();
 if(a==='social-tab'){S.social=v;render();return}
 if(a==='store-tab'){S.catalog=v;render();return}
 if(a==='bag-tab'){S.bag=v;render();return}
 if(a==='alert-tab'){S.alerts=v;render();return}
 if(a==='help-tab'){S.help=v;render();return}
 if(a==='bag-browse'){S.catalog=v;go('storePreview');return}
 if(a==='product'){sheetProduct(v);return}
 if(a==='close-product-bag'){closeSheet();go('bagPreview');return}
 if(a==='close'){closeSheet();return}
 if(a==='person-info'){showSheet('<div class="fc-sheet">'+head('ملف '+H(v))+note+
  card('هذه شخصية توضيحية؛ لا يوجد User ID حقيقي أو طلب متابعة فعلي.')+
  btn('العودة','close','','wide')+'</div>',true);return}
 if(a==='reward-info'){showSheet('<div class="fc-sheet">'+head('شروط المكافآت')+note+
  card('تحدد الإدارة الأهلية وقيمة المكافأة وتاريخ انتهاء الصلاحية، ويمنع منح رصيد تجريبي باعتباره حقيقياً.')+
  btn('إغلاق','close','','wide')+'</div>',true);return}
 if(a==='validate-auth'){
  const email=(document.getElementById('fc-email')?.value||'').trim();
  const password=document.getElementById('fc-pass')?.value||'';
  const signup=v==='signupPreview',reset=v==='passwordResetPreview',verify=v==='verifyAccountPreview';
  if(verify)return msg(/^\d{6}$/.test(document.getElementById('fc-code')?.value||'')?'الرمز صحيح شكلياً؛ يتطلب التحقق الحقيقي خادم مصادقة.':'أدخل رمزاً من 6 أرقام.',!(/^\d{6}$/.test(document.getElementById('fc-code')?.value||'')));
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return msg('أدخل بريداً إلكترونياً صحيحاً.',true);
  if(!reset&&password.length<8)return msg('كلمة المرور يجب أن تحتوي 8 أحرف على الأقل.',true);
  if(signup){
   const name=(document.getElementById('fc-name')?.value||'').trim();
   if(name.length<2||name.length>35)return msg('اسم المستخدم يجب أن يكون 2–35 حرفاً.',true);
   if(password!==(document.getElementById('fc-confirm')?.value||''))return msg('كلمتا المرور غير متطابقتين.',true);
   if(!document.getElementById('fc-terms')?.checked)return msg('يلزم قبول الشروط قبل إنشاء الحساب الحقيقي.',true);
  }
  msg('البيانات مكتملة شكلياً. لا توجد جلسة تسجيل أو حساب أُنشئ؛ ينتظر ربط Backend.',false);return;
 }
 if(a==='report-review'){
  const v=(document.getElementById('fc-report-text')?.value||'').trim();
  if(v.length<15)return msg('اكتب تفاصيل لا تقل عن 15 حرفاً.',true,'fc-report-status');
  const file=document.getElementById('fc-report-attachment')?.files?.[0];
  if(file&&(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5*1024*1024))
   return msg('اختر PNG أو JPG أو WebP لا يزيد عن 5MB.',true,'fc-report-status');
  const kind=document.getElementById('fc-report-type')?.selectedOptions?.[0]?.textContent||'بلاغ';
  showSheet('<div class="fc-sheet" dir="rtl">'+head('مراجعة البلاغ')+
   card('<div class="fc-kv"><span>النوع</span><b>'+H(kind)+'</b></div><p>'+H(v)+'</p>'+
   '<p class="fc-quiet">مرفقات: '+(file?'صورة محلية جاهزة للمراجعة':'لا توجد')+'</p>')+
   note+btn('إغلاق المراجعة','close','','wide')+'</div>',true);return;
 }
},true);
window.TotiChatFrontendFinish=Object.freeze({version:'1.0-ui-handoff',routes:Object.keys(extraRoutes).concat(['storePreview','bagPreview','friendsPreview','notificationsPreview','signupPreview','loginPreview','welcomePreview'])});
})();
