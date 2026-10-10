/* Repackage the exact approved /app/ preview for offline Android WebView.
 * This script must NEVER rebuild or transform the approved UI master.
 * Source paths remain app/ and ../assets/ so artwork/styles stay intact.
 */
import {cp, mkdir, rm, writeFile, readFile, stat} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const destination=path.join(root,'dist');
const approved=path.join(root,'app','index.html');
const html=await readFile(approved,'utf8');
if(!html.includes('toti-nav-banner-refine.js') ||
   !html.includes('room-seats-finish.css') ||
   !html.includes('profile-stats-luxe.css')){
  throw new Error('Approved TotiChat /app/ source missing its accepted design layers');
}
if(!(await stat(path.join(root,'assets','images')).catch(()=>null))){
  throw new Error('Approved image assets are missing');
}
await rm(destination,{recursive:true,force:true});
await mkdir(destination,{recursive:true});
await cp(path.join(root,'app'),path.join(destination,'app'),{recursive:true});
await cp(path.join(root,'assets'),path.join(destination,'assets'),{recursive:true});

const {build:bundle}=await import('esbuild');
await bundle({
 entryPoints:[path.join(root,'app','phase2-livekit-sdk.mjs')],
 outfile:path.join(destination,'app','phase2-livekit-sdk.bundle.js'),
 bundle:true,format:'esm',platform:'browser',target:'es2022',
 sourcemap:false,minify:true,logLevel:'warning'
});

// CRITICAL ANDROID WEBVIEW FIX (2026-10-10):
// Android's embedded Capacitor server opens dist/index.html at https://localhost/.
// A redirect to './app/' can fail to resolve a folder-style URL on-device,
// leaving users on a WHITE PAGE showing only the fallback "TotiChat" link.
// Render the already-approved UI DIRECTLY at the root instead, while a base
// element preserves its CSS/script/../assets/image URLs (originally /app/).
// Keep app/index.html byte-for-byte identical for existing Pages/QA previews.
const head='<html lang="ar" dir="rtl"><head>';
if(html.split(head).length!==2)throw new Error('Unexpected source <head>: refusing unsafe Android packaging');
if(/<base\b/i.test(html))throw new Error('Approved app already specifies a base tag; review packager');
const entry=html.replace(head,head+'<base href="./app/">');
await writeFile(path.join(destination,'index.html'),entry,'utf8');
console.log('PASS: Android root directly hosts approved TotiChat UI, /app/ relative paths and ../assets preserved');
