/* No-login Google OAuth initiation probe. Does NOT create a user or follow Google. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';

export const NATIVE_CALLBACK='com.totichat.beta://auth/callback';
export function publicConfig(source){
 const rawUrl=source.match(/supabaseUrl\s*:\s*["']([^"']+)["']/)?.[1];
 const key=source.match(/publishableKey\s*:\s*["']([^"']+)["']/)?.[1];
 if(!key?.startsWith('sb_publishable_'))throw Error('Only publishable public key supported');
 let parsed;try{parsed=new URL(rawUrl)}catch{throw Error('Invalid Supabase endpoint')}
 if(parsed.protocol!=='https:'||!/^[a-z0-9-]+\.supabase\.co$/.test(parsed.hostname)||
  parsed.username||parsed.password||parsed.port||parsed.pathname!=='/'||parsed.search||parsed.hash)
  throw Error('Unsafe Supabase endpoint');
 return {origin:parsed.origin,key};
}
export function isSafeGoogleRedirect(location,origin){
 let url;try{url=new URL(location)}catch{return false}
 return url.protocol==='https:'&&url.hostname==='accounts.google.com'&&!url.port&&
  /^\/o\/oauth2(?:\/v2)?\/auth\/?$/.test(url.pathname)&&
  url.searchParams.get('redirect_uri')===origin+'/auth/v1/callback';
}
export async function probe({configText,fetchImpl=fetch}){
 const {origin,key}=publicConfig(configText);
 const get=(url)=>fetchImpl(url,{
  method:'GET',headers:{apikey:key,accept:'application/json'},redirect:'manual',
  cache:'no-store',signal:AbortSignal.timeout(10000)
 });
 const base={source:'public OAuth GET preflight only',google_enabled:false,
  oauth_initiation_verified:false,native_callback_verified:false,
  real_login_verified:false,android_hardware_verified:false};
 const settings=await get(origin+'/auth/v1/settings');
 if(!settings.ok)throw Error('Provider settings HTTP '+settings.status);
 const data=await settings.json();
 if((data?.external||data?.external_providers||{}).google!==true)
  return {...base,status:'BLOCKED_PROVIDER_DISABLED'};
 const url=new URL(origin+'/auth/v1/authorize');
 url.searchParams.set('provider','google');
 url.searchParams.set('redirect_to',NATIVE_CALLBACK);
 url.searchParams.set('code_challenge',createHash('sha256').update(randomBytes(48)).digest('base64url'));
 url.searchParams.set('code_challenge_method','s256');
 const response=await get(url.href);
 const redirected=response.status>=300&&response.status<400&&
  isSafeGoogleRedirect(response.headers.get('location'),origin);
 return {...base,google_enabled:true,oauth_initiation_verified:Boolean(redirected),
  status:redirected?'GOOGLE_REDIRECT_OK_CALLBACK_UNTESTED':'BLOCKED_AUTHORIZE_HTTP_'+response.status};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const config=fs.readFileSync(path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../app/config.js'),'utf8');
  const result=await probe({configText:config});
  process.stdout.write(JSON.stringify(result,null,2)+'\n');
  if(process.argv.includes('--strict')&&!result.oauth_initiation_verified)process.exitCode=1;
 }catch(error){
  const reason=String(error.message||'unknown').replace(/https?:\/\/\S+/g,'[URL]').slice(0,120);
  console.log(JSON.stringify({status:'UNVERIFIED',reason,real_login_verified:false,native_callback_verified:false}));
  if(process.argv.includes('--strict'))process.exitCode=1;
 }
}
