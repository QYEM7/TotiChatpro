/* Verified state sync: refresh true backend records after admin changes or foreground.
 * Never infer permissions, coins, medals, VIP or banners from a client event.
 * No dummy data and no direct database mutation.
 */
(function(){
'use strict';
if(!window.TotiLiveMode?.enabled||!window.TotiPhase2Auth)return;
const auth=window.TotiPhase2Auth;
let inflight=false,last=0;
async function refresh(force=false){
 const user=auth.state()?.user?.id;
 if(!auth.state()?.signedIn||!user||document.hidden||inflight)return;
 if(!force&&Date.now()-last<30000)return;
 inflight=true;last=Date.now();
 try{
  const work=[
   window.TotiBannerData?.refresh?.(),
   window.TotiPhase2Wallet?.refresh?.(),
   window.TotiVipStatus?.refresh?.(),
   window.TotiMedals?.refresh?.(),
   window.TotiNotifications?.refresh?.(),
   window.TotiSocial?.refresh?.(),
   window.TotiGlobalGiftFeed?.refresh?.(),
   window.TotiLuckyGiftUI?.refreshOpen?.(),
   window.TotiInAppAdmin?.recheck?.()
  ];
  if(window.TotiPhase2Rooms?.getStatus?.()?.activeRoomId)
   work.push(window.TotiPhase2Rooms.refreshRoom());
  await Promise.allSettled(work.filter(x=>x&&typeof x.then==='function'));
 }finally{inflight=false}
}
window.addEventListener('totichat-admin-action-confirmed',()=>{void refresh(true)});
window.addEventListener('totichat-lucky-policy-updated',()=>{void refresh(true)});
window.addEventListener('totichat-phase2-auth',()=>{last=0;void refresh(true)});
window.addEventListener('focus',()=>{void refresh()});
window.addEventListener('online',()=>{void refresh(true)});
document.addEventListener('visibilitychange',()=>{if(!document.hidden)void refresh(true)});
setInterval(()=>{void refresh()},45000);
window.TotiVerifiedStateSync=Object.freeze({refresh:()=>refresh(true)});
})();
