// Staging-only read-only probe. Never needs or prints user credentials/tokens.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const staging = 'https://rziaedugbdwefbefcxjt.supabase.co';
const preview = 'https://totichat-login-review-20261013.vercel.app';
const publicConfig = readFileSync(new URL('../app/config.js',import.meta.url),'utf8');
const key = publicConfig.match(/publishableKey:\s*"(sb_publishable_[^"]+)"/)?.[1];
assert.ok(key?.startsWith('sb_publishable_'),'expected existing browser-safe publishable key');

const checks=[];
async function check(name,func){
  try{const detail=await func();checks.push({name,ok:true,detail});console.log('PASS '+name+(detail?': '+detail:''))}
  catch(error){checks.push({name,ok:false,reason:String(error.message).slice(0,180)});console.error('FAIL '+name+': '+String(error.message).slice(0,180))}
}
async function fetchTimeout(url,options={}){
  return fetch(url,{signal:AbortSignal.timeout(15000),...options});
}
await check('Independent review homepage responds',async()=>{
  const r=await fetchTimeout(preview+'/');
  assert.equal(r.status,200,'HTTP '+r.status);
  const html=await r.text();
  assert.match(html,/TotiChat/);assert.match(html,/Continue with Google/);
  assert.doesNotMatch(html,/Continue with Apple|Continue with Phone/);
  return 'HTTP 200, Google-only markup';
});
await check('Latest review login controller deployed',async()=>{
  const r=await fetchTimeout(preview+'/login.js');
  assert.equal(r.status,200,'HTTP '+r.status);
  const body=await r.text();
  assert.ok(body.includes("totichat-login-review-20261013.vercel.app"));
  assert.ok(body.includes("signInWithProvider('google')"));
  return 'matching approved host and provider';
});
await check('Published CSS loads',async()=>{
  const r=await fetchTimeout(preview+'/login.css');
  assert.equal(r.status,200,'HTTP '+r.status);
  assert.ok((await r.text()).includes('grid-template-columns'));
  return 'HTTP 200';
});
await check('Self-hosted Google auth adapter is deployed with strict server logout behavior',async()=>{
  const r=await fetchTimeout(preview+'/auth-adapter.js');
  assert.equal(r.status,200,'HTTP '+r.status);
  const body=await r.text();
  assert.ok(body.includes('TotiPhase2Auth'));
  assert.ok(body.includes("/auth/v1/logout?scope=local"));
  assert.ok(body.includes('server could not confirm session revocation'));
  assert.ok(!/sb_secret_|service_role/.test(body));
  return 'HTTP 200; server-signout error handling and local session scope';
});
await check('Preview enforces strict CSP and referrer policy',async()=>{
  const r=await fetchTimeout(preview+'/');
  assert.equal(r.status,200,'HTTP '+r.status);
  const csp=r.headers.get('content-security-policy')||'';
  assert.ok(csp.includes("script-src 'self'"),'missing same-origin script restriction');
  assert.ok(csp.includes("frame-ancestors 'none'"),'missing frame protection');
  assert.equal(r.headers.get('referrer-policy'),'no-referrer');
  const html=await r.text();
  assert.ok(html.includes('src="./auth-adapter.js"'));
  assert.ok(html.includes('src="./backend-config.js"'));
  return 'CSP and same-origin scripts enforced';
});
await check('Google enabled on Supabase Staging',async()=>{
  const r=await fetchTimeout(staging+'/auth/v1/settings',{headers:{apikey:key,Accept:'application/json'}});
  assert.equal(r.status,200,'HTTP '+r.status);
  const obj=await r.json();
  const ext=obj.external||obj.external_providers||{};
  assert.equal(ext.google,true,'external.google is not enabled');
  return 'public provider setting enabled';
});
await check('No other social sign-in providers enabled in staging',async()=>{
  const r=await fetchTimeout(staging+'/auth/v1/settings',{headers:{apikey:key,Accept:'application/json'}});
  assert.equal(r.status,200,'HTTP '+r.status);
  const obj=await r.json();
  const ext=obj.external||obj.external_providers||{};
  const unexpected=Object.entries(ext).filter(([name,enabled])=>name!=='google'&&enabled===true).map(([name])=>name);
  assert.deepEqual(unexpected,[],'non-Google providers enabled: '+unexpected.join(','));
  return 'Google is the only enabled social provider';
});
await check('Unauthorized session is blocked',async()=>{
  const r=await fetchTimeout(staging+'/auth/v1/user',{headers:{apikey:key,Accept:'application/json'}});
  assert.ok(r.status===401||r.status===403,'unauthenticated /user returned HTTP '+r.status);
  return 'HTTP '+r.status;
});
await check('Google authorize endpoint initiates provider redirect',async()=>{
  const u=new URL(staging+'/auth/v1/authorize');
  u.searchParams.set('provider','google');
  u.searchParams.set('redirect_to',preview+'/?mode=live');
  u.searchParams.set('code_challenge','K2Y3V8qOfglKbhniAJjPvHkEkkxBqPlZGehLTmMeaPY');
  u.searchParams.set('code_challenge_method','s256');
  const r=await fetchTimeout(u.href,{headers:{apikey:key},redirect:'manual'});
  assert.ok([301,302,303,307,308].includes(r.status),'HTTP '+r.status);
  const target=new URL(r.headers.get('location')||'',u.href);
  assert.ok(target.hostname.endsWith('.google.com')||target.hostname.endsWith('.googleusercontent.com'),'unexpected provider redirect host '+target.hostname);
  return 'HTTP '+r.status+' redirect to Google (does not prove final callback)';
});
console.log('SUMMARY '+checks.filter(x=>x.ok).length+'/'+checks.length);
if(checks.some(x=>!x.ok))process.exitCode=1;
