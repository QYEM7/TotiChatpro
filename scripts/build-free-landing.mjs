/* Build ONLY the static Cloudflare Pages landing. NEVER calls Gradle, never creates APK. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dest=path.join(root,'dist-free-site');
const readiness=JSON.parse(fs.readFileSync(path.join(root,'docs/release-readiness.json'),'utf8'));
const scope=JSON.parse(fs.readFileSync(path.join(root,'docs/beta30-scope.json'),'utf8'));
if(readiness.project!=='TotiChatpro'||scope.project!=='TotiChatpro')throw Error('Unexpected project');
if(!readiness.release_allowed&&/href\s*=\s*["'][^"']+\.apk(?:["'?]|$)/i.test(fs.readFileSync(path.join(root,'site/index.html'),'utf8')))
 throw Error('REFUSED: no APK download link before Owner-approved build release gate');
if(!fs.existsSync(path.join(root,'assets/images/toti_falcon_logo_1790422919580.jpg')))
 throw Error('Official TotiChat branding asset is missing. Refuse placeholder logo.');
fs.rmSync(dest,{recursive:true,force:true});
fs.mkdirSync(path.join(dest,'brand'),{recursive:true});
for(const name of ['index.html','privacy.html','_headers'])
 fs.copyFileSync(path.join(root,'site',name),path.join(dest,name));
fs.copyFileSync(path.join(root,'assets/images/toti_falcon_logo_1790422919580.jpg'),path.join(dest,'brand/falcon.jpg'));
for(const file of ['index.html','privacy.html','_headers','brand/falcon.jpg'])
 if(!fs.statSync(path.join(dest,file)).size)throw Error('Empty landing asset: '+file);
console.log('PASS: built zero-budget static site to dist-free-site/ (NO APK, NO paid deployment, NO fake download)');
