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
  assert.notEqual(settings.supabaseUrl,'https://sqedsnyvjblvbjbizcay.supabase.co','Never run browser smoke test against production');
  assert.match(settings.publishableKey,/^sb_publishable_[A-Za-z0-9_-]+$/);
  const api=settings.supabaseUrl+'/rest/v1/home_banners?select='+encodeURIComponent('id,title,image_url,link_kind,link_target,sort_order,status,starts_at,ends_at')+'&order=sort_order.asc&limit=30';
  const response=await fetch(api,{headers:{apikey:settings.publishableKey,Accept:'application/json'},signal:AbortSignal.timeout(15000)});
  assert.equal(response.status,200,'Supabase anonymous REST read should succeed (HTTP '+response.status+')');
  const items=await response.json();
  assert.ok(Array.isArray(items));
  // Real staging data can legitimately contain zero official banners until
  // an administrator publishes genuine content. Never force seed/test ads.
  assert.ok(items.length<=30,'REST limit must be enforced by the server');
  const seen=new Set();
  for(const item of items){
    assert.ok(item&&typeof item.id==='string'&&item.id.length>0,'A persisted banner needs a valid ID');
    assert.ok(!seen.has(item.id),'A published banner must not be duplicated');
    seen.add(item.id);
    assert.equal(item.status,'published','Only admin-published content is eligible');
    assert.ok(typeof item.title==='string'&&item.title.trim().length>0);
    const img=new URL(item.image_url);
    assert.equal(img.protocol,'https:','Only HTTPS image URLs are allowed');
    assert.equal(img.username,'');
    assert.equal(img.password,'');
    if(item.link_kind==='external'){
      const link=new URL(item.link_target);
      assert.equal(link.protocol,'https:');
      assert.equal(link.username,'');
      assert.equal(link.password,'');
    }
  }
  for(const x of items){
    if(x.starts_at)assert.ok(Date.parse(x.starts_at)<=Date.now());
    if(x.ends_at)assert.ok(Date.parse(x.ends_at)>Date.now());
  }
  console.log('Verified public Supabase REST: '+items.length+' genuine active published announcements.');
});
