/* Reference catalogs are read from the NEW backend, never from a baked-in seed.
 * Auth boundaries invalidate cache and pending responses. No financial writes.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth)return;
const queries=Object.freeze({
 gift_categories:'select=id,label,sort_order&order=sort_order.asc',
 cp_types:'select=id,label,is_primary,presentation,level_thresholds&order=id.asc',
 gift_catalog:'select=id,name,price,icon,category_id,relationship_type_id,description,preview_url,animation_type&order=price.asc',
 store_catalog:'select=id,name,category,price,currency,icon,description,duration_days,vip_level,is_reward,relationship_type_id,presentation,preview_url&order=price.asc',
 recharge_packages:'select=id,price_usd,gold_amount&order=price_usd.asc',
 recharge_reward_tiers:'select=id,label,threshold_usd,rewards&order=threshold_usd.asc'
});
let owner=auth.state().user?.id||'',generation=0;
const cache=new Map(),pending=new Map();
function sync(){
 const id=auth.state().user?.id||'';
 if(id!==owner){owner=id;generation++;cache.clear();pending.clear();}
 return id;
}
async function list(table,{force=false}={}){
 if(!Object.hasOwn(queries,table))throw new Error('Unknown catalog');
 if(!sync())throw new Error('Sign in to load catalogs');
 const entry=cache.get(table);
 if(!force&&entry&&Date.now()-entry.at<60000)return structuredClone(entry.rows);
 if(pending.has(table))return structuredClone(await pending.get(table));
 const before=generation,id=owner;
 const job=(async()=>{
  const rows=await auth.requestData('/rest/v1/'+table+'?'+queries[table]+'&limit=1000');
  sync();
  if(before!==generation||owner!==id)throw new Error('Account changed while loading catalog');
  if(!Array.isArray(rows))throw new Error('Invalid catalog response');
  if(rows.length>=1000)throw new Error('Catalog exceeds supported size; pagination required');
  cache.set(table,{at:Date.now(),rows:structuredClone(rows)});
  return rows;
 })();
 pending.set(table,job);
 try{return structuredClone(await job);}
 finally{if(pending.get(table)===job)pending.delete(table);}
}
window.addEventListener('totichat-phase2-auth',sync);
window.TotiPhase2Catalogs=Object.freeze({list});
})();
