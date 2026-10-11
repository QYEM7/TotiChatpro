/* Live backend VIP identity: real entitlement only. Does not grant/charge VIP
 * or repaint approved frames; it never displays preview example tiers/levels.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
let owner='',generation=0,loadedAt=0,status=null,pending=null,error='';
function signed(){return auth.state().signedIn===true&&auth.state().user?.id===owner}
function visible(){return screen==='me'||screen==='profilePreview'}
function clearBadges(node,vip){
 if(!node)return;
 const level=document.createElement('span');
 const vipLabel=document.createElement('span');
 vipLabel.textContent=vip;
 level.textContent='المستوى غير مرتبط بالخادم بعد';
 node.replaceChildren(vipLabel,level);
}
function description(){
 if(error)return '👑 VIP · تعذّر التحقق';
 if(status===null)return '👑 VIP · جارٍ التحقق';
 if(status.active===true&&Number.isInteger(status.tier)&&status.tier>=1&&status.tier<=10)
  return '👑 VIP '+status.tier;
 return '👑 VIP غير مفعّل';
}
function paint(){
 if(!signed()||!visible())return;
 const vip=description();
 const main=$('.me-vip-banner strong');
 if(main)main.textContent=vip;
 clearBadges($('.me-summary .vip-labels'),vip);
 clearBadges($('.pr-person-meta .pr-vipstrip'),vip);
}
async function refresh(force=false){
 if(!signed()||!visible()||pending)return;
 if(!force&&loadedAt&&Date.now()-loadedAt<30000)return;
 const id=owner,stamp=generation;
 pending=(async()=>{
  try{
   const result=await auth.requestData('/rest/v1/rpc/phase5_vip_status',{
    method:'POST',body:{p_target:id}
   });
   if(stamp!==generation||!signed()||id!==owner)return;
   if(!result||result.userId!==id||!Number.isInteger(result.tier)||
      result.tier<0||result.tier>10||
      typeof result.active!=='boolean'||
      (result.active&&result.tier===0))
    throw Error('Invalid entitlement response');
   status=result;loadedAt=Date.now();error='';
  }catch(e){
   if(stamp!==generation||!signed()||id!==owner)return;
   error='VIP status unavailable';status=null;loadedAt=Date.now();
  }finally{
   if(stamp===generation){pending=null;paint()}
  }
 })();
 return pending;
}
function mount(){
 const id=auth.state().user?.id||'';
 if(!id){return}
 if(id!==owner){
  generation++;owner=id;loadedAt=0;status=null;error='';pending=null;
 }
 if(!visible())return;
 paint();
 void refresh();
}
const prev=window.render;
window.render=function(){
 const output=prev.apply(this,arguments);
 mount();
 return output;
};
window.addEventListener('totichat-phase2-auth',()=>{
 const id=auth.state().user?.id||'';
 if(id!==owner){
  generation++;owner=id;status=null;error='';loadedAt=0;pending=null;
 }
 if(id)mount();
});
window.addEventListener('focus',()=>{
 if(signed()&&visible())void refresh(true);
});
window.TotiVipStatus=Object.freeze({refresh:()=>refresh(true),isInstalled:()=>true});
queueMicrotask(mount);
})();
