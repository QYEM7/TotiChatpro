'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const code=fs.readFileSync(path.join(__dirname,'../app/phase2-live-mode.js'),'utf8');
function begin({search='?phase2Demo=1',hostname='localhost',protocol='https:',native=false}={}){
 let alarms=0;
 const ctx={
   URLSearchParams,
   location:{search,hostname,protocol},
   window:{Capacitor:{isNativePlatform:()=>native}},
   document:{body:{insertAdjacentHTML:()=>{alarms++}}},
 };
 vm.runInNewContext(code,ctx,{filename:'phase2-live-mode.js'});
 return alarms;
}
test('T10: Android native URL demo parameter cannot bypass a missing real Auth adapter',()=>{
 assert.equal(begin({native:true,search:'?phase2Demo=1'}),1);
 assert.equal(begin({native:true,search:'?mode=live&phase2Demo=1'}),1);
});
test('T10: explicit live website cannot bypass real Auth using phase2Demo query',()=>{
 assert.equal(begin({hostname:'preview.example.org',protocol:'https:',search:'?mode=live&phase2Demo=1'}),1);
});
test('T10: separate offline visual-preview site remains available only outside live mode',()=>{
 assert.equal(begin({hostname:'preview.example.org',protocol:'https:',search:'?phase2Demo=1'}),0);
});
test('T10: approved UI source and owner-approved art layers unchanged by the guard',()=>{
 const html=fs.readFileSync(path.join(__dirname,'../app/index.html'),'utf8');
 assert(html.includes('toti-nav-banner-refine.js'));
 assert(html.includes('room-seats-finish.css'));
 assert(html.includes('profile-stats-luxe.css'));
 assert(!code.includes("params.get('phase2Demo')==='1'"));
});
