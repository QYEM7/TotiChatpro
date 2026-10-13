import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const root = new URL('../design/reference-fusion-20261013/login/', import.meta.url);
const html = fs.readFileSync(new URL('index.html', root), 'utf8');
const css = fs.readFileSync(new URL('login.css', root), 'utf8');
const script = fs.readFileSync(new URL('login.js', root), 'utf8');

test('login screen has exactly one visible sign-in method', () => {
  assert.match(html, /Continue with Google/);
  assert.doesNotMatch(html, /Continue with (Apple|Phone|Email|Facebook)/);
  assert.doesNotMatch(html, /type="password"|type="tel"/);
  assert.match(script, /signInWithProvider\('google'\)/);
  assert.match(html,/src="\\.\\/auth-adapter\\.js"/);
  assert.match(html,/src="\\.\\/backend-config\\.js"/);
  assert.doesNotMatch(html,/cdn\\.jsdelivr\\.net\\/gh\\/QYEM7\\/TotiChatpro.*app\\/phase2-auth/);
  assert.doesNotMatch(script, /service_role|sb_secret_|mockSuccess|fakeUser/);
});
test('mobile UI and accessibility contracts exist', () => {
  assert.match(html, /aria-live="polite"/);
  assert.match(html, /id="signed-out-panel"/);
  assert.match(html, /id="signed-in-panel"[^>]+hidden/);
  assert.match(css, /@media \(max-width: 760px\)/);
  assert.match(css, /@media \(max-width: 380px\)/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /focus-visible/);
});
test('production app files are not part of login directory', () => {
  assert.doesNotMatch(script, /INSERT INTO|admin_password|seed_data/);
  assert.match(script, /allowedHosts/);
  assert.match(script, /auth\.securityState\(\)/);
  assert.match(script, /auth\.readProfile\(\)/);
});

function harness({hostname='totichat-login-review-20261013.vercel.app',online=true,signedIn=false,verify=true,provider=true} = {}) {
  const listeners = new Map();
  function mockEl(id) {
    return { id, hidden:id==='signed-in-panel', disabled:false, textContent:'', dataset:{},
      listeners:{}, attrs:{},
      addEventListener(kind,callback){ this.listeners[kind]=callback; },
      setAttribute(k,v){this.attrs[k]=v}
    };
  }
  const elements = Object.fromEntries([
    'google-button','auth-message','signed-out-panel','signed-in-panel',
    'account-summary','signout-button','continue-link'
  ].map(id=>[id,mockEl(id)]));
  let currentUser=signedIn?{id:'real-user-1',email:'verified@example.test'}:null;
  let currentProfile=null;
  const calls=[];
  const auth={
    state(){return {signedIn:!!currentUser,user:currentUser,profile:currentProfile}},
    async providers(){calls.push('providers');return {google:provider}},
    async signInWithProvider(s){calls.push('signIn:'+s)},
    async securityState(){calls.push('security');if(!verify)throw Error('invalid')},
    async readProfile(){
      calls.push('profile');
      currentProfile=currentUser?{id:currentUser.id}:null;
      listeners.get('totichat-phase2-auth')?.();
    },
    async signOut(){calls.push('signOut');currentUser=null;currentProfile=null}
  };
  const window={
    TotiPhase2Auth:auth,
    Capacitor:null,
    addEventListener(event,handler){listeners.set(event,handler)}
  };
  const context={
    window, location:{protocol:'https:',hostname},
    document:{getElementById(id){return elements[id]},querySelector(){return null}},
    navigator:{onLine:online},
    console
  };
  vm.runInNewContext(script,context,{timeout:3000,filename:'login.js'});
  return {elements,calls,auth,listeners,setUser(user){currentUser=user}};
}
const flush=async()=>{for(let i=0;i<5;i++) await new Promise(resolve=>setImmediate(resolve))};

test('Google click invokes existing provider and never fakes success',async()=>{
  const h=harness();
  await flush();
  await h.elements['google-button'].listeners.click();
  assert.deepEqual(h.calls.filter(x=>x.startsWith('signIn:')),['signIn:google']);
  assert.equal(h.elements['signed-in-panel'].hidden,true);
});
test('unapproved host prevents sign-in',async()=>{
  const h=harness({hostname:'unapproved.example.com'});
  await flush();
  await h.elements['google-button'].listeners.click();
  assert.equal(h.calls.filter(x=>x.startsWith('signIn:')).length,0);
  assert.match(h.elements['auth-message'].textContent,/not been authorized/);
});
test('offline mode never tries OAuth',async()=>{
  const h=harness({online:false});
  await flush();
  await h.elements['google-button'].listeners.click();
  assert.equal(h.calls.filter(x=>x.startsWith('signIn:')).length,0);
  assert.match(h.elements['auth-message'].textContent,/offline/);
});
test('provider disabled on server prevents OAuth',async()=>{
  const h=harness({provider:false});
  await flush();
  await h.elements['google-button'].listeners.click();
  assert.equal(h.calls.filter(x=>x.startsWith('signIn:')).length,0);
  assert.match(h.elements['auth-message'].textContent,/not enabled/);
});
test('server-verified signed-in session appears only after auth checks',async()=>{
  const h=harness({signedIn:true,verify:true});
  await flush();
  assert.equal(h.elements['signed-in-panel'].hidden,false);
  assert.equal(h.elements['signed-out-panel'].hidden,true);
  assert.equal(h.elements['continue-link'].hidden,true,'Do not promise cross-origin session handoff');
  assert.ok(h.calls.includes('security'));
  assert.ok(h.calls.includes('profile'));
});
test('cached but server-rejected session is not presented as verified',async()=>{
  const h=harness({signedIn:true,verify:false});
  await flush();
  assert.equal(h.elements['signed-in-panel'].hidden,true);
  assert.match(h.elements['auth-message'].textContent,/could not be verified/);
});
test('sign-out revokes through adapter and returns to signed-out view',async()=>{
  const h=harness({signedIn:true});
  await flush();
  await h.elements['signout-button'].listeners.click();
  assert.ok(h.calls.includes('signOut'));
  assert.equal(h.elements['signed-in-panel'].hidden,true);
  assert.equal(h.elements['signed-out-panel'].hidden,false);
});


test('profile events cannot recursively trigger unbounded session checks',async()=>{
  const h=harness({signedIn:true});
  await flush();
  assert.equal(h.elements['signed-in-panel'].hidden,false);
  const before=h.calls.filter(x=>x==='profile').length;
  assert.equal(before,1,'one profile read is sufficient for an account');
  h.listeners.get('totichat-phase2-auth')?.();
  await flush();
  assert.equal(h.calls.filter(x=>x==='profile').length,1,'revalidated profile should be cached');
});
