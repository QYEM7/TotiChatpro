/* TotiChat REBORN — secondary pages, server-backed and fail-closed. */
(function(){
'use strict';
const api=()=>window.TotiReborn;
const A=()=>api().auth,s=()=>api().state;
const e=x=>api().esc(x),m=x=>api().money(x),h=t=>api().header(t);
const rpc=(n,args)=>api().rpc(n,args),get=p=>api().endpoint(p);
const empty=(title,desc)=>api().empty(title,desc);
const status=msg=>'<div class="status">'+e(msg||'')+'</div>';
const icon=(name,screen)=>api().menuRow(name,screen,screen);
function list(rows,renderRow,no='ماكو بيانات منشورة حالياً'){return Array.isArray(rows)&&rows.length?rows.map(renderRow).join(''):empty('القائمة فارغة',no);}
function current(){return A()?.state()?.user?.id||'';}
function data(key){return s().extra[key];}
function set(key,val){s().extra[key]=val;if(s().screen===key)api().render();}
function pending(msg){return status(msg||'يتم جلب المعلومات من الخادم…');}
function inbox(){
 const rows=s().inbox;return h('الرسائل الخاصة')+
 '<div class="card" style="margin-bottom:15px"><b>محادثاتك محفوظة وآمنة</b><p class="hint">الرسائل خاصة ونصية فقط. لا توجد رسائل صوتية خاصة.</p></div>'+
 list(rows,item=>'<button class="list-item" data-peer="'+e(item.other_user_id)+'" data-name="'+e(item.other_display_name||'مستخدم')+'">'+
 api().avatar(item.other_avatar_url)+'<span class="grow"><b>'+e(item.other_display_name||'مستخدم')+'</b><br><small>'+e(item.last_body||'')+'</small></span>'+
 (Number(item.unread_count)>0?'<span class="inline-badge">'+m(item.unread_count)+'</span>':'<span class="end">‹</span>')+'</button>','اختر مستخدماً من أعضاء الغرفة لبدء محادثة.');
}
function thread(){
 return h(s().peerName||'محادثة خاصة')+
 '<div class="card"><div class="dm-thread" id="dm-thread">'+list(s().thread,item=>
 '<div class="dm-bubble '+(item.sender_id===current()?'mine':'')+'">'+e(item.body)+'<br><small>'+e(item.created_at?new Date(item.created_at).toLocaleTimeString('ar-IQ',{hour:'2-digit',minute:'2-digit'}):'')+'</small></div>','لا توجد رسائل سابقة.')+
 '</div><form id="dm-form" class="row" style="margin-top:14px"><input class="field grow" name="body" maxlength="2000" required placeholder="اكتب رسالة نصية…"><button type="submit" class="primary">إرسال</button></form></div>';
}
function store(){
 const items=(s().store||[]).filter(x=>x.is_active!==false&&!x.is_reward);
 const filter=s().tab==='all'?items:items.filter(x=>x.category===s().tab);
 const categories=[...new Set(items.map(x=>x.category).filter(Boolean))];
 return h('المتجر')+'<div class="hero"><div><h1>اقتني ما يميزك ✦</h1><p>الأسعار والمقتنيات من خادم TotiChat الحقيقي.</p></div></div>'+
 '<div class="section-head"><h2>الأقسام</h2></div>'+
 '<div class="chips"><button class="chip '+(s().tab==='all'?'active':'')+'" data-tab="all">الكل</button>'+
 categories.map(x=>'<button class="chip '+(s().tab===x?'active':'')+'" data-tab="'+e(x)+'">'+e(x)+'</button>').join('')+'</div>'+
 '<div class="section-head"><h2>المعروض للبيع</h2><button data-act="refresh">تحديث</button></div>'+
 (filter.length?'<div class="inventory">'+filter.map(x=>'<button class="card" data-store-item="'+e(x.id)+'">'+
 '<span class="symbol">'+e(x.icon||'◇')+'</span><b style="display:block">'+e(x.name)+'</b>'+
 '<small>🪙 '+m(x.price)+'</small></button>').join('')+'</div>':empty('ماكو عناصر بهذا القسم','اعرض قسماً ثانياً أو حاول التحديث.'));
}
function walletSection(){return api().menuRow('◈','المحفظة','wallet');}
function editProfile(){
 const p=A()?.state()?.profile||{};
 return h('تعديل ملفي')+'<div class="card"><div class="row" style="margin-bottom:18px">'+api().avatar(p.avatar_url,'xl')+
 '<div class="grow"><b>'+e(p.display_name||'مستخدم')+'</b><br><small>الصورة الحالية لحسابك</small></div></div>'+
 '<form id="profile-form" class="stack"><label><span class="label">الاسم الظاهر</span><input class="field" name="name" required minlength="2" maxlength="35" value="'+e(p.display_name||'')+'"></label>'+
 '<label><span class="label">نبذة شخصية</span><textarea class="field" maxlength="150" name="bio">'+e(p.bio||'')+'</textarea></label>'+
 '<button class="primary" type="submit">حفظ التغييرات</button></form>'+
 '<div class="separator"></div><label><span class="label">تغيير صورة الحساب</span>'+
 '<input type="file" class="field" accept="image/png,image/jpeg,image/webp" id="avatar-file"></label>'+
 '<button class="secondary full" style="margin-top:10px" data-act="avatarUpload">رفع الصورة إلى حسابي</button></div>';
}
function cp(){
 const state=data('cp'),relations=state?.relations||[],types=state?.types||[];
 return h('علاقات CP')+'<div class="hero"><div><h1>العلاقات الحقيقية ♡</h1><p>كل علاقة محفوظة بموافقة الطرفين على الخادم.</p></div></div>'+
 '<div class="section-head"><h2>علاقاتي</h2></div>'+
 list(relations,item=>'<div class="card" style="margin-bottom:9px"><b>'+e(item.type_label||item.type_id)+' · '+e(item.partner?.display_name||'شريك')+'</b>'+
 '<p class="hint">'+(item.accepted_at?'علاقة مؤكدة':'طلب بانتظار القبول')+'</p>'+
 (!item.accepted_at&&item.requested_by!==current()?'<button class="secondary" data-cp-decision="accept" data-cp-target="'+e(item.partner?.id)+'" data-cp-type="'+e(item.type_id)+'">قبول</button>':'')+'</div>','ليس عندك علاقات أو طلبات حالياً.')+
 '<div class="section-head"><h2>إرسال طلب جديد</h2></div>'+
 '<div class="card"><form id="cp-search-form" class="stack"><label><span class="label">بحث عن المستخدم</span><input class="field" required name="name" maxlength="35" placeholder="اسم الشريك"></label><button class="secondary">البحث عن الشريك</button></form>'+
 '<form id="cp-request-form" class="stack" style="margin-top:12px"><label><span class="label">العضو</span><select class="field" name="partner" required><option value="">اختر عضواً من نتائج البحث</option>'+
 (data('cpMatches')||[]).filter(x=>x.id!==current()).map(x=>'<option value="'+e(x.id)+'">'+e(x.display_name)+'</option>').join('')+'</select></label>'+
 '<label><span class="label">نوع العلاقة</span><select class="field" name="type" required>'+types.map(x=>'<option value="'+e(x.id)+'">'+e(x.label)+'</option>').join('')+'</select></label>'+
 '<button class="primary" '+(!types.length?'disabled':'')+'>إرسال طلب العلاقة</button></form></div>';
}
function agency(){
 const state=data('agencies')||{},rows=state.agencies||[],regs=state.registrations||[];
 return h('الوكالات')+'<div class="hero"><div><h1>وكالات TotiChat ♛</h1><p>وكالات المضيفين والشحن ببيانات حقيقية وصلاحيات محددة.</p></div></div>'+
 '<div class="section-head"><h2>وكالاتي</h2></div>'+
 list(rows.filter(x=>x.owner_id===current()||x.member_user_id===current()),x=>
 '<div class="card" style="margin-bottom:10px"><b>'+e(x.name||x.kind)+'</b><p class="hint">'+e(x.kind||'')+'</p></div>','ما عندك وكالة مرتبطة بالحساب.')+
 '<div class="section-head"><h2>طلبات فتح الوكالة</h2></div>'+
 list(regs.filter(x=>x.requested_by===current()||x.user_id===current()),x=>
 '<div class="card" style="margin-bottom:9px"><b>'+e(x.name)+'</b><p class="hint">الحالة: '+e(x.status||'بانتظار المراجعة')+'</p></div>','لم تقدم طلباً بعد.')+
 '<div class="section-head"><h2>فتح وكالة جديدة</h2></div><form class="card stack" id="agency-form">'+
 '<label><span class="label">نوع الوكالة</span><select name="kind" class="field"><option value="host">وكالة مضيفين</option><option value="recharge">وكالة شحن</option></select></label>'+
 '<label><span class="label">اسم الوكالة</span><input class="field" name="name" minlength="2" maxlength="80" required></label>'+
 '<label><span class="label">التواصل</span><input class="field" name="contact" minlength="3" maxlength="100" required></label>'+
 '<label><span class="label">سبب الطلب</span><textarea class="field" name="reason" minlength="3" maxlength="500" required></textarea></label>'+
 '<button class="primary">إرسال الطلب للإدارة</button></form>';
}
function notifications(){
 const rows=data('notifications')||[];return h('الإشعارات',true,'<button class="secondary" data-act="mark-notifications">تحديد الكل مقروء</button>')+
 list(rows,x=>'<div class="card" style="margin-bottom:9px"><b>'+e(x.title||'إشعار')+'</b><p class="hint">'+e(x.body||x.message||'')+'</p><small>'+e(x.created_at?new Date(x.created_at).toLocaleString('ar-IQ'):'')+'</small></div>','لا توجد إشعارات جديدة.');
}
function vip(){
 const obj=data('vip')||{};const tier=Number(obj.tier??obj.level??obj.vip_level??0);
 return h('عضوية VIP')+'<div class="hero"><div><h1>VIP · '+(tier||'غير مفعل')+'</h1><p>المستوى حسب استحقاق الحساب على الخادم، وليس مستوى تجريبياً.</p></div></div>'+
 '<div class="section-head"><h2>حالة عضويتك</h2></div><div class="card"><b>'+ (tier?'المستوى '+tier:'لا توجد عضوية VIP نشطة')+'</b>'+
 '<p class="hint">'+(obj.expires_at?'تنتهي بتاريخ '+e(new Date(obj.expires_at).toLocaleDateString('ar-IQ')):'المزايا تظهر بعد تفعيلها من النظام الحقيقي.')+'</p></div>';
}
function history(){
 const rows=data('giftHistory')||[];return h('سجل الهدايا')+
 list(rows,x=>'<div class="card" style="margin-bottom:9px"><b>'+e(x.gift_name||'هدية')+'</b>'+
 '<p class="hint">العدد: '+m(x.quantity)+' · '+m(x.total_coins||x.gold_amount)+' كوين</p>'+
 '<small>'+e(x.created_at||'')+'</small></div>','لم تُسجل هدايا ضمن النتائج الحالية.');
}
function social(){
 const rows=data('social')||[];return h('الأصدقاء والمتابعة')+
 '<div class="card"><form id="social-form" class="row"><input class="field grow" name="q" placeholder="ابحث عن مستخدم…" maxlength="30" required>'+
 '<button class="primary">بحث</button></form></div>'+
 '<div class="section-head"><h2>النتائج</h2></div>'+
 list(rows,x=>'<div class="list-item">'+api().avatar(x.avatar_url)+'<div class="grow"><b>'+e(x.display_name||'مستخدم')+'</b></div>'+
 '<button class="secondary" data-follow="'+e(x.id)+'">متابعة</button></div>','ابحث باسم مستخدم حقيقي.');
}
function support(){
 const rows=data('support')||[];return h('الدعم الفني الرسمي')+
 '<div class="card"><p class="hint">البلاغات تذهب مباشرة إلى نظام التذاكر. لا يتم التعامل عبر تطبيق خارجي.</p>'+
 '<form id="support-form" class="stack"><label><span class="label">نوع الطلب</span><select class="field" name="category">'+
 [['general','استفسار عام'],['technical','مشكلة تقنية'],['account','الحساب'],['recharge','الشحن'],['host_agency','وكالة مضيفين'],['host_transfer','انتقال مضيف']].map(x=>'<option value="'+x[0]+'">'+x[1]+'</option>').join('')+
 '</select></label><label><span class="label">عنوان الطلب</span><input name="subject" class="field" required minlength="5" maxlength="120"></label>'+
 '<label><span class="label">وصف المشكلة</span><textarea name="message" class="field" required minlength="2" maxlength="2500"></textarea></label>'+
 '<button class="primary">إنشاء تذكرة دعم</button></form></div>'+
 '<div class="section-head"><h2>تذاكري</h2></div>'+
 list(rows,x=>'<div class="card" style="margin-bottom:9px"><b>'+e(x.title||x.category)+'</b><p class="hint">'+e(x.status||'')+'</p></div>','ما عندك تذاكر مفتوحة في النتائج الحالية.');
}
function settings(){
 return h('إعدادات الحساب')+api().menuRow('◈','تعديل الملف الشخصي','editProfile')+
 api().menuRow('♧','الإشعارات','notifications')+
 '<div class="card"><h3>الأمان والخصوصية</h3><p class="hint">المصادقة عبر Google حصراً في هذه النسخة. يمكنك تسجيل الخروج أو طلب حذف حسابك والبيانات المرتبطة به.</p>'+
 '<button class="secondary full" style="margin-bottom:10px" data-act="requestDeletion">طلب حذف حسابي وبياناتي</button>'+
 '<p class="hint">طلب الحذف يُسجَّل كتذكرة فعلية لحسابك لدى الدعم ويحتاج معالجة آمنة. قد تُحتفظ بسجلات مالية مطلوبة للالتزامات القانونية، وسيتم توضيح ذلك ضمن المراجعة.</p>'+
 '<button class="danger full" data-act="logout">تسجيل الخروج من TotiChat</button></div>';
}
function admin(){
 const a=s().authority;if(!(a?.isOwner||a?.isMainPartner||a?.canManageCatalogs||a?.canReadReports||a?.role==='db'))
  return h('مركز الإدارة')+empty('وصول مرفوض','ليس لحسابك صلاحية إدارة.');
 const agencyFlag=a.isOwner||a.isMainPartner||a.canManageHostAgencies;
 const commands=[['التقارير',a.canReadReports||a.isOwner||a.isMainPartner],['الكتالوجات',a.canManageCatalogs||a.isOwner||a.isMainPartner],['وكالات المضيفين',agencyFlag]];
 const granted=commands.filter(x=>x[1]).map(x=>'<div class="list-item"><b>'+x[0]+'</b><span class="end">صلاحية من الخادم</span></div>').join('');
 const role=e(a.role||'admin');
 return h('مركز الإدارة')+'<div class="hero"><div><h1>مركز إدارة TotiChat</h1><p>الصلاحيات الفعلية مفروضة من الخادم على كل إجراء.</p></div></div>'+
 '<div class="section-head"><h2>صلاحياتي</h2></div><div class="card"><b>'+role+'</b><p class="hint">تتحدد الأقسام والبيانات حسب أذونات حسابك.</p></div>'+
 '<div class="section-head"><h2>الأقسام المخولة</h2></div>'+granted+
 ((a.canReadReports||a.isOwner||a.isMainPartner)?'<button class="secondary full" data-act="adminReport">تحميل تقارير المعاملات</button>':'')+
 (data('adminReport')?'<div class="card" style="margin-top:12px"><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-size:11px">'+e(JSON.stringify(data('adminReport'),null,2).slice(0,3500))+'</pre></div>':'');
}
function sheet(name){
 if(name==='createRoom')return '<h2>إنشاء غرفة صوتية</h2><p class="hint">الاسم والصورة والترحيب حقول مطلوبة. كل البيانات تُحفظ في Staging.</p>'+
 '<form id="create-room-form" class="stack">'+
 '<label><span class="label">اسم الغرفة *</span><input name="title" class="field" required minlength="2" maxlength="60" placeholder="اسم الغرفة"></label>'+
 '<label><span class="label">صورة الغرفة *</span><input name="cover" type="file" class="field" accept="image/jpeg,image/png,image/webp" required></label>'+
 '<label><span class="label">رسالة الترحيب *</span><textarea name="welcome" class="field" required minlength="2" maxlength="500" placeholder="نورتوا غرفتنا"></textarea></label>'+
 '<label class="row"><input type="checkbox" name="private"> غرفة خاصة بدعوة</label>'+
 '<button class="primary">إنشاء الغرفة</button></form>';
 if(name==='roomMembers')return '<h2>أعضاء الغرفة</h2>'+list(s().members,x=>'<div class="list-item">'+api().avatar(x.avatar_url)+
 '<div class="grow"><b>'+e(x.display_name||'مستخدم')+'</b><br><small>'+e(x.seat_no?'المقعد '+x.seat_no:'عضو مستمع')+'</small></div>'+
 (x.user_id!==current()?'<button class="secondary" data-peer="'+e(x.user_id)+'" data-name="'+e(x.display_name||'مستخدم')+'">مراسلة</button>':'')+'</div>','الغرفة فارغة حالياً.');
 if(name==='inviteJoin')return '<h2>دخول غرفة خاصة</h2><p class="hint">اكتب رمز الدعوة المستلم من صاحب الغرفة. لا تظهر الغرف الخاصة في القائمة العامة.</p>'+
 '<form id="invite-join-form" class="stack"><label><span class="label">رمز الدعوة</span><textarea class="field" required name="invite" maxlength="250" placeholder="Room ID:Invitation token"></textarea></label><button class="primary">دخول الغرفة</button></form>';
 if(name==='roomInvite')return '<h2>رمز دعوة خاص</h2><p class="hint">شارك الرمز فقط مع الشخص المقصود.</p><textarea class="field" readonly>'+e(s().extra.invite||'')+'</textarea>'+
 '<button data-act="copyInvite" class="secondary full" style="margin-top:10px">نسخ الرمز</button>';
 if(name==='gifts'){
  const all=s().gifts||[];
  const available=all.filter(x=>x.is_active===true&&x.diamond_source_type!=='LUCKY_GIFT');
  const selected=s().selectedGift;
  const peers=s().members.filter(x=>x.user_id!==current());
  return '<h2>صندوق الهدايا ✦</h2><p class="hint">اختيار الهدية لا يخصم أي رصيد. الإرسال يحتاج تأكيدك وتأكيد الخادم.</p>'+
  '<div class="gift-list">'+(all.length?all.map(x=>'<button class="gift '+(selected===x.id?'selected':'')+'" data-gift="'+e(x.id)+'" '+
  (!x.is_active||x.diamond_source_type==='LUCKY_GIFT'?'disabled':'')+'><span class="emoji">'+e(x.icon||'🎁')+'</span>'+
  '<b>'+e(x.name)+'</b><small>🪙 '+m(x.price)+'</small></button>').join(''):status('لا توجد هدايا نشطة منشورة من الخادم.'))+'</div>'+
  (available.length?'<form id="gift-form" class="stack" style="margin-top:15px">'+
  '<label><span class="label">إلى العضو</span><select name="peer" class="field" required><option value="">اختر المستلم</option>'+
  peers.map(x=>'<option value="'+e(x.user_id)+'">'+e(x.display_name||'مستخدم')+'</option>').join('')+'</select></label>'+
  '<label><span class="label">العدد</span><select name="qty" class="field">'+[1,7,17,77,777].map(x=>'<option>'+x+'</option>').join('')+'</select></label>'+
  '<button class="primary" '+(!selected||!peers.length?'disabled':'')+'>إرسال الهدية المحددة</button></form>':'');
 }
 if(name==='storeItem'){
  const item=(s().store||[]).find(x=>x.id===s().extra.itemId);
  return !item?empty('العنصر غير متاح',''):
  '<h2>'+e(item.icon||'◇')+' '+e(item.name)+'</h2><p class="hint">'+e(item.description||'')+'</p>'+
  '<div class="card"><strong>'+m(item.price)+' '+e(item.currency==='silver'?'فضة':'كوينز')+'</strong>'+
  '<p class="hint">التأكيد النهائي يتم عبر الخادم مع منع إرسال الطلب مرتين.</p></div>'+
  '<button class="primary full" style="margin-top:12px" data-act="purchaseItem" '+(s().financeBusy?'disabled':'')+'>شراء العنصر</button>';
 }
 return empty('غير متاح','لا توجد بيانات للنافذة حالياً.');
}
async function load(name){
 const uid=current();if(!uid)return;let result;
 if(name==='inbox'){result=await rpc('phase2_dm_inbox',{p_limit:40});if(uid===current()){s().inbox=Array.isArray(result)?result:[];api().render();}}
 else if(name==='thread'&&s().selectedPeer){result=await rpc('phase2_dm_thread',{p_other_user:s().selectedPeer,p_before_id:null,p_limit:100});if(uid===current()){s().thread=Array.isArray(result)?result.slice().reverse():[];api().render();}}
 else if(name==='store'){result=await get('store_catalog?select=id,name,category,price,currency,icon,description,is_active,is_reward&is_active=eq.true&limit=100');if(uid===current()){s().store=Array.isArray(result)?result:[];api().render();}}
 else if(name==='cp')set('cp',await rpc('phase4_cp_state',{}));
 else if(name==='agencies')set('agencies',await rpc('phase4_agency_state',{}));
 else if(name==='notifications'){
  result=await rpc('phase5_notification_feed',{p_limit:80,p_before:null});
  set('notifications',Array.isArray(result)?result:Array.isArray(result?.rows)?result.rows:Array.isArray(result?.items)?result.items:[]);
 }
 else if(name==='vip')set('vip',await rpc('phase5_vip_status',{p_target:uid}));
 else if(name==='giftHistory'){
  result=await rpc('phase5_gift_history',{p_direction:'received',p_limit:40,p_before_at:null,p_before_id:null});
  set('giftHistory',Array.isArray(result)?result:Array.isArray(result?.rows)?result.rows:[]);
 }
 else if(name==='support'){
  result=await rpc('phase5_support_list',{p_scope:'mine',p_offset:0,p_limit:40});
  set('support',Array.isArray(result)?result:Array.isArray(result?.rows)?result.rows:Array.isArray(result?.tickets)?result.tickets:[]);
 }
 else if(name==='me'){await api().readAuthority();}
}
async function loadSheet(name){
 if(name==='gifts'){
  try{const rows=await get('gift_catalog?select=id,name,price,icon,category_id,is_active,diamond_source_type&limit=100');
   if(!Array.isArray(rows))throw Error('قائمة الهدايا غير صالحة');
   s().gifts=rows;if(s().sheet==='gifts')api().render();
  }catch(err){api().fail(err);}
 }
}
async function action(cmd,target){
 try{
  if(cmd==='requestDeletion'){
   const confirmed=confirm('هل تريد إرسال طلب رسمي بحذف حساب TotiChat والبيانات المرتبطة به؟ لا يبدأ الحذف تلقائياً، وسيراجع الدعم الطلب وهويتك قبل تنفيذه.');
   if(!confirmed)return;
   const sig='delete-account|'+current();
   if(!pendingKeys.has(sig))pendingKeys.set(sig,crypto.randomUUID());
   const result=await rpc('phase5_support_action',{
    p_action:'create',
    p_data:{category:'account',subject:'Account and personal data deletion request',
     message:'I request deletion of my TotiChat account and associated personal data. Please verify identity, handle financial record retention as legally required, and confirm completion.'},
    p_request_id:pendingKeys.get(sig)
   });
   if(!result?.id)throw Error('لم يؤكد الخادم تسجيل طلب الحذف');
   pendingKeys.delete(sig);
   api().notify('تم تسجيل طلب حذف الحساب لدى الدعم، رقم الطلب: '+result.id);
   return;
  }
  if(cmd==='logout'){await api().disconnectVoice();await A().signOut();api().open('home');return;}
  if(cmd==='avatarUpload'){
   const file=document.getElementById('avatar-file')?.files?.[0];if(!file)throw Error('اختر صورة أولاً');
   const blob=await api().imageBlob(file);await A().uploadAvatar(blob);api().notify('تم حفظ صورتك على الخادم');api().open('me');return;
  }
  if(cmd==='copyInvite'){
   const invite=String(s().extra.invite||'');
   if(!invite)return;
   await navigator.clipboard.writeText(invite);api().notify('تم نسخ الرمز');return;
  }
  if(cmd==='purchaseItem'){
   const item=s().store.find(x=>x.id===s().extra.itemId);
   if(!item||s().financeBusy)return;
   if(!confirm('تأكيد شراء '+item.name+' مقابل '+m(item.price)+'؟'))return;
   s().financeBusy=true;api().render();
   const requestId=crypto.randomUUID();
   const result=await rpc('phase3_purchase_store',{p_item_id:item.id,p_request_id:requestId,p_expected_price:item.price,p_expected_currency:item.currency});
   if(result?.status!=='completed')throw Error('لم يؤكد الخادم الشراء');
   s().sheet='';api().notify('تم الشراء بنجاح');api().render();return;
  }
  if(cmd==='adminReport'){
   const a=s().authority;if(!(a?.canReadReports||a?.isOwner||a?.isMainPartner))throw Error('غير مصرح');
   const to=new Date(),from=new Date(to.getTime()-30*86400000);
   set('adminReport',await rpc('phase4_admin_report',{p_from:from.toISOString(),p_to:to.toISOString(),p_status:null,p_offset:0,p_limit:30}));return;
  }
  if(cmd==='mark-notifications'){
   await rpc('phase5_notification_mark',{p_ids:null,p_all:true});await load('notifications');return;
  }
 }catch(err){api().fail(err);}finally{s().financeBusy=false;}
}
const pendingKeys=new Map();
async function submit(id,form){
 if(s().busy)return;
 const fd=new FormData(form);s().busy=true;
 try{
  if(id==='invite-join-form'){
   const raw=String(fd.get('invite')||'').trim();
   const match=raw.match(/^([0-9a-f]{8}-[0-9a-f-]{27,36}):([a-f0-9]{48,100})$/i);
   if(!match||!api().validId(match[1]))throw Error('رمز الدعوة غير صالح');
   const result=await rpc('phase2_room_invite_join',{p_room_id:match[1],p_token:match[2]});
   if(result!==true)throw Error('لم يؤكد الخادم قبول الدعوة');
   await api().readRooms();
   s().sheet='';
   await api().enterRoom(match[1]);
  }else if(id==='profile-form'){
   await A().updateProfile({display_name:String(fd.get('name')||''),bio:String(fd.get('bio')||'')});
   api().notify('تم حفظ الملف الشخصي');api().open('me');
  }else if(id==='dm-form'){
   const body=String(fd.get('body')||'').trim(),peer=s().selectedPeer;
   if(!peer||!body||body.length>2000)return;
   const signature=peer+'|'+body;
   if(!pendingKeys.has(signature))pendingKeys.set(signature,crypto.randomUUID());
   const done=await rpc('phase2_dm_send',{p_recipient_id:peer,p_body:body,p_request_id:pendingKeys.get(signature)});
   if(done?.sent!==true)throw Error('الخادم لم يؤكد إرسال الرسالة');
   pendingKeys.delete(signature);form.reset();await load('thread');
  }else if(id==='gift-form'){
   const gift=s().gifts.find(x=>x.id===s().selectedGift),peer=String(fd.get('peer')),qty=Number(fd.get('qty'));
   if(!gift?.is_active||gift.diamond_source_type==='LUCKY_GIFT'||!s().room||!api().validId(peer)||![1,7,17,77,777].includes(qty))throw Error('حدد هدية ومستلم وعدد صحيح');
   const cost=Number(gift.price)*qty;if(!Number.isSafeInteger(cost)||cost<=0)throw Error('سعر غير صحيح');
   if(!confirm('إرسال '+gift.name+' × '+qty+' مقابل '+m(cost)+' كوينز؟'))return;
   const sig=JSON.stringify([current(),s().room.id,peer,gift.id,qty]);
   if(!pendingKeys.has(sig))pendingKeys.set(sig,crypto.randomUUID());
   const res=await rpc('phase3_send_gift',{p_room_id:s().room.id,p_recipient_id:peer,p_gift_id:gift.id,p_quantity:qty,p_expected_price:gift.price,p_request_id:pendingKeys.get(sig)});
   if(res?.status!=='completed')throw Error('لم يؤكد الخادم العملية');
   pendingKeys.delete(sig);s().sheet='';api().render();api().notify('تم إرسال الهدية');await api().readWallet();
  }else if(id==='cp-search-form'){
   const prefix=String(fd.get('name')||'').trim().replace(/[%_*]/g,'');
   if(prefix.length<1)return;
   const matches=await get('profiles?select=id,display_name,avatar_url&display_name=ilike.'+encodeURIComponent('*'+prefix+'*')+'&limit=20');
   set('cpMatches',Array.isArray(matches)?matches:[]);
   api().render();
  }else if(id==='cp-request-form'){
   const peer=String(fd.get('partner')||''),type=String(fd.get('type')||'');
   if(!api().validId(peer)||!type)throw Error('الشريك أو نوع العلاقة غير صالح');
   const res=await rpc('phase4_cp_action',{p_partner_id:peer,p_type_id:type,p_action:'request',p_request_id:crypto.randomUUID()});
   if(!res?.id)throw Error('الخادم لم يؤكد الطلب');
   await load('cp');api().notify('تم إرسال طلب العلاقة');
  }else if(id==='agency-form'){
   const payload=Object.fromEntries(fd);
   const res=await rpc('phase4_agency_action',{p_action:'register',p_data:payload,p_request_id:crypto.randomUUID()});
   if(!res?.id)throw Error('الخادم لم يؤكد الطلب');
   form.reset();await load('agencies');api().notify('تم تسجيل طلب الوكالة');
  }else if(id==='support-form'){
   const payload=Object.fromEntries(fd);
   const res=await rpc('phase5_support_action',{p_action:'create',p_data:payload,p_request_id:crypto.randomUUID()});
   if(!res?.id)throw Error('الخادم لم يؤكد التذكرة');
   form.reset();await load('support');api().notify('تم إنشاء تذكرة الدعم');
  }else if(id==='social-form'){
   const prefix=String(fd.get('q')||'').trim();if(!prefix)return;
   const rows=await rpc('phase5_social_search',{p_prefix:prefix,p_limit:30});
   set('social',Array.isArray(rows)?rows:[]);
   api().render();
  }
 }catch(err){api().fail(err);}
 finally{s().busy=false;}
}
document.addEventListener('click',event=>{
 const btn=event.target?.closest?.('[data-peer],[data-store-item],[data-tab],[data-gift],[data-follow],[data-cp-decision]');
 if(!btn||!api())return;
 if(btn.dataset.peer){event.preventDefault();const id=btn.dataset.peer;if(!api().validId(id))return;
  s().selectedPeer=id;s().peerName=btn.dataset.name||'مستخدم';s().sheet='';api().open('thread');return;}
 if(btn.dataset.storeItem){s().extra.itemId=btn.dataset.storeItem;api().sheet('storeItem');return;}
 if(btn.dataset.tab){s().tab=btn.dataset.tab;api().render();return;}
 if(btn.dataset.gift){s().selectedGift=btn.dataset.gift;api().render();return;}
 if(btn.dataset.follow){void (async()=>{try{await rpc('phase5_social_follow',{p_target:btn.dataset.follow,p_follow:true,p_request_id:crypto.randomUUID()});api().notify('تم تحديث المتابعة');}catch(err){api().fail(err);}})();return;}
 if(btn.dataset.cpDecision){void (async()=>{try{const out=await rpc('phase4_cp_action',{p_partner_id:btn.dataset.cpTarget,p_type_id:btn.dataset.cpType,p_action:btn.dataset.cpDecision,p_request_id:crypto.randomUUID()});if(!out?.id)throw Error('الخادم لم يؤكد القرار');await load('cp');}catch(err){api().fail(err);}})();}
},true);
window.TotiRebornFeatures={view:function(route){
 switch(route){
  case 'inbox':return inbox();case 'thread':return thread();case 'store':return store();case 'editProfile':return editProfile();case 'cp':return cp();case 'agencies':return agency();case 'notifications':return notifications();case 'vip':return vip();case 'giftHistory':return history();case 'social':return social();case 'support':return support();case 'settings':return settings();case 'admin':return admin();default:return '';
 }
},sheet,load,loadSheet,action,submit};
})();