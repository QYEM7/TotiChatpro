/* TotiChat home-banner data validation. Shared by browser and CI tests. */
(function(root,factory){
  const core=factory();
  if(typeof module==='object' && module.exports) module.exports=core;
  root.TotiBannerCore=core;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const screens=new Set(['home','room','ranks','cp','agencyPreview','agency','storePreview','vip','wallet','me','tour','profilePreview','rechargePreview','discoverPreview']);
  function https(value){
    if(typeof value!=='string'||value.length>2048)return null;
    try{const u=new URL(value.trim());return u.protocol==='https:'&&u.hostname&&!u.username&&!u.password?u.href:null;}catch{return null;}
  }
  function normalizedRow(row,now=Date.now()){
    if(!row||typeof row!=='object'||row.status!=='published')return null;
    const id=String(row.id||'');
    const title=typeof row.title==='string'?row.title.trim():'';
    const url=https(row.image_url);
    if(!id||id.length>100||title.length<1||title.length>120||!url)return null;
    const start=row.starts_at?Date.parse(row.starts_at):null;
    const end=row.ends_at?Date.parse(row.ends_at):null;
    if((row.starts_at&&!Number.isFinite(start))||(row.ends_at&&!Number.isFinite(end)))return null;
    if((start!==null&&start>now)||(end!==null&&end<=now))return null;
    const kind=row.link_kind||'none',rawTarget=String(row.link_target||'').trim();
    let target=null;
    if(kind==='external'){target=https(rawTarget);if(!target)return null;}
    else if(kind==='screen'){if(!screens.has(rawTarget))return null;target=rawTarget;}
    else if(kind!=='none'||rawTarget)return null;
    const order=Number.isInteger(row.sort_order)?row.sort_order:100;
    return {id,title,imageUrl:url,kind,target,sortOrder:order};
  }
  function normalize(data,now=Date.now()){
    if(!Array.isArray(data))return [];
    const found=new Set();
    return data.map(x=>normalizedRow(x,now)).filter(x=>{
      if(!x||found.has(x.id))return false;found.add(x.id);return true;
    }).sort((a,b)=>a.sortOrder-b.sortOrder||a.id.localeCompare(b.id)).slice(0,12);
  }
  function escape(value){return String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  return Object.freeze({https,normalize,normalizedRow,escape,allowedScreens:[...screens]});
});
