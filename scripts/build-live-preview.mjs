/* Build approved browser app against an ISOLATED Supabase project only.
 * The Google OAuth callback query must survive the default live-mode switch.
 * No APK, billing, real production data, or sample-room entry.
 */
import {cp,rm,mkdir,readFile,writeFile,readdir,stat} from 'node:fs/promises';
import {resolve,join,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {stagingFromEnv,prepareStagingRuntime,PRODUCTION_SUPABASE_URL} from './t03-staging-config.mjs';

export const PREVIEW_DIR='dist-live-preview';
export const PREVIEW_FLAG='window.TotiLivePreviewOnly=true';
export function injectPreviewEntry(html){
 const anchor='<base href="./app/">';
 if(!html.includes(anchor)||!html.includes('toti-nav-banner-refine.js')||
   !html.includes('room-seats-finish.css'))
   throw Error('BLOCKED preview: original TotiChat app shell missing');
 const boot='<script>'+PREVIEW_FLAG+';'+
   '(function(){const u=new URL(location.href);u.searchParams.set("mode","live");'+
   'history.replaceState(history.state,"",u.href)})();</script>';
 // Opt-in mobile diagnostic for invite-only UAT. Records only clicked
 // navigation attributes and current UI state, never account IDs or tokens.
 // Runs before legacy app scripts and is absent unless ?qa=discover.
 const qaProbe=`<script>(function(){
 if(new URLSearchParams(location.search).get('qa')!=='discover')return;
 var marker='DISCOVER-QA-05',box;
 function badge(){
   if(box||!document.body)return;
   box=document.createElement('output');
   box.id='toti-search-qa-status';
   box.setAttribute('role','status');
   box.style.cssText='position:fixed;z-index:2147483647;top:6px;left:6px;right:6px;'+
    'background:#24132eea;color:#fff8df;border:1px solid #dcbf89;border-radius:10px;'+
    'padding:5px 9px;font:11px/1.45 system-ui,sans-serif;direction:rtl;text-align:center;pointer-events:none;';
   box.textContent=marker+' · اضغط اكتشف أو بحث';document.body.appendChild(box);
 }
 document.addEventListener('DOMContentLoaded',badge);
 window.addEventListener('click',function(e){
   var t=e.target&&e.target.closest&&e.target.closest('button');
   if(!t)return;
   var label=(t.textContent||'').trim().slice(0,35);
   var royal=t.getAttribute('data-royal')||'-';
   var route=t.getAttribute('data-v')||'-';
   var phase=t.getAttribute('data-phase2')||'-';
   window.setTimeout(function(){
     badge();
     if(!box)return;
     var open=!!document.getElementById('tc-real-room-search-query');
     var live=window.TotiLiveMode&&window.TotiLiveMode.enabled===true;
     var ready=typeof (window.TotiPhase2Rooms&&window.TotiPhase2Rooms.openSearch);
     box.textContent=marker+' | '+label+' | v:'+route+' r:'+royal+' p:'+phase+
        ' | Live:'+!!live+' | API:'+ready+' | بحث:'+!!open;
   },220);
 },true);
 })();</script>`;
 if(html.includes(PREVIEW_FLAG))throw Error('BLOCKED preview: duplicate entry');
 return html.replace(anchor,anchor+boot+qaProbe)
   .replace(/<title>[^<]*<\/title>/,'<title>TotiChat | Live Preview</title>');
}
export function restrictDemoChoice(js){
 const anchor="if(screen==='loginPreview'){";
 const click="if(action.dataset.liveEntry==='preview'){";
 if(!js.includes(click))
  throw Error('BLOCKED preview: cannot restrict synthetic mode safely');
 // Recent live mode does not create a demo-choice banner at all. Support both
 // historical approved layouts and the new clean-auth variant without adding it.
 const restricted=js.includes(anchor)?js.replace(anchor,"if(screen==='loginPreview'&&!window.TotiLivePreviewOnly){"):js;
 return restricted.replace(click,"if(action.dataset.liveEntry==='preview'){"+
   "if(window.TotiLivePreviewOnly){warn('المعاينة الحقيقية لا تسمح بالحسابات الوهمية.');return;}");
}
export async function buildLivePreview(env=process.env,{
 source=resolve('dist'),output=resolve(PREVIEW_DIR)
}={}){
 const cfg=stagingFromEnv(env); // Reject production BEFORE touching output.
 if(source===output||output===resolve('app')||output===resolve('.'))
  throw Error('BLOCKED preview: output must be independent');
 const html=await readFile(join(source,'index.html'),'utf8');
 const liveScript=await readFile(join(source,'app','phase2-live-mode.js'),'utf8');
 const entry=injectPreviewEntry(html);
 const restricted=restrictDemoChoice(liveScript);
 await rm(output,{recursive:true,force:true});
 await mkdir(output,{recursive:true});
 await cp(source,output,{recursive:true});
 await writeFile(join(output,'index.html'),entry,'utf8');
 await writeFile(join(output,'app','phase2-live-mode.js'),restricted,'utf8');
 await prepareStagingRuntime(env,output);
 const config=await readFile(join(output,'app','config.js'),'utf8');
 if(config.includes(PRODUCTION_SUPABASE_URL)||!config.includes(cfg.supabaseUrl)||
   !config.includes(cfg.publishableKey))
   throw Error('BLOCKED preview: backend mismatch');
 await writeFile(join(output,'_headers'),
  '/*\n  X-Content-Type-Options: nosniff\n  X-Frame-Options: DENY\n'+
  '  Referrer-Policy: no-referrer\n'+
  '  Permissions-Policy: camera=(), microphone=(self), geolocation=(), payment=()\n'+
  '  X-Robots-Tag: noindex, nofollow\n'+
  '/index.html\n  Cache-Control: no-store\n'+
  '/app/config.js\n  Cache-Control: no-store\n');
 await writeFile(join(output,'robots.txt'),'User-agent: *\nDisallow: /\n');
 await writeFile(join(output,'preview-status.json'),JSON.stringify({
   app:'TotiChat',mode:'LIVE_STAGING_ONLY',backend_isolated:true,
   backend_ref:cfg.projectRef,data_source:'REAL_STAGING_SUPABASE',
   design:'APPROVED_UNCHANGED',apk_built:false,release_allowed:false,
   acceptance:{google_two_accounts:'UNVERIFIED',
    audio_two_physical_phones:'UNVERIFIED',finance:'UNVERIFIED'}
 },null,2)+'\n');
 async function scan(dir){
  for(const item of await readdir(dir,{withFileTypes:true})){
   const p=join(dir,item.name);
   if(item.isDirectory()){await scan(p);continue;}
   if(!/\.(js|mjs|html|json|css|txt)$/.test(item.name))continue;
   const data=await readFile(p,'utf8');
   if(data.includes(PRODUCTION_SUPABASE_URL)||data.includes('sb_secret_')||
      data.includes('service_role')||data.includes('BEGIN PRIVATE KEY'))
    throw Error('BLOCKED preview: production/private marker in '+relative(output,p));
  }
 }
 await scan(output);
 if(!(await stat(join(output,'assets','images'))).isDirectory())
  throw Error('BLOCKED preview: approved assets missing');
 return {output,projectRef:cfg.projectRef};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const done=await buildLivePreview();console.log(
  'PASS: isolated live web preview compiled; backend='+done.projectRef+
  ' design preserved; no APK, no mock login, no production');
 }catch(e){console.error(String(e.message||e));process.exitCode=1;}
}
