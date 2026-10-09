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
const entry=`<!doctype html>
<html lang="ar" dir="rtl"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0; url=./app/">
<title>TotiChat</title>
</head><body>
<p><a href="./app/">TotiChat</a></p>
<script>window.location.replace('./app/');</script>
</body></html>
`;
await writeFile(path.join(destination,'index.html'),entry,'utf8');
console.log('PASS: unmodified approved UI and assets packaged under dist/app and dist/assets');
