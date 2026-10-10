'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const src=fs.readFileSync(require('node:path').join(__dirname,'../app/phase2-auth.js'),'utf8');
const UUID='94c0e8fb-126e-4149-ad30-6f25e3c99c33';
function init(responder){
  const requests=[],map=new Map(),events=[];
  const storage={
    getItem:key=>map.get(key)??null,
    setItem:(key,value)=>map.set(key,value),
    removeItem:key=>map.delete(key)
  };
  const win={
    TOTICHAT_PUBLIC_BACKEND:{
      supabaseUrl:'https://sqedsnyvjblvbjbizcay.supabase.co',
      publishableKey:'sb_publishable_TEST_public_only'
    },
    dispatchEvent:(e)=>events.push(e),
    addEventListener:()=>{}
  };
  const ctx={window:win,sessionStorage:storage,URL,Date,console,Blob,
    clearTimeout:()=>{},setTimeout:()=>1,queueMicrotask:()=>{},
    CustomEvent:function(type,opts){this.type=type;this.detail=opts.detail;},
    fetch:async (url,options)=>{
      requests.push({url,options});
      const response=await responder(url,options);
      return {ok:response.status<400,status:response.status,
        text:async()=>JSON.stringify(response.data),json:async()=>response.data,blob:async()=>response.data};
    }
  };
  vm.runInNewContext(src,ctx,{filename:'phase2-auth.js'});
  return {auth:win.TotiPhase2Auth,requests,map,events};
}
const row={
  id:UUID,display_name:'مستخدم جديد',bio:'',
  avatar_url:null,created_at:'2026-10-10T00:00:00Z',updated_at:'2026-10-10T00:00:00Z'
};
test('real signup sends only display name metadata to independent Auth, not legacy DB',async()=>{
  const app=init(async(url,opts)=>{
    assert.match(url,/sqedsnyvjblvbjbizcay\.supabase\.co\/auth\/v1\/signup/);
    const body=JSON.parse(opts.body);
    assert.deepEqual(Object.keys(body).sort(),['data','email','password']);
    assert.equal(body.data.display_name,'مريم');
    assert.equal(body.password,'strong-pass-123');
    return {status:200,data:{user:{id:UUID},session:null}};
  });
  const x=await app.auth.signUp({email:'test@example.org',password:'strong-pass-123',displayName:'مريم'});
  assert.equal(x.confirmationRequired,true);
  assert.equal(x.signedIn,false);
  assert.equal(app.auth.state().user,null);
  assert.equal(app.map.get('totichat.phase2.session.v1'),undefined);
  assert.equal(app.map.get('totichat.phase2.pending-email.v1'),'test@example.org');
});
test('sign-in reads profile under JWT, updates only allowlisted fields and revokes local session',async()=>{
  const authResult={
    access_token:'access.TEST_TOKEN',refresh_token:'refresh.TEST_TOKEN',expires_in:3600,
    user:{id:UUID,email:'test@example.org'}
  };
  const app=init(async(url,opts)=>{
    if(url.includes('/auth/v1/token?grant_type=password'))return{status:200,data:authResult};
    if(url.includes('/rest/v1/profiles')&&opts.method==='GET'){
      assert.equal(opts.headers.Authorization,'Bearer access.TEST_TOKEN');
      assert.ok(url.includes('id=eq.'+UUID));
      return {status:200,data:[row]};
    }
    if(url.includes('/rest/v1/profiles')&&opts.method==='PATCH'){
      assert.equal(opts.headers.Authorization,'Bearer access.TEST_TOKEN');
      assert.deepEqual(Object.keys(JSON.parse(opts.body)).sort(),['bio','display_name']);
      assert.match(url,/id=eq\./);
      return {status:200,data:[{...row,display_name:'زينب',bio:'الملف الحقيقي'}]};
    }
    if(url.includes('/auth/v1/logout'))return{status:204,data:null};
    throw Error('Unmocked URL: '+url);
  });
  await app.auth.signIn({email:'test@example.org',password:'strong-pass-123'});
  assert.equal(app.auth.state().signedIn,true);
  assert.equal(app.auth.state().profile.display_name,'مستخدم جديد');
  assert.equal(app.auth.state().user.email,'test@example.org');
  assert.equal('access_token' in app.auth.state(),false);
  const value=await app.auth.updateProfile({display_name:'زينب',bio:'الملف الحقيقي',gold:100000,vip:10});
  assert.equal(value.display_name,'زينب');
  assert.equal(app.auth.state().profile.display_name,'زينب');
  const store=app.map.get('totichat.phase2.session.v1');
  assert.equal(store.includes('strong-pass-123'),false,'Never persist password');
  await app.auth.signOut();
  assert.equal(app.auth.state().signedIn,false);
  assert.equal(app.map.has('totichat.phase2.session.v1'),false);
});
test('token refresh and invalid credentials never produce local false-success state',async()=>{
  const app=init(async(url)=>({status:400,data:{msg:'Invalid login credentials'}}));
  await assert.rejects(()=>app.auth.signIn({email:'test@example.org',password:'bad-but-long'}),/Invalid login credentials/);
  assert.equal(app.auth.state().signedIn,false);
  assert.equal(app.requests.length,1);
  assert.equal(app.map.size,0);
});
test('phase2 source has no old database or embedded elevated key',()=>{
  assert.doesNotMatch(src,/bfadhdnudmsggylunhlh/);
  assert.doesNotMatch(src,/sb_secret_|service_role\s*[:=]/);
  assert.match(src,/credentials:'omit'/);
});
test('account security changes use authenticated endpoints and reject invalid MFA input',async()=>{
 const token={access_token:'access.SECURITY',refresh_token:'refresh.SECURITY',expires_in:3600,user:{id:UUID,email:'security@test.invalid'}};
 const app=init(async(url,opts)=>{
  if(url.includes('grant_type=password'))return {status:200,data:token};
  if(url.includes('/rest/v1/profiles'))return {status:200,data:[row]};
  assert.equal(opts.headers.Authorization,'Bearer access.SECURITY');
  if(url.endsWith('/auth/v1/user')&&opts.method==='GET')return {status:200,data:{...token.user,email_confirmed_at:'2026-10-10',factors:[{id:UUID,status:'verified',factor_type:'totp'}],identities:[{provider:'google',identity_id:UUID}]}};
  if(url.endsWith('/auth/v1/user')&&opts.method==='PUT'){assert.deepEqual(JSON.parse(opts.body),{password:'new-long-password-123'});return{status:200,data:token.user};}
  if(url.endsWith('/auth/v1/logout?scope=others'))return {status:204,data:null};
  throw Error('Unexpected security request');
 });
 await app.auth.signIn({email:token.user.email,password:'strong-pass-123'});
 const security=await app.auth.securityState();assert.equal(security.emailConfirmed,true);assert.equal(security.factors[0].type,'totp');assert.equal(security.identities[0].provider,'google');
 await assert.rejects(app.auth.changePassword('short'),/12/);
 await assert.rejects(app.auth.verifyMFA(UUID,'123'),/غير صالح/);
 await app.auth.changePassword('new-long-password-123');await app.auth.revokeOtherSessions();assert.equal(app.auth.state().signedIn,true);
});
test('MFA verification exchanges challenge and stores the returned session, never the OTP',async()=>{
 const base={access_token:'access.AAL1',refresh_token:'refresh.AAL1',expires_in:3600,user:{id:UUID,email:'mfa@test.invalid'}};
 const app=init(async(url,opts)=>{
  if(url.includes('grant_type=password'))return{status:200,data:base};
  if(url.includes('/rest/v1/profiles'))return{status:200,data:[row]};
  if(url.endsWith('/challenge')){assert.deepEqual(JSON.parse(opts.body),{});return{status:200,data:{id:UUID}};}
  if(url.endsWith('/verify')){assert.deepEqual(JSON.parse(opts.body),{challenge_id:UUID,code:'654321'});return{status:200,data:{...base,access_token:'access.AAL2',refresh_token:'refresh.AAL2'}};}
  throw Error('Unexpected request');
 });
 await app.auth.signIn({email:base.user.email,password:'strong-pass-123'});await app.auth.verifyMFA(UUID,'654321');
 assert.match(app.map.get('totichat.phase2.session.v1'),/access.AAL2/);assert.doesNotMatch(app.map.get('totichat.phase2.session.v1'),/654321/);
});

test('private audio storage rejects foreign uploads and late responses after logout',async()=>{
 const token={access_token:'access.VOICE',refresh_token:'refresh.VOICE',expires_in:3600,user:{id:UUID,email:'voice@test.invalid'}};
 let resolveRead,readStarted;
 const started=new Promise(resolve=>readStarted=resolve);
 const app=init(async(url,opts)=>{
  if(url.includes('grant_type=password'))return{status:200,data:token};
  if(url.includes('/rest/v1/profiles'))return{status:200,data:[row]};
  if(url.includes('/auth/v1/logout'))return{status:204,data:null};
  if(url.includes('/storage/v1/object/authenticated/')){assert.equal(opts.headers.Authorization,'Bearer access.VOICE');readStarted();return new Promise(resolve=>resolveRead=resolve);}
  throw Error('Unexpected upload escaped validation');
 });
 await app.auth.signIn({email:token.user.email,password:'strong-pass-123'});
 const other='294b758b-2cdd-437f-bf20-8b31daea4b53',path=other+'/'+UUID+'/'+UUID+'.webm';
 await assert.rejects(app.auth.voiceStorage('upload',path,new Blob(['audio'],{type:'audio/webm'})));
 const pending=app.auth.voiceStorage('read',path);await started;await app.auth.signOut();resolveRead({status:200,data:new Blob(['private'],{type:'audio/webm'})});
 await assert.rejects(pending,/تغير الحساب/);
 assert.equal(app.requests.filter(x=>x.options.method==='POST'&&x.url.includes('/storage/')).length,0);
});
