'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
test('slow old wallet cannot block or overwrite the next account wallet',async()=>{
 let user={id:'a'};const events={},requests=[];
 const window={TotiLiveMode:{enabled:true},TotiPhase2Auth:{
  state:()=>({user,signedIn:!!user}),
  requestData:url=>new Promise(resolve=>requests.push({url,resolve}))
 },addEventListener:(name,fn)=>{events[name]=fn;}};
 const ctx={window,document:{querySelector:()=>null,querySelectorAll:()=>[]},render:()=>{},screen:'home',Number,String,Array,Object};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../app/phase2-wallet.js'),'utf8'),ctx);
 events['totichat-phase2-auth']();assert.equal(requests.length,2);
 user={id:'b'};events['totichat-phase2-auth']();assert.equal(requests.length,4);
 requests[2].resolve([{user_id:'b',coins:20,diamonds:3}]);requests[3].resolve([]);
 await new Promise(r=>setImmediate(r));
 assert.equal(window.TotiPhase2Wallet.status().ownerId,'b');
 assert.equal(window.TotiPhase2Wallet.status().coins,'20');
 requests[0].resolve([{user_id:'a',coins:999,diamonds:99}]);requests[1].resolve([]);
 await new Promise(r=>setImmediate(r));
 assert.equal(window.TotiPhase2Wallet.status().coins,'20');
});
