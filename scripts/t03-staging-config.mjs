/* T03: isolate real acceptance tests from production. */
import {readFile,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
export const PRODUCTION_SUPABASE_URL='https://sqedsnyvjblvbjbizcay.supabase.co';
export function stagingFromEnv(env=process.env){
 const raw=String(env.STAGING_SUPABASE_URL||'').trim();
 const key=String(env.STAGING_SUPABASE_PUBLISHABLE_KEY||'').trim();
 if(!raw||!key)throw Error('BLOCKED staging: private STAGING_SUPABASE_URL and STAGING_SUPABASE_PUBLISHABLE_KEY required');
 let url;try{url=new URL(raw);}catch{throw Error('BLOCKED staging: invalid Supabase URL');}
 if(url.protocol!=='https:'||!/^([a-z0-9]{20})\.supabase\.co$/.test(url.hostname)||url.username||url.password||url.pathname!=='/'||url.search||url.hash||url.port)throw Error('BLOCKED staging: require dedicated HTTPS Supabase project root');
 if(url.origin===PRODUCTION_SUPABASE_URL)throw Error('BLOCKED staging: production Supabase forbidden for real E2E');
 if(!/^sb_publishable_[A-Za-z0-9_-]{8,}$/.test(key))throw Error('BLOCKED staging: only a publishable key is allowed, never a secret/service_role key');
 return Object.freeze({supabaseUrl:url.origin,publishableKey:key,projectRef:url.hostname.split('.')[0]});
}
export function publicRuntime(cfg){
 return '/* TotiChat staging-only public runtime config; do not deploy over production. */\n'+
 'window.TOTICHAT_PUBLIC_BACKEND=Object.freeze('+JSON.stringify({supabaseUrl:cfg.supabaseUrl,publishableKey:cfg.publishableKey})+');\n';
}
export function assertStagingRuntime(contents,cfg){
 if(contents!==publicRuntime(cfg))throw Error('BLOCKED staging: served config does not match isolated staging build');
 if(contents.includes(PRODUCTION_SUPABASE_URL)||/sb_secret_|service_role|BEGIN PRIVATE KEY/i.test(contents))throw Error('BLOCKED staging: production or private credentials detected');
}
export async function prepareStagingRuntime(env=process.env,outputDir=resolve('dist')){
 const cfg=stagingFromEnv(env),dest=resolve(outputDir);
 if(dest===resolve('.')||dest===resolve('app'))throw Error('BLOCKED staging: never overwrite source configuration');
 const file=join(dest,'app','config.js');
 await readFile(file,'utf8');
 const js=publicRuntime(cfg);assertStagingRuntime(js,cfg);
 await writeFile(file,js,'utf8');
 assertStagingRuntime(await readFile(file,'utf8'),cfg);
 return {projectRef:cfg.projectRef,asset:file};
}
