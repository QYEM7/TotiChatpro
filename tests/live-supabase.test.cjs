// GitHub Actions live integration check for public TotiChatpro Supabase data.
// Reads browser public config. No service role credentials or secrets required.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const config=fs.readFileSync(path.join(__dirname,'../app/config.js'),'utf8');
const sandbox={window:{}};
vm.runInNewContext(config,sandbox,{filename:'app/config.js'});
const settings=sandbox.window.TOTICHAT_PUBLIC_BACKEND;
test('browser can read real published home banners using only the publishable key',async()=>{
  assert.match(settings.supabaseUrl,/^https:\/\/[a-z0-9-]+\.supabase\.co$/);
  assert.match(settings.publishableKey,/^sb_publishable_[A-Za-z0-9_-]+$/);
  const api=settings.supabaseUrl+'/rest/v1/home_banners?select='+encodeURIComponent('id,title,image_url,link_kind,link_target,sort_order,status,starts_at,ends_at')+'&order=sort_order.asc&limit=30';
  const response=await fetch(api,{headers:{apikey:settings.publishableKey,Accept:'application/json'},signal:AbortSignal.timeout(15000)});
  assert.equal(response.status,200,'Supabase anonymous REST read should succeed (HTTP '+response.status+')');
  const items=await response.json();
  assert.ok(Array.isArray(items));
  assert.ok(items.length>=3,'Three genuine official project announcements should be published');
  const expected=['TotiChat — المعاينة الرسمية','واجهات TotiChat — قيد التطوير','نظام الوكالات — معاينة تفاعلية'];
  for(const title of expected){
    const item=items.find(x=>x.title===title);
    assert.ok(item,'Missing published announcement: '+title);
    assert.equal(item.status,'published');
    assert.match(item.image_url,/^https:\/\/qyem7\.github\.io\/TotiChatpro\/assets\/images\//);
  }
  for(const x of items){
    if(x.starts_at)assert.ok(Date.parse(x.starts_at)<=Date.now());
    if(x.ends_at)assert.ok(Date.parse(x.ends_at)>Date.now());
  }
  console.log('Verified public Supabase REST: '+items.length+' genuine active published announcements.');
});
