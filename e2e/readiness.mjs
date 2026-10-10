import '../scripts/load-local-env.mjs';
import {stagingFromEnv,assertStagingRuntime} from '../scripts/t03-staging-config.mjs';
export default async function(){
 const cfg=stagingFromEnv(process.env);
 const required=['TEST_USER1_EMAIL','TEST_USER1_PASSWORD','TEST_USER2_EMAIL','TEST_USER2_PASSWORD','TEST_ROOM_ID'];
 const missing=required.filter(k=>!process.env[k]);
 if(missing.length)throw Error('BLOCKED real E2E: missing '+missing.join(', ')+'. Supply real staging users and room privately.');
 if(process.env.TEST_USER1_EMAIL===process.env.TEST_USER2_EMAIL)throw Error('Real E2E requires two separate confirmed accounts');
 for(const k of ['TEST_USER1_EMAIL','TEST_USER2_EMAIL'])if(/@.*\.(invalid|local|test)$/i.test(process.env[k]))throw Error('Real E2E requires deliverable email accounts');
 if(!/^[0-9a-f-]{36}$/i.test(process.env.TEST_ROOM_ID))throw Error('TEST_ROOM_ID must identify an existing STAGING room');
 const base=process.env.E2E_BASE_URL||'http://127.0.0.1:8765';
 let url;try{url=new URL(base);}catch{throw Error('BLOCKED real E2E: invalid E2E_BASE_URL');}
 if(!['http:','https:'].includes(url.protocol))throw Error('BLOCKED real E2E: server must be HTTP(S)');
 if(url.protocol!=='https:'&&!['127.0.0.1','localhost','[::1]','::1'].includes(url.hostname))throw Error('BLOCKED real E2E: remote server requires HTTPS');
 const asset=new URL('/app/config.js',url.origin);
 const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),12000);
 try{
  const response=await fetch(asset,{signal:controller.signal,redirect:'error'});
  if(!response.ok)throw Error('HTTP '+response.status);
  assertStagingRuntime(await response.text(),cfg);
 }catch(err){throw Error('BLOCKED real E2E: staged runtime not present at test host ('+err.message+')');}
 finally{clearTimeout(timeout);}
}
