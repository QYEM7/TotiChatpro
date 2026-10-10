/* Approved TotiChat LIVE WEB preview public-key wrapper.
 * All data is from the distinct, empty, isolated Supabase staging project.
 * This browser publishable key is designed for client use, NOT a secret.
 * NEVER read, print, or use a database password or service_role key here.
 */
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildLivePreview} from './build-live-preview.mjs';
const base=new URL('../docs/preview-public-backend.json',import.meta.url);
const cfg=JSON.parse(readFileSync(base,'utf8'));
export const EXPECTED_STAGING_REF='rziaedugbdwefbefcxjt';
export function checkedStagingConfig(config){
 if(config.project!=='TotiChat Staging'||
  config.supabaseUrl!=='https://'+EXPECTED_STAGING_REF+'.supabase.co'||
  !/^sb_publishable_[A-Za-z0-9_-]{8,}$/.test(config.publishableKey))
  throw Error('BLOCKED preview: project mismatch or unsafe API credential');
 return {
  STAGING_SUPABASE_URL:config.supabaseUrl,
  STAGING_SUPABASE_PUBLISHABLE_KEY:config.publishableKey
 };
}
const env=checkedStagingConfig(cfg);
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const result=await buildLivePreview(env);
  console.log('PASS: TotiChat approved real web UI compiled for isolated staging '+result.projectRef+
   '; no APK, no production write or billable service.');
 }catch(e){console.error(String(e.message||e));process.exitCode=1;}
}
