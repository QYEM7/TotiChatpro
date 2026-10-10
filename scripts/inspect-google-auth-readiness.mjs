/* Google-only beta PRE-FLIGHT — public provider flags, read-only, no secret output.
 * Does not enable Google OAuth, mutate any Supabase project, or validate mobile callbacks.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function readPublicBackend(configText){
 const u=configText.match(/supabaseUrl\s*:\s*["']([^"']+)["']/)?.[1];
 const k=configText.match(/publishableKey\s*:\s*["']([^"']+)["']/)?.[1];
 if(!u||!k||!k.startsWith('sb_publishable_'))throw Error('Only a public Supabase publishable key is allowed');
 const parsed=new URL(u);
 if(parsed.protocol!=='https:'||!parsed.hostname.endsWith('.supabase.co')||parsed.username||parsed.password||parsed.port)
  throw Error('Refused non-Supabase endpoint');
 return {url:parsed.origin,key:k};
}
export function summarizeFlags(data){
 const ext=data?.external||data?.external_providers;
 if(!ext||typeof ext!=='object')return {google:null,apple:null,facebook:null,readiness:'unverified'};
 const flags={google:ext.google===true,apple:ext.apple===true,facebook:ext.facebook===true};
 return {...flags,readiness:flags.google?'google_provider_enabled_callback_unverified':'blocked_google_provider_disabled'};
}
export async function inspect({configText,fetchImpl=fetch}){
 const {url,key}=readPublicBackend(configText);
 const res=await fetchImpl(url+'/auth/v1/settings',{
  method:'GET',headers:{apikey:key,accept:'application/json'},
  signal:AbortSignal.timeout(10000),redirect:'error',cache:'no-store'
 });
 if(!res.ok)throw Error('Supabase public Auth settings returned HTTP '+res.status);
 return summarizeFlags(await res.json());
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const status=await inspect({configText:fs.readFileSync(path.join(root,'app/config.js'),'utf8')});
  // Never include publishable keys, URLs with credentials, user records or secrets.
  process.stdout.write(JSON.stringify({source:'public Supabase Auth provider flags only',...status,
   android_callback_verified:false,google_cloud_consent_verified:false,
   note:'Provider enabled is NOT proof of working real Android OAuth. No Auth settings modified.'},null,2)+'\n');
  if(process.argv.includes('--strict')&&status.readiness!=='google_provider_enabled_callback_unverified')process.exitCode=1;
 }catch(error){
  process.stdout.write(JSON.stringify({readiness:'unverified',reason:String(error?.message||error),
   android_callback_verified:false,note:'Read-only check, no changes made'},null,2)+'\n');
  if(process.argv.includes('--strict'))process.exitCode=1;
 }
}
