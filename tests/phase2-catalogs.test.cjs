'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
function setup(responder){
 let user={id:'account-a'};const events={};const calls=[];
 const window={TotiPhase2Auth:{
  state:()=>({user,signedIn:!!user}),
  requestData:async url=>{calls.push(url);return responder(url);}
 },addEventListener:(name,fn)=>events[name]=fn};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../app/phase2-catalog-data.js'),'utf8'),{window,structuredClone,Date,Map,Error,Object});
 return {api:window.TotiPhase2Catalogs,calls,switch:id=>{user=id?{id}:null;events['totichat-phase2-auth']();}};
}
test('catalog requests deduplicate, return independent snapshots and prohibit unlisted tables',async()=>{
 let resolve;const app=setup(()=>new Promise(r=>resolve=r));
 const a=app.api.list('gift_catalog'),b=app.api.list('gift_catalog');
 resolve([{id:'g1',name:'Rose',price:10}]);
 const [first,second]=await Promise.all([a,b]);
 assert.equal(app.calls.length,1);
 first[0].price=999;assert.equal(second[0].price,10);
 assert.equal((await app.api.list('gift_catalog'))[0].price,10);
 await assert.rejects(app.api.list('wallets'),/Unknown catalog/);
 assert.equal(app.calls.length,1);
});
test('logout and account switch discard pending catalog responses and caches',async()=>{
 const resolvers=[];const app=setup(()=>new Promise(r=>resolvers.push(r)));
 const pending=app.api.list('store_catalog');app.switch('account-b');
 const next=app.api.list('store_catalog');
 resolvers[0]([{id:'old'}]);resolvers[1]([{id:'new'}]);
 await assert.rejects(pending,/Account changed/);
 assert.equal((await next)[0].id,'new');
 app.switch(null);await assert.rejects(app.api.list('store_catalog'),/Sign in/);
});
test('backend failure never substitutes seed or demo rows and can be retried',async()=>{
 let fail=true;const app=setup(()=>{if(fail)throw Error('offline');return [];});
 await assert.rejects(app.api.list('gift_catalog'),/offline/);
 fail=false;assert.equal((await app.api.list('gift_catalog')).length,0);
});
test('malformed or truncated catalogs fail instead of silently showing incomplete choices',async()=>{
 const app=setup(()=>({rows:[]}));await assert.rejects(app.api.list('cp_types'),/Invalid catalog/);
 const huge=setup(()=>Array.from({length:1000},()=>({id:'x'})));
 await assert.rejects(huge.api.list('cp_types'),/pagination/);
});
