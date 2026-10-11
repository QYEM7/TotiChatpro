/**
 * Construct the exact CANONICAL staging-era migration sequence in a disposable
 * UNLINKED local Supabase workspace. Historical files remain in GitHub and are
 * NEVER removed or edited. No external network, database or secrets required.
 */
import {readdirSync,copyFileSync,mkdirSync,existsSync} from 'node:fs';
import {resolve,dirname,sep,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const original=join(repo,'supabase','migrations');
// Superseded by 20261011000400 (support) and 20261011000401 (month).
// Those historical prototypes create duplicate tables/functions if replayed
// together with Staging's authoritative later implementation.
export const superseded=Object.freeze([
 '20261010160500_t36_host_month_preflight.sql',
 '20261010171000_t42_support_tickets.sql',
 '20261010183000_t42_support_roster_thread_paging.sql',
 '20261010191000_t06_support_concurrency_private_retry.sql'
]);
export function prepareStagingReplay(target,runnerTemp=process.env.RUNNER_TEMP){
 if(!runnerTemp)throw Error('RUNNER_TEMP must be explicitly provided');
 const root=resolve(runnerTemp);
 const dest=resolve(target||'');
 if(!target||dest===root||!dest.startsWith(root+sep)||dest.startsWith(repo+sep))
  throw Error('Only a subdirectory of disposable RUNNER_TEMP is allowed');
 const selected=readdirSync(original).filter(name=>name.endsWith('.sql')).sort();
 for(const filename of superseded){
  if(!selected.includes(filename))throw Error('Missing historical migration '+filename);
 }
 const active=selected.filter(name=>!superseded.includes(name));
 const authoritative=[
  '20261011000400_phase5_support_tickets.sql',
  '20261011000401_phase5_host_month_preflight.sql',
  '20261011141000_backend_actor_serialization_support_privacy.sql'
 ];
 if(active.length<35||authoritative.some(name=>!active.includes(name)))
  throw Error('Canonical staging backend migration set incomplete');
 const targetMigrations=join(dest,'supabase','migrations');
 mkdirSync(targetMigrations,{recursive:true});
 if(readdirSync(targetMigrations).some(name=>name.endsWith('.sql')))
  throw Error('Refuse to mix into an existing migration workspace');
 for(const filename of active){
  copyFileSync(join(original,filename),join(targetMigrations,filename));
 }
 return {active:active.length,retainedHistory:superseded.length,dest:targetMigrations};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const result=prepareStagingReplay(process.argv[2]);
  process.stdout.write('CANONICAL STAGING REPLAY: '+result.active+
   ' active migration files; '+result.retainedHistory+
   ' superseded historical files safely remain only in source control.\n');
 }catch(e){console.error(String(e.message||e));process.exitCode=1;}
}
