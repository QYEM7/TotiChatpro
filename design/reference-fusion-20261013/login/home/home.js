/* TotiChat Home 02 — isolated staging-backed page.
 * Source of truth: server-authorized rooms, banners, memberships and gift events.
 * No seeded demo cards, phantom banners, fake balances, or simulated joins.
 */
(function initHome(){
  'use strict';
  const byId=id=>document.getElementById(id);
  const auth=window.TotiPhase2Auth;
  const origin=window.TOTICHAT_PUBLIC_BACKEND?.supabaseUrl;
  const state={rooms:[],mine:new Set(),joined:new Set(),banners:[],events:[],filter:'all',query:'',user:null,
    authenticated:false,loadTicket:0,viewReady:false,activeBanner:0,fetching:false,creating:false};
  const icons={sparkle:'✧',private:'♕'};
  const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  let toastTimer=null,backgroundTimer=null,authTask=null;
  const clamp=(v,min,max)=>Math.max(min,Math.min(max,Number(v)||0));
  const escapeText=s=>String(s??'').slice(0,300);
  function status(message,kind='info'){
    const node=byId('auth-status');
    byId('auth-status-text').textContent=message;
    node.dataset.kind=kind;
    node.hidden=false;
  }
  function toast(message){
    const el=byId('toast');el.textContent=escapeText(message);
    el.hidden=false;clearTimeout(toastTimer);
    toastTimer=setTimeout(()=>{el.hidden=true},3400);
  }
  function safeImage(raw){
    try{const u=new URL(raw,location.origin);
      if(u.protocol!=='https:' || /\s/.test(u.href))return null;
      return u.href;
    }catch{return null;}
  }
  function coverUrl(path){
    if(typeof path!=='string'||!path||path.length>200||
      !/^[a-zA-Z0-9_\-/]+\.webp$/.test(path)||path.includes('..'))return null;
    return origin+'/storage/v1/object/public/totichat-room-images/'+
      path.split('/').map(encodeURIComponent).join('/');
  }
  function addText(parent,tag,klass,value){
    const el=document.createElement(tag);if(klass)el.className=klass;
    el.textContent=escapeText(value);parent.appendChild(el);return el;
  }
  function clear(node){while(node.firstChild)node.removeChild(node.firstChild);}
  function openSheet(title,render){
    byId('sheet-title').textContent=title;const parent=byId('sheet-body');clear(parent);
    render(parent);byId('sheet-scrim').hidden=false;byId('info-sheet').hidden=false;
    byId('sheet-close').focus();
  }
  function closeSheets(){
    byId('info-sheet').hidden=true;byId('create-sheet').hidden=true;
    byId('sheet-scrim').hidden=true;
  }
  function sheetParagraph(target,message){addText(target,'p','sheet-copy',message);}
  function primarySheetButton(target,label,disabled=true,onClick=null){
    const b=addText(target,'button','sheet-primary',label);b.type='button';b.disabled=disabled;
    if(onClick)b.addEventListener('click',onClick);
    return b;
  }
  function futureScreen(label){
    openSheet(label,target=>{
      sheetParagraph(target,'هذه الواجهة مخصصة للمرحلة القادمة من TotiChat. لن نعرض بيانات تجريبية أو أزرار لا تنفّذ عمليات حقيقية.');
      sheetParagraph(target,'حالياً نفحص الرئيسية وحدها قبل الانتقال لبقية الواجهات حسب خطة الموافقة واجهة بواجهة.');
      primarySheetButton(target,'تحت التطوير — لا يوجد تنفيذ وهمي',true);
    });
  }
  async function verifyAccount(){
    if(!auth||!origin){status('خدمة تسجيل الدخول غير متوفرة في المعاينة.','error');return false}
    if(!auth.state()?.signedIn){location.replace('../');return false}
    if(authTask)return authTask;
    authTask=(async()=>{
      try{
        const expected=auth.state().user?.id;
        if(!UUID.test(expected||''))throw Error('Invalid active identity');
        await auth.securityState();
        if(!auth.state()?.signedIn||auth.state().user?.id!==expected)throw Error('Authentication changed');
        if(auth.state().profile?.id!==expected)await auth.readProfile();
        if(!auth.state()?.signedIn||auth.state().user?.id!==expected)throw Error('Profile identity mismatch');
        state.user=expected;state.authenticated=true;state.viewReady=true;
        byId('secure-content').hidden=false;byId('auth-status').hidden=true;
        return true;
      }catch(error){
        state.authenticated=false;byId('secure-content').hidden=true;
        status('تعذّر التحقق من الحساب. ارجع لتسجيل الدخول وأعد المحاولة.','error');
        return false;
      }
    })();
    try{return await authTask}finally{authTask=null}
  }
  function assertUser(){
    if(!state.authenticated||!state.user||auth?.state()?.user?.id!==state.user)throw Error('Account session has changed');
  }
  async function query(table,params){
    assertUser();
    return auth.requestData('/rest/v1/'+table+'?'+params);
  }
  function renderBanners(){
    const wrapper=byId('banners'),list=byId('banner-items'),dots=byId('banner-pagination');
    clear(list);clear(dots);clearInterval(backgroundTimer);backgroundTimer=null;
    const items=state.banners.filter(b=>safeImage(b.image_url)&&b.status==='published');
    wrapper.hidden=items.length===0;
    items.forEach((b,index)=>{
      const entry=document.createElement('div');entry.className='banner-entry'+(index===0?' active':'');
      const img=document.createElement('img');img.src=safeImage(b.image_url);img.alt=escapeText(b.title);
      img.loading='lazy';img.referrerPolicy='no-referrer';img.addEventListener('error',()=>{entry.hidden=true});
      entry.appendChild(img);addText(entry,'span','banner-label',b.title);
      list.appendChild(entry);
      if(items.length>1){
        const dot=document.createElement('button');dot.className=index===0?'current':'';
        dot.type='button';dot.setAttribute('aria-label','الإعلان '+(index+1));
        dot.addEventListener('click',()=>showBanner(index));dots.appendChild(dot);
      }
    });
    state.activeBanner=0;
    if(items.length>1){
      backgroundTimer=setInterval(()=>{if(document.hidden)return;showBanner((state.activeBanner+1)%items.length)},6000);
    }
  }
  function showBanner(index){
    state.activeBanner=index;
    [...byId('banner-items').children].forEach((entry,i)=>entry.classList.toggle('active',i===index));
    [...byId('banner-pagination').children].forEach((entry,i)=>entry.classList.toggle('current',i===index));
  }
  function renderGiftStrip(){
    const container=byId('global-gift-strip');
    const latest=state.events.find(e=>Number(e.total_coins)>=7000);
    container.hidden=!latest;
    if(!latest)return;
    byId('gift-ticker-content').textContent=
      escapeText(latest.sender_name)+' أرسل '+escapeText(latest.gift_name)+
      ' إلى '+escapeText(latest.recipient_name)+' — '+Number(latest.total_coins).toLocaleString('en-US')+' عملة';
  }
  function eligibleRoom(room){
    return room&&UUID.test(room.id||'')&&typeof room.title==='string'&&
      (room.is_private!==true || room.owner_id===state.user || state.mine.has(room.id));
  }
  function matchesRoom(room){
    if(!eligibleRoom(room))return false;
    if(state.filter==='public'&&room.is_private)return false;
    if(state.filter==='mine'&&room.owner_id!==state.user&&!state.mine.has(room.id))return false;
    if(state.query&&!room.title.toLocaleLowerCase().includes(state.query))return false;
    return true;
  }
  function renderRooms(){
    const grid=byId('rooms-grid'),empty=byId('rooms-empty');
    clear(grid);
    const list=state.rooms.filter(matchesRoom);
    const hasResult=list.length>0;grid.hidden=!hasResult;empty.hidden=hasResult;
    if(!hasResult){
      byId('empty-title').textContent=state.query?'ما لقينا غرفة بهذا الاسم':state.filter==='mine'?'ما عندك غرف بهذا التصنيف':'لا توجد غرف متاحة حالياً';
      byId('empty-copy').textContent=state.query?'جرّب كتابة اسم آخر أو ألغِ البحث.':'الغرف الخاصة لا تظهر إلا لأصحابها أو المشاركين فيها، وما نعرض غرف وهمية.';
      return;
    }
    for(const room of list){
      const card=document.createElement('button');card.type='button';card.className='room-card';card.setAttribute('aria-label','تفاصيل الغرفة '+room.title);
      const image=coverUrl(room.cover_path);
      if(image){
        const img=document.createElement('img');img.className='cover-image';img.src=image;img.alt='';img.loading='lazy';
        img.addEventListener('error',()=>{img.remove();const holder=addText(card,'span','cover-placeholder','✧');card.insertBefore(holder,card.firstChild)});
        card.appendChild(img);
      }else{addText(card,'span','cover-placeholder','✧');}
      addText(card,'span','room-gradient','');
      addText(card,'span','room-badge',room.is_private?'♕ خاصة':'✦ عامة');
      addText(card,'span','corner-shine','✧');
      addText(card,'span','room-title',room.title);
      addText(card,'span','room-subtitle',room.owner_id===state.user?'غرفتك الصوتية':state.mine.has(room.id)?'غرفة انضممت إليها':'غرفة صوتية');
      card.addEventListener('click',()=>openRoomDetails(room));
      grid.appendChild(card);
    }
  }
  function openRoomDetails(room){
    openSheet('تفاصيل الغرفة',target=>{
      addText(target,'h3','',room.title);
      const meta=document.createElement('div');meta.className='detail-meta';
      addText(meta,'span','',room.is_private?'خاصة':'عامة');
      if(room.owner_id===state.user)addText(meta,'span','','أنت المالك');
      target.appendChild(meta);
      if(room.welcome_message)sheetParagraph(target,room.welcome_message);
      sheetParagraph(target,'عرض الغرف مربوط ببيانات Supabase الفعلية. الدخول للصوت والمقاعد يُفحص في واجهة الغرفة المستقلة، لذلك لن ندخلك جلسة صوت غير مكتملة.');
      primarySheetButton(target,'واجهة الغرفة قيد التنفيذ',true);
    });
  }
  async function loadHome(){
    if(state.fetching||!state.authenticated)return;
    const ticket=++state.loadTicket,owner=state.user;
    state.fetching=true;
    byId('rooms-loading').hidden=false;byId('rooms-grid').hidden=true;byId('rooms-empty').hidden=true;
    byId('rooms-error').hidden=true;
    try{
      const results=await Promise.allSettled([
        query('rooms','select=id,title,owner_id,is_private,cover_path,welcome_message,created_at&order=created_at.desc&limit=80'),
        query('room_members','select=room_id,user_id&user_id=eq.'+encodeURIComponent(owner)+'&limit=250'),
        query('home_banners','select=id,title,image_url,status,sort_order,starts_at,ends_at&status=eq.published&order=sort_order.asc&limit=15'),
        query('gift_global_announcements','select=id,sender_name,recipient_name,gift_name,total_coins,created_at&total_coins=gte.7000&order=created_at.desc&limit=5')
      ]);
      if(ticket!==state.loadTicket || !state.authenticated || owner!==state.user)return;
      if(results[0].status==='rejected')throw results[0].reason;
      state.rooms=Array.isArray(results[0].value)?results[0].value:[];
      state.joined=new Set(results[1].status==='fulfilled'&&Array.isArray(results[1].value)?results[1].value.map(x=>x.room_id):[]);
      state.mine=new Set(state.joined);
      if(results[2].status==='fulfilled')state.banners=Array.isArray(results[2].value)?results[2].value:[];
      if(results[3].status==='fulfilled')state.events=Array.isArray(results[3].value)?results[3].value:[];
      renderRooms();renderBanners();renderGiftStrip();
      if(results.slice(1).some(r=>r.status==='rejected'))toast('تم عرض الغرف، لكن بعض بيانات المجتمع غير متوفرة حالياً.');
    }catch(error){
      if(ticket!==state.loadTicket)return;
      const fail=byId('rooms-error');fail.hidden=false;
      fail.textContent='تعذّر تحميل الغرف من الخادم. تحقق من الاتصال واضغط زر التحديث.';
      // Never replace a network error with invented fallback rooms.
      state.rooms=[];byId('banners').hidden=true;byId('global-gift-strip').hidden=true;
    }finally{if(ticket===state.loadTicket){state.fetching=false;byId('rooms-loading').hidden=true}}
  }
  function setFilter(next){
    state.filter=next;
    document.querySelectorAll('[data-filter]').forEach(b=>{
      const active=b.dataset.filter===next;b.classList.toggle('is-active',active);
      b.setAttribute('aria-pressed',String(active));
    });
    renderRooms();
  }
  function createRoomDialog(){
    if(!state.authenticated){toast('يرجى تسجيل الدخول أولاً');return;}
    closeSheets();byId('sheet-scrim').hidden=false;byId('create-sheet').hidden=false;
    byId('create-name').focus();
  }
  function setCreateMessage(text,kind='info'){
    const node=byId('create-message');node.textContent=escapeText(text);node.dataset.kind=kind;
  }
  function imageBlob(file){
    return new Promise((resolve,reject)=>{
      if(!file||!['image/png','image/jpeg','image/webp'].includes(file.type)||file.size>12*1024*1024)
        return reject(Error('اختر صورة PNG أو JPG أو WebP بحجم أقل من 12 ميغابايت.'));
      const url=URL.createObjectURL(file),img=new Image();
      img.onload=()=>{
        URL.revokeObjectURL(url);
        try{
          const scale=Math.min(1,1024/Math.max(img.width,img.height));
          const canvas=document.createElement('canvas');
          canvas.width=Math.max(1,Math.round(img.width*scale));canvas.height=Math.max(1,Math.round(img.height*scale));
          const ctx=canvas.getContext('2d');if(!ctx)throw Error('Image conversion unavailable');
          ctx.drawImage(img,0,0,canvas.width,canvas.height);
          canvas.toBlob(blob=>{
            if(!blob||blob.type!=='image/webp'||blob.size>2097152)
              reject(Error('تعذّر تجهيز صورة WebP أقل من 2 ميغابايت. جرّب صورة أصغر.'));
            else resolve(blob);
          },'image/webp',.79);
        }catch(e){reject(e)}
      };
      img.onerror=()=>{URL.revokeObjectURL(url);reject(Error('تعذّر قراءة الصورة.'))};
      img.src=url;
    });
  }
  async function handleCreate(event){
    event.preventDefault();
    if(state.creating)return;
    const title=byId('create-name').value.trim(),welcome=byId('create-welcome').value.trim();
    const file=byId('create-cover').files?.[0];
    if(title.length<2||title.length>48||welcome.length<2||welcome.length>220||!file){
      setCreateMessage('أدخل الاسم، رسالة الترحيب والصورة قبل الإنشاء.','error');return;
    }
    if(!state.authenticated){setCreateMessage('انتهت الجلسة، سجّل الدخول مرة ثانية.','error');return}
    // The live RPC refuses creating a new room while the account is a room member.
    // Never call phase2_room_leave here: for room owners it DELETES the owned room.
    if(state.joined.size>0){
      setCreateMessage('حسابك مشترك حالياً في غرفة. تحتاج مغادرتها من واجهة الغرفة قبل إنشاء أخرى. لن نحذف غرفتك تلقائياً.','error');
      return;
    }
    state.creating=true;byId('create-submit').disabled=true;setCreateMessage('جاري تجهيز الصورة…');
    let newId=null;
    try{
      const blob=await imageBlob(file);
      assertUser();setCreateMessage('جاري إنشاء الغرفة على Staging…');
      newId=await auth.requestData('/rest/v1/rpc/phase2_room_create',{
        method:'POST',body:{p_title:title,p_is_private:byId('create-private').checked}});
      if(!UUID.test(newId||''))throw Error('الخادم لم يؤكد رقم الغرفة الجديدة');
      assertUser();setCreateMessage('جاري رفع الصورة…');
      const path=await auth.uploadRoomImage(newId,'cover',blob);
      assertUser();setCreateMessage('جاري حفظ رسالة الترحيب…');
      const result=await auth.requestData('/rest/v1/rpc/phase2_room_customize',{
        method:'POST',body:{p_room_id:newId,p_welcome_message:welcome,p_cover_path:path,p_background_path:null}});
      if(result!==true)throw Error('لم يؤكد الخادم حفظ تفاصيل الغرفة');
      closeSheets();byId('create-form').reset();byId('cover-preview').hidden=true;
      toast('تم إنشاء غرفتك وحفظ الصورة والترحيب بنجاح.');
      await loadHome();
    }catch(error){
      setCreateMessage(newId?
        'تم إنشاء غرفة برقم '+newId+' لكن لم تكتمل الصورة أو رسالة الترحيب. لا تعيد الإنشاء حتى نصلحها.':
        escapeText(error?.message||'تعذّر إنشاء الغرفة. حاول مجدداً.'),'error');
      if(newId)byId('create-submit').disabled=true;
    }finally{
      state.creating=false;if(!newId)byId('create-submit').disabled=false;
    }
  }
  async function init(){
    const events=[
      ['search-trigger','click',()=>{const r=byId('search-region');r.hidden=!r.hidden;if(!r.hidden)byId('room-search').focus();else{byId('room-search').value='';state.query='';renderRooms()}}],
      ['search-clear','click',()=>{byId('room-search').value='';state.query='';renderRooms();byId('search-region').hidden=true}],
      ['refresh-rooms','click',()=>void loadHome()],
      ['hero-create','click',createRoomDialog],
      ['nav-create','click',createRoomDialog],
      ['empty-create','click',createRoomDialog],
      ['notifications-trigger','click',()=>futureScreen('الإشعارات')],
      ['sheet-close','click',closeSheets],
      ['create-close','click',closeSheets],
      ['sheet-scrim','click',closeSheets],
      ['create-form','submit',event=>void handleCreate(event)],
      ['room-search','input',event=>{state.query=event.target.value.trim().toLocaleLowerCase();renderRooms()}],
      ['create-cover','change',event=>{
        const img=byId('cover-preview');if(img.dataset.blobUrl)URL.revokeObjectURL(img.dataset.blobUrl);
        const file=event.target.files?.[0];img.hidden=!file;if(file){img.dataset.blobUrl=URL.createObjectURL(file);img.src=img.dataset.blobUrl}
      }]
    ];
    for(const [id,type,fn] of events)byId(id).addEventListener(type,fn);
    document.querySelectorAll('[data-filter]').forEach(b=>b.addEventListener('click',()=>setFilter(b.dataset.filter)));
    document.querySelectorAll('[data-future]').forEach(b=>b.addEventListener('click',()=>{
      const names={cp:'روابط CP',agency:'الوكالات',vip:'مستويات VIP',discover:'اكتشف',messages:'الرسائل',me:'ملفي'};
      if(b.dataset.future==='me'){
        openSheet('ملفي',target=>{
          const email=auth?.state()?.user?.email||'';
          sheetParagraph(target,'حساب Google المتصل: '+email);
          sheetParagraph(target,'الملف الشخصي الكامل ضمن الواجهة المخصصة القادمة. ويمكنك تسجيل الخروج الآن بأمان.');
          primarySheetButton(target,'تسجيل الخروج من TotiChat',false,async()=>{
            closeSheets();status('جاري تسجيل الخروج…');
            try{await auth.signOut();location.replace('../')}
            catch(error){status(error?.message||'تم الخروج محلياً لكن لم يتأكد إلغاء الجلسة بالخادم.','error');}
          });
        });
      }else futureScreen(names[b.dataset.future]||'واجهة قادمة');
    }));
    byId('nav-home').addEventListener('click',()=>window.scrollTo({top:0,behavior:'smooth'}));
    document.addEventListener('keydown',event=>{if(event.key==='Escape')closeSheets()});
    window.addEventListener('totichat-phase2-auth',()=>{
      if(state.authenticated&&!auth.state()?.signedIn){
        state.authenticated=false;state.loadTicket++;byId('secure-content').hidden=true;location.replace('../');
      }
    });
    document.addEventListener('visibilitychange',()=>{
      if(!document.hidden&&state.authenticated&&!state.fetching)void loadHome();
    });
    if(await verifyAccount())await loadHome();
  }
  void init();
})();