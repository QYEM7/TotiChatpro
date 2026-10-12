/* TotiChat Premium Icon System — authenticated live app only.
   One consistent outline family; preserves routing, VIP art, falcon logo, room seats and gifts effects.
   Visual-only DOM enhancement: no data, permissions, storage, clicks, or backend writes.
 */
(function(){
'use strict';
if(!window.TotiLiveMode?.enabled||!window.TotiPhase2Auth)return;
const live=()=>window.TotiLiveMode?.enabled===true&&window.TotiPhase2Auth?.state()?.signedIn===true;
const icons=Object.freeze({
 home:'<path d="m3 10 9-7 9 7"/><path d="M5 9.5V21h14V9.5"/><path d="M9 21v-7h6v7"/>',
 compass:'<circle cx="12" cy="12" r="9"/><path d="m16.2 7.8-3.1 5.3-5.3 3.1 3.1-5.3z"/>',
 plus:'<path d="M12 5v14M5 12h14"/>',
 message:'<path d="M20 11.5a8 8 0 0 1-8 8c-1.2 0-2.4-.2-3.5-.7L4 20l1.3-4.3A8 8 0 1 1 20 11.5Z"/>',
 messages:'<path d="M3 6a3 3 0 0 1 3-3h11a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3H9l-5 4v-4a3 3 0 0 1-1-3Z"/><path d="M8 8h9M8 12h6"/>',
 users:'<path d="M16 20v-1.7a4.3 4.3 0 0 0-4.3-4.3H6.3A4.3 4.3 0 0 0 2 18.3V20"/><circle cx="9" cy="7" r="3.2"/><path d="M17 4.1a3.2 3.2 0 0 1 0 6.3M22 20v-1.7a4.3 4.3 0 0 0-3.2-4.1"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>',
 search:'<circle cx="10.7" cy="10.7" r="6.7"/><path d="m16 16 5 5"/>',
 edit:'<path d="m15.5 4.5 4 4-11 11-5 1 1-5z"/><path d="m13.5 6.5 4 4"/>',
 close:'<path d="M5 5 19 19M19 5 5 19"/>',
 bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
 crown:'<path d="m2.5 7 5.4 4.5L12 4l4.1 7.5L21.5 7l-1.8 12H4.3z"/><path d="M5 16.5h14"/>',
 flame:'<path d="M12 22c-4.2 0-7-3-7-7 0-3.3 2.6-5.8 3.5-8 .2 2 1.5 3.4 2.5 4 .4-3.1 1.8-5.9 4.5-8 0 3.1 3.5 5.9 3.5 11.7C19 19.1 16.1 22 12 22Z"/><path d="M12 21c-2 0-3-1.5-3-3 0-1.2.8-2.4 2-3.4.1 1.1.6 1.8 1.2 2.1.4-1.1 1-1.9 1.9-2.7.4 1.4 1.3 2.1 1.3 4 0 1.7-1.1 3-3.4 3Z"/>',
 heart:'<path d="M20.6 8.3c0 4.7-8.6 10.7-8.6 10.7S3.4 13 3.4 8.3a4.7 4.7 0 0 1 8.6-2.6 4.7 4.7 0 0 1 8.6 2.6Z"/>',
 music:'<path d="M9 18V5l12-2v13"/><ellipse cx="6" cy="18.5" rx="3" ry="2.3"/><ellipse cx="18" cy="16.5" rx="3" ry="2.3"/>',
 gamepad:'<path d="M6 9.5h12a4 4 0 0 1 3.8 3l1 5.3a2.4 2.4 0 0 1-4 2l-3-3.1H8.2L5.3 20a2.4 2.4 0 0 1-4-2l1-5.4A4 4 0 0 1 6 9.5Z"/><path d="M8 12v5M5.5 14.5h5M16.5 13h.01M19 15h.01"/>',
 globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 4.5 6 4.5 9s-1.5 6-4.5 9M12 3c-3 3-4.5 6-4.5 9S9 18 12 21"/>',
 grid:'<rect x="3" y="3" width="7" height="7" rx="1.3"/><rect x="14" y="3" width="7" height="7" rx="1.3"/><rect x="3" y="14" width="7" height="7" rx="1.3"/><rect x="14" y="14" width="7" height="7" rx="1.3"/>',
 wallet:'<rect x="3" y="6" width="18" height="15" rx="2"/><path d="M3 10h18M6 6V4h12v2"/><path d="M16 15h2"/>',
 card:'<rect x="2.5" y="5" width="19" height="14" rx="2"/><path d="M2.5 10h19M6 15h4"/>',
 backpack:'<rect x="5" y="7" width="14" height="15" rx="3"/><path d="M9 7V5a3 3 0 0 1 6 0v2M5 12h14M10 17h4"/>',
 gem:'<path d="M6 3h12l4 6-10 12L2 9zM2 9h20M6 3l2 6 4 12 4-12 2-6"/>',
 award:'<circle cx="12" cy="8" r="5"/><path d="m8 12-2 9 6-3 6 3-2-9"/>',
 building:'<rect x="4" y="4" width="16" height="17" rx="1.5"/><path d="M9 21v-5h6v5M8 8h1M15 8h1M8 12h1M15 12h1"/>',
 ban:'<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6 18.4 18.4"/>',
 flag:'<path d="M5 21V4m0 1c4-3 8 3 14 0v11c-6 3-10-3-14 0"/>',
 languages:'<path d="M3 5h12M9 3v2m3 0c-.4 5.3-3.2 9.4-8 12m2-7c1.6 2.8 4 5.2 7.6 7.1M15 21l4-10 4 10m-6.8-3h5.6"/>',
 settings:'<path d="M10 2.5h4l.7 2.1 2 .9 2.1-1 2.4 2.9-1.3 1.9.5 2.2L22 13l-1.5 3.4-2.3-.2-1.7 1.6.1 2.4-3.6 1.3-1.2-2.1h-2l-1.2 2.1-3.6-1.3.1-2.4-1.7-1.6-2.3.2L.6 13l1.7-1.5.5-2.2-1.3-1.9L4 4.5l2.1 1 2-.9z" transform="translate(1 0) scale(.91)"/><circle cx="12" cy="12" r="3"/>',
 shield:'<path d="M12 2.5 20 6v6c0 5-3.3 8.3-8 10-4.7-1.7-8-5-8-10V6z"/><path d="m8.5 12 2.5 2.5 4.8-5"/>',
 lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 15v2"/>',
 document:'<path d="M6 2.5h8L19 8v13H6zM14 2.5V8h5M9 12h7M9 16h7"/>',
 arrows:'<path d="M5 7h15m-4-4 4 4-4 4M19 17H4m4-4-4 4 4 4"/>',
 history:'<path d="M3 10a9 9 0 1 1 1 7M3 4v6h6M12 7v5l3 2"/>',
 chart:'<path d="M4 21V13h4v8M10 21V7h4v14M16 21V3h4v18M2 21h20"/>',
 gift:'<rect x="3" y="10" width="18" height="11" rx="1.5"/><path d="M2 7h20v4H2zM12 7v14M12 7C7.5 7 6 6 6 4.5a2.5 2.5 0 0 1 4.5-1.2C11.3 4.3 12 7 12 7Zm0 0s.7-2.7 1.5-3.7A2.5 2.5 0 0 1 18 4.5C18 6 16.5 7 12 7Z"/>',
 megaphone:'<path d="m4 10 14-6v16L4 14zM4 10H2v4h2M6 15l2 6h4l-2-7M20 9a4 4 0 0 1 0 6"/>',
 headset:'<path d="M3 13V11a9 9 0 0 1 18 0v2M3 13h3v7H4a2 2 0 0 1-2-2v-3a2 2 0 0 1 1-2m18 0h-3v7h2a2 2 0 0 0 2-2v-3a2 2 0 0 0-1-2M18 20a4 4 0 0 1-4 2h-2"/>',
 microphone:'<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v4m-4 0h8"/>',
 sliders:'<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="2"/><circle cx="15" cy="17" r="2"/>',
 menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
 chevron:'<path d="m15 18-6-6 6-6"/>',
 arrow:'<path d="m16 5-7 7 7 7M9 12h11"/>',
 refresh:'<path d="M20 7V3h-4M4 17v4h4"/><path d="M4.5 9a8 8 0 0 1 14-3L20 7M4 17l1.5 1a8 8 0 0 0 14-3"/>',
 sparkles:'<path d="m12 2 2.6 7.4L22 12l-7.4 2.6L12 22l-2.6-7.4L2 12l7.4-2.6z"/>',
 archive:'<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v11h14V9M10 13h4"/>',
 eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>'
});
const routeIcons={home:'home',discoverPreview:'compass',messages:'messages',me:'user',rechargePreview:'card',storage:'backpack',level:'gem',honor:'award',agencyPreview:'building',block:'ban',report:'flag',languages:'languages',settings:'settings'};
const categoryIcons={popular:'flame',vip:'crown',friends:'heart',music:'music',games:'gamepad',world:'globe',all:'grid'};
const adminIcons={overview:'grid',users:'users',rooms:'microphone',room_moderation:'shield',staff:'users',
 host_agencies:'building',recharge_agencies:'wallet',registrations:'document',agency_transfers:'arrows',
 audit:'history',finance_integrity:'shield',host_month:'chart',catalog:'gift',reports:'chart',
 global_gift:'megaphone',open_agency:'building',support:'headset',vip:'crown',
 medals:'award',special_id:'gem',banners:'megaphone',settlement:'wallet'};
const bottomRoomIcons={chatInput:'message',gift:'gift',messagesRoom:'messages',games:'gamepad',tools:'sliders'};
function svg(name,className=''){
 const path=icons[name];if(!path)return '';
 return '<svg class="tc-premium-svg '+className+'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" role="presentation" aria-hidden="true" focusable="false">'+path+'</svg>';
}
function paint(el,name){
 if(!el||!icons[name]||el.dataset.tcPremiumIcon===name)return;
 el.innerHTML=svg(name);
 el.dataset.tcPremiumIcon=name;
}
function decorate(){
 if(!live())return;
 document.documentElement.dataset.tcPremium='1';
 const root=document.getElementById('app');
 if(root){
  root.querySelectorAll('.tc-unified-nav button').forEach(b=>{
   if(b.querySelector('.tc-falcon-nav'))return; // Never replace the approved falcon identity.
   const icon=b.querySelector(':scope > span');
   paint(icon,b.classList.contains('royal-create')?'plus':routeIcons[b.dataset.v]);
  });
  root.querySelectorAll('.royal-category-row .royal-cat').forEach(b=>
   paint(b.querySelector('.royal-cat-icon'),categoryIcons[b.dataset.cat]));
  root.querySelectorAll('.royal-top-actions button').forEach(b=>{
   if(b.matches('[data-tc-social-open]'))paint(b,'users');
   else if(b.matches('[data-t57-open]'))paint(b,'bell');
   else if(b.getAttribute('aria-label')?.includes('بحث'))paint(b,'search');
  });
  root.querySelectorAll('.me-pencil,[data-a="go"][data-v="profileEdit"][aria-label]').forEach(b=>{
   if(b.dataset.tcPremiumIcon==='edit')return;
   if(b.matches('.me-pencil')||b.closest('.pr-top-actions')){
    b.innerHTML=svg('edit');
    b.dataset.tcPremiumIcon='edit';
   }
  });
  root.querySelectorAll('.pr-top-actions button[aria-label="رجوع"]').forEach(b=>{
   if(b.dataset.tcPremiumIcon==='arrow')return;
   b.innerHTML=svg('arrow');
   b.dataset.tcPremiumIcon='arrow';
  });
  root.querySelectorAll('.me-links .me-link').forEach(b=>
   paint(b.querySelector('.rich-icon'),routeIcons[b.dataset.v]));
  root.querySelectorAll('.me-more > button').forEach(b=>{
   if(b.matches('[data-tcac-entry]'))return;
   paint(b.querySelector('.more-icon'),routeIcons[b.dataset.v]);
  });
  root.querySelectorAll('.me-statcard .tc-stat-glyph').forEach((b,i)=>
   paint(b,['users','heart','user','eye'][i]));
  // Preserve all seats, names, overlays, mic indicators and custom animations.
  root.querySelectorAll('.roomBottom > button').forEach(b=>{
   const name=bottomRoomIcons[b.dataset.v];
   if(!name||b.dataset.tcPremiumIcon===name)return;
   if(b.querySelectorAll('input,span,.badge,.count').length)return;
   b.innerHTML=svg(name);
   b.dataset.tcPremiumIcon=name;
  });
 }
 const admin=document.getElementById('tcac-root');
 if(admin!==observedAdmin){
  observedAdmin=admin;
  adminObserver.disconnect();
  adminObserver.observe(document.body,{childList:true});
  if(admin)adminObserver.observe(admin,{childList:true,subtree:true});
 }
 if(admin){
  const entry=document.querySelector('#app [data-tcac-entry] .tcac-entry-icon');
  paint(entry,'shield');
  admin.querySelectorAll('button[data-tcac-view]').forEach(b=>
   paint(b.querySelector('.tcac-icon'),adminIcons[b.dataset.tcacView]));
  const back=admin.querySelector('.tcac-back'),refresh=admin.querySelector('.tcac-refresh');
  if(back&&back.dataset.tcPremiumIcon!=='arrow'){back.innerHTML=svg('arrow');back.dataset.tcPremiumIcon='arrow';}
  if(refresh&&refresh.dataset.tcPremiumIcon!=='refresh'){refresh.innerHTML=svg('refresh');refresh.dataset.tcPremiumIcon='refresh';}
  admin.querySelectorAll('.tcac-bottom button[data-tcac]').forEach(b=>{
   const name=({home:'home',modules:'grid',exit:'arrow'})[b.dataset.tcac];
   if(!name||b.dataset.tcPremiumIcon===name)return;
   b.insertAdjacentHTML('afterbegin',svg(name));
   b.dataset.tcPremiumIcon=name;
  });
 }
 const profileEntry=document.querySelector('#app [data-tcac-entry] .tcac-entry-icon');
 paint(profileEntry,'shield');
}
let pending=false;
function schedule(){
 if(pending||!live())return;
 pending=true;queueMicrotask(()=>{pending=false;decorate();});
}
const app=document.getElementById('app');
if(app)new MutationObserver(schedule).observe(app,{childList:true,subtree:true});
const adminObserver=new MutationObserver(schedule);
let observedAdmin=null;
adminObserver.observe(document.body,{childList:true}); // Admin overlay shell is a direct body child
window.addEventListener('totichat-phase2-auth',schedule);
schedule();
window.TotiPremiumIcons=Object.freeze({version:'1.0',styles:'premium-outline-quiet',refresh:schedule});
})();