/* Reborn TotiChat: pack clean app shell and preserve vetted Auth + LiveKit bridge. */
import {cp,mkdir,rm,readFile,writeFile,stat} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));
const output=join(root,'dist');
const source=join(root,'app','index.html');
const html=await readFile(source,'utf8');
const required=['reborn/core.js','reborn/features.js','reborn/styles.css','phase2-auth.js','config.js'];
if(!html.startsWith('<!doctype html>')||!html.includes('<html lang="ar" dir="rtl"><head>')||
  !required.every(x=>html.includes('./'+x)))throw Error('Reborn entry missing required modules');
for(const file of required){const target=await stat(join(root,'app',file)).catch(()=>null);if(!target?.isFile())throw Error('Missing '+file);}
const publicConfig=await readFile(join(root,'app','config.js'),'utf8');
if(!publicConfig.includes('rziaedugbdwefbefcxjt.supabase.co')||publicConfig.includes('service_role')||publicConfig.includes('sb_secret_'))throw Error('Only isolated public Staging config allowed');
await rm(output,{recursive:true,force:true});
await mkdir(join(output,'app'),{recursive:true});
await cp(join(root,'app','reborn'),join(output,'app','reborn'),{recursive:true});
for(const file of ['config.js','phase2-auth.js'])await cp(join(root,'app',file),join(output,'app',file));
await cp(join(root,'assets'),join(output,'assets'),{recursive:true});
const {build}=await import('esbuild');
await build({entryPoints:[join(root,'app','phase2-livekit-sdk.mjs')],
 outfile:join(output,'app','phase2-livekit-sdk.bundle.js'),
 bundle:true,format:'esm',platform:'browser',target:'es2022',
 minify:true,sourcemap:false,logLevel:'warning'});
await writeFile(join(output,'app','index.html'),html,'utf8');
await writeFile(join(output,'index.html'),html.replace('<html lang="ar" dir="rtl"><head>','<html lang="ar" dir="rtl"><head><base href="./app/">'),'utf8');
console.log('PASS: freshly rebuilt TotiChat app packaged at WebView root; isolated Staging, real Google + LiveKit.');
