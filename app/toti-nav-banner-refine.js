/* TotiChat focused UI refinement.
   Works only on existing render output; no backend, balance, room or profile rewrites. */
(function(){
'use strict';
const app=document.getElementById('app');
if(!app || typeof render!=='function')return;
const falconSource='../assets/images/toti_falcon_logo_1790422919580.jpg';
const state={index:0,busy:false};
const escapeMarkup=value=>String(value==null?'':value).replace(/[&<>"']/g,function(c){
  return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];
});
function navigationMarkup(){
  const items=[
    ['home','⌂','الرئيسية'],
    ['discoverPreview','◎','اكتشف'],
    ['CREATE','＋','إنشاء غرفة'],
    ['messages','☏','الرسائل'],
    ['me','<img class="tc-falcon-nav" src="'+falconSource+'" alt="شعار الصقر">','حسابي']
  ];
  return '<nav class="royal-nav tc-unified-nav" aria-label="التنقل الرئيسي">'+items.map(function(item){
    const create=item[0]==='CREATE';
    const props=create?'class="royal-create" data-royal="create-room" aria-label="إنشاء غرفة"':
      'data-a="go" data-v="'+item[0]+'"'+(screen===item[0]?' class="selected" aria-current="page"':'');
    return '<button type="button" '+props+'><span>'+item[1]+'</span><small>'+item[2]+'</small></button>';
  }).join('')+'</nav>';
}
function enhanceNavigation(){
  // The home page owns its five-button navigation. Keep the original buttons and handlers.
  const royalNav=app.querySelector('.royal-home > .royal-nav');
  if(royalNav){
    royalNav.classList.add('tc-unified-nav');
    royalNav.setAttribute('aria-label','التنقل الرئيسي');
    const account=royalNav.querySelector('[data-v="me"]');
    if(account&&!account.querySelector('.tc-falcon-nav')){
      const icon=account.querySelector('span');
      if(icon)icon.innerHTML='<img class="tc-falcon-nav" src="'+falconSource+'" alt="شعار الصقر">';
    }
    return;
  }
  // Other full-screen views are unchanged; only replace the old three-button bottom bar.
  const old=app.querySelector('nav.bottom');
  if(!old)return;
  old.outerHTML=navigationMarkup();
}
function localSlides(){
  return [
    {title:'هنا يجتمع\nالصوت الجميل',caption:'⋆ كوّن صداقات حول العالم ⋆',url:A+assets.room5,action:'hero',label:'اكتشف الغرف'},
    {title:'لحظات جميلة\nمع أصدقاء جدد',caption:'⋆ انضم إلى مجتمع TotiChat ⋆',url:A+assets.hero2,action:'go',route:'discoverPreview',label:'اكتشف المجتمع'},
    {title:'عالم من الفعاليات\nوالتجارب المميزة',caption:'⋆ اكتشف أحدث الأقسام ⋆',url:A+assets.hero3,action:'go',route:'agencyPreview',label:'اكتشف الأقسام'}
  ];
}
function slides(){
  const raw=window.TotiBannerData&&typeof window.TotiBannerData.getItems==='function'
    ?window.TotiBannerData.getItems():[];
  // A genuine published banner comes only from the existing validated Supabase feed.
  // The static brand artwork is the visual placeholder, never a fake paid ad.
  if(raw.length)return [localSlides()[0]].concat(raw.map(function(x,i){
    return {title:x.title,caption:'إعلان رسمي في TotiChat',url:x.imageUrl,
      action:'live',liveIndex:i,label:x.title};
  }));
  return localSlides();
}
function applySlide(hero,list,index){
  const selected=list[index];
  if(!selected)return;
  const img=hero.querySelector('img');
  const title=hero.querySelector('.royal-hero-text b');
  const caption=hero.querySelector('.royal-hero-text small');
  if(!img||!title||!caption)return;
  img.src=selected.url;
  img.alt=selected.label;
  title.innerHTML=String(selected.title).split('\n').map(escapeMarkup).join('<br>');
  caption.textContent=selected.caption;
  hero.setAttribute('aria-label',selected.label);
  hero.removeAttribute('data-royal');
  hero.removeAttribute('data-a');
  hero.removeAttribute('data-v');
  if(selected.action==='hero')hero.dataset.royal='hero';
  else if(selected.action==='live'){
    hero.dataset.a='liveBanner';hero.dataset.v=String(selected.liveIndex);
  }else if(selected.action==='go'){
    hero.dataset.a='go';hero.dataset.v=selected.route;
  }
  const dots=hero.parentElement.querySelectorAll('.tc-banner-dot');
  dots.forEach(function(dot,i){
    const active=i===index;
    dot.classList.toggle('is-active',active);
    dot.setAttribute('aria-current',active?'true':'false');
    dot.setAttribute('aria-pressed',active?'true':'false');
  });
}
function setSlide(next,animate){
  const stage=app.querySelector('.royal-home .tc-banner-stage');
  if(!stage||state.busy)return;
  const hero=stage.querySelector('.royal-hero');
  const list=slides();
  if(!hero||!list.length)return;
  const ix=((next%list.length)+list.length)%list.length;
  if(!animate){
    state.index=ix;applySlide(hero,list,ix);return;
  }
  if(ix===state.index)return;
  state.busy=true;
  hero.classList.add('tc-slide-changing');
  setTimeout(function(){
    // Route transitions may have removed this slide while its fade was in progress.
    if(!hero.isConnected){state.busy=false;return;}
    state.index=ix;
    applySlide(hero,slides(),Math.min(ix,slides().length-1));
    requestAnimationFrame(function(){
      hero.classList.remove('tc-slide-changing');state.busy=false;
    });
  },210);
}
function enhanceBanner(){
  const hero=app.querySelector('.royal-home .royal-hero');
  if(!hero||hero.closest('.tc-banner-stage'))return;
  const stage=document.createElement('div');
  stage.className='tc-banner-stage';
  stage.setAttribute('aria-label','البنرات والعروض');
  hero.parentNode.insertBefore(stage,hero);
  stage.appendChild(hero);
  const list=slides();
  state.index=Math.min(state.index,Math.max(0,list.length-1));
  const dots=document.createElement('div');
  dots.className='tc-banner-controls';
  dots.setAttribute('role','group');
  dots.setAttribute('aria-label','اختيار البنر');
  list.forEach(function(x,i){
    const dot=document.createElement('button');
    dot.type='button';dot.className='tc-banner-dot';
    dot.setAttribute('aria-label','اعرض البنر '+(i+1)+': '+x.label);
    dot.addEventListener('click',function(ev){
      ev.preventDefault();ev.stopPropagation();
      setSlide(i,true);
    });
    dots.appendChild(dot);
  });
  stage.appendChild(dots);
  applySlide(hero,list,state.index);
}
function enhanceProfileStats(){
  // Only decorate the existing profile counters; preserve values, data-a routes and click events.
  const card=app.querySelector('.me-royal > .me-statcard');
  if(!card)return;
  card.classList.add('tc-stats-luxe');
  card.setAttribute('aria-label','متابعة الحساب والأصدقاء والزوار');
  const glyphs=['♟','♥','✦','◉'];
  Array.from(card.querySelectorAll(':scope > button')).forEach(function(button,index){
    if(button.querySelector('.tc-stat-glyph'))return;
    const glyph=document.createElement('span');
    glyph.className='tc-stat-glyph';
    glyph.setAttribute('aria-hidden','true');
    glyph.textContent=glyphs[index]||'✦';
    button.insertBefore(glyph,button.firstChild);
  });
}
function refine(){
  enhanceNavigation();
  enhanceBanner();
  enhanceProfileStats();
}
const previousRender=render;
render=function(){
  const result=previousRender.apply(this,arguments);
  refine();
  return result;
};
refine();
setInterval(function(){
  if(document.hidden||screen!=='home'||homeTab!=='حفلة')return;
  if(document.getElementById('overlay')?.classList.contains('show'))return;
  const stage=app.querySelector('.royal-home .tc-banner-stage');
  if(!stage||stage.matches(':focus-within'))return;
  const total=slides().length;
  if(total>1)setSlide((state.index+1)%total,true);
},5300);
window.TotiChatBannerRefinement=Object.freeze({version:'1.1',getSlideIndex:function(){return state.index;}});
})();