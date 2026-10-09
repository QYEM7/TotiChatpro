/* TotiChat frontend integration: live home banners. No mock-data fallback. */
(function(){
  'use strict';
  const core=window.TotiBannerCore;
  const state={items:[],index:0,status:'loading',message:''};
  const fields='id,title,image_url,link_kind,link_target,sort_order,status,starts_at,ends_at';
  let inflight=null;
  const emptyCopy={
    loading:'جارٍ تحميل الإعلانات…',
    unconfigured:'لم يتم ربط مصدر الإعلانات الحقيقي بعد',
    empty:'لا توجد إعلانات منشورة حالياً',
    error:'تعذّر تحميل الإعلانات حالياً'
  };
  function current(){return state.items[state.index]||null;}
  function placeholder(){
    return '<div class="hero" aria-live="polite"><span style="display:block;min-height:147px;position:relative"></span><b>'+core.escape(emptyCopy[state.status]||emptyCopy.empty)+'</b><div class="dots"></div></div>';
  }
  function renderBanner(){
    const item=current();
    if(!item)return placeholder();
    const label=core.escape(item.title);
    const aria=core.escape(item.kind==='none'?item.title:'افتح الإعلان: '+item.title);
    return '<div class="hero" data-a="liveBanner" data-v="'+state.index+'" role="button" tabindex="0" aria-label="'+aria+'"><img src="'+core.escape(item.imageUrl)+'" alt="'+label+'" loading="lazy"><b>'+label+'</b><div class="dots">'+state.items.map((_,i)=>'<i class="'+(i===state.index?'on':'')+'"></i>').join('')+'</div></div>';
  }
  function renderAnnouncements(){
    if(!state.items.length)return '<div class="cardwhite">'+core.escape(emptyCopy[state.status]||emptyCopy.empty)+'</div>';
    return state.items.map((item,i)=>'<button class="visual-row" data-a="liveBanner" data-v="'+i+'"><img src="'+core.escape(item.imageUrl)+'" alt=""><span class="visual-copy"><b>'+core.escape(item.title)+'</b><small>إعلان رسمي</small></span><span class="at-end">‹</span></button>').join('');
  }
  function redraw(){
    if(typeof screen==='undefined'||typeof render!=='function')return;
    if(screen==='home'&&homeTab==='حفلة')render();
  }
  async function refresh(){
    if(inflight)return inflight;
    const settings=window.TOTICHAT_PUBLIC_BACKEND||{};
    let api=null;
    try{const u=new URL(settings.supabaseUrl||'');if(u.protocol==='https:'&&u.hostname)api=u.origin;}catch{}
    const key=String(settings.publishableKey||'').trim();
    if(!api||!key){
      state.items=[];state.index=0;state.status='unconfigured';redraw();return;
    }
    const controller=new AbortController();
    const deadline=setTimeout(()=>controller.abort(),10000);
    inflight=(async()=>{
      try{
        const response=await fetch(api+'/rest/v1/home_banners?select='+encodeURIComponent(fields)+'&order=sort_order.asc,created_at.desc&limit=30',{
          method:'GET',headers:{apikey:key,Accept:'application/json'},signal:controller.signal,cache:'no-store'
        });
        if(!response.ok)throw new Error('Home banners API HTTP '+response.status);
        const results=await response.json();
        if(!Array.isArray(results))throw new Error('Invalid home banner response');
        const items=core.normalize(results);
        const old=current()?.id;
        state.items=items;
        state.index=Math.max(0,items.findIndex(x=>x.id===old));
        state.status=items.length?'ready':'empty';
      }catch(error){
        console.warn('TotiChat home banners unavailable:',error?.message||error);
        state.items=[];state.index=0;state.status='error';
      }finally{
        clearTimeout(deadline);
        inflight=null;
        redraw();
      }
    })();
    return inflight;
  }
  function advance(){
    if(state.status!=='ready'||state.items.length<2)return;
    state.index=(state.index+1)%state.items.length;
    if(typeof screen==='undefined'||screen!=='home'||homeTab!=='حفلة')return;
    const target=document.querySelector('.hero');
    if(target)target.outerHTML=renderBanner();
  }
  function activate(index){
    if(!Number.isInteger(index)||index<0||index>=state.items.length)return;
    state.index=index;
    const b=current();
    if(b.kind==='external'&&b.target){
      window.open(b.target,'_blank','noopener,noreferrer');
    }else if(b.kind==='screen'&&b.target&&typeof go==='function'){
      if(typeof closeSheet==='function')closeSheet();
      go(b.target);
    }else if(b.kind==='none'){
      if(typeof showToast==='function')showToast('لا يوجد رابط مرتبط بهذا الإعلان');
    }
  }
  document.addEventListener('click',e=>{
    const target=e.target.closest('[data-a="liveBanner"]');
    if(!target)return;
    e.preventDefault();
    activate(Number(target.dataset.v));
  });
  document.addEventListener('keydown',e=>{
    if((e.key==='Enter'||e.key===' ')&&e.target.matches?.('[data-a="liveBanner"]')){
      e.preventDefault();activate(Number(e.target.dataset.v));
    }
  });
  document.addEventListener('DOMContentLoaded',()=>{
    refresh();
    setInterval(()=>{if(document.visibilityState!=='hidden')refresh();},90000);
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')refresh();});
  });
  window.TotiBannerData=Object.freeze({renderBanner,renderAnnouncements,refresh,advance,getStatus:()=>state.status});
})();
