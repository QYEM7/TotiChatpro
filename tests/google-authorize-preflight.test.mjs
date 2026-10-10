import test from 'node:test';
import assert from 'node:assert/strict';
import {publicConfig,isSafeGoogleRedirect,probe,NATIVE_CALLBACK} from '../scripts/inspect-google-authorize-preflight.mjs';

const origin='https://sqedsnyvjblvbjbizcay.supabase.co';
const cfg='window.TOTICHAT_PUBLIC_BACKEND={supabaseUrl:"'+origin+'",publishableKey:"sb_publishable_PUBLIC_TEST"}';
const response=(status,body,location)=>({
 status,ok:status>=200&&status<300,json:async()=>body,
 headers:new Headers(location?{location}:{})
});
function google(){
 const u=new URL('https://accounts.google.com/o/oauth2/v2/auth');
 u.searchParams.set('redirect_uri',origin+'/auth/v1/callback');
 u.searchParams.set('client_id','public-client-id');
 return u.href;
}
test('rejects non-public keys or non-Supabase domains',()=>{
 assert.equal(publicConfig(cfg).origin,origin);
 assert.throws(()=>publicConfig(cfg.replace('sb_publishable_','sb_secret_')));
 assert.throws(()=>publicConfig(cfg.replace(origin,'https://evil.example')));
});
test('disabled provider stops before authorize',async()=>{
 let calls=0;
 const result=await probe({configText:cfg,fetchImpl:async()=>{
  calls++;return response(200,{external:{google:false}});
 }});
 assert.equal(calls,1);assert.equal(result.google_enabled,false);
 assert.equal(result.oauth_initiation_verified,false);
});
test('Google 302 and PKCE initiation never claim real Android sign-in',async()=>{
 const calls=[];
 const result=await probe({configText:cfg,fetchImpl:async(url,opts)=>{
  calls.push({url,opts});
  return calls.length===1?response(200,{external:{google:true}}):response(302,null,google());
 }});
 assert.equal(calls.length,2);
 const url=new URL(calls[1].url);
 assert.equal(url.pathname,'/auth/v1/authorize');
 assert.equal(url.searchParams.get('provider'),'google');
 assert.equal(url.searchParams.get('redirect_to'),NATIVE_CALLBACK);
 assert.equal(url.searchParams.get('code_challenge_method'),'s256');
 assert.match(url.searchParams.get('code_challenge'),/^[A-Za-z0-9_-]{43}$/);
 assert.equal(calls[1].opts.redirect,'manual');
 assert.equal(result.oauth_initiation_verified,true);
 assert.equal(result.native_callback_verified,false);
 assert.equal(result.real_login_verified,false);
 assert.equal(result.android_hardware_verified,false);
 assert.doesNotMatch(JSON.stringify(result),/client_id|sb_publishable_|access_token/);
});
test('malicious or wrong google redirects cannot be accepted',async()=>{
 assert.equal(isSafeGoogleRedirect('https://accounts.google.com.evil.test/o/oauth2/v2/auth',origin),false);
 assert.equal(isSafeGoogleRedirect('https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=https://wrong.supabase.co/auth/v1/callback',origin),false);
 const result=await probe({configText:cfg,fetchImpl:async url=>
  url.endsWith('/settings')?response(200,{external:{google:true}}):response(302,null,'https://evil.example')});
 assert.equal(result.oauth_initiation_verified,false);
 assert.match(result.status,/BLOCKED/);
});
