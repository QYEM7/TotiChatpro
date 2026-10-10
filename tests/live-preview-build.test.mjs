import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Script} from 'node:vm';
import {injectPreviewEntry,restrictDemoChoice,buildLivePreview,PREVIEW_FLAG} from '../scripts/build-live-preview.mjs';
import {publicRuntime,stagingFromEnv,PRODUCTION_SUPABASE_URL} from '../scripts/t03-staging-config.mjs';
const env={
 STAGING_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
 STAGING_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_FAKE_PUBLIC_FOR_OFFLINE_TEST'
};
test('generated staging backend is valid browser JavaScript',()=>{
 const config=publicRuntime(stagingFromEnv(env));
 assert.doesNotThrow(()=>new Script(config));
 assert(config.includes('\nwindow.TOTICHAT_PUBLIC_BACKEND'));
 assert(!config.includes(PRODUCTION_SUPABASE_URL));
});
test('browser entry selects live mode without clearing OAuth code',()=>{
 const original='<html><head><base href="./app/"><title>Original</title></head>'+
 '<body><script src="toti-nav-banner-refine.js"></script>'+
 '<link href="room-seats-finish.css"></body></html>';
 const output=injectPreviewEntry(original);
 assert(output.includes(PREVIEW_FLAG));
 assert(output.includes('searchParams.set("mode","live")'));
 assert(output.includes('history.replaceState(history.state'));
 assert(!output.includes('searchParams.delete("code")'));
 assert.throws(()=>injectPreviewEntry(output));
});
test('staging build copy denies optional sample mode',()=>{
 const js="if(screen==='loginPreview'){ } if(action.dataset.liveEntry==='preview'){explicitPreview=true;}";
 const out=restrictDemoChoice(js);
 assert(out.includes("&& !window.TotiLivePreviewOnly"));
 assert(out.includes("if(window.TotiLivePreviewOnly)"));
 assert.throws(()=>restrictDemoChoice('unknown'));
});
test('missing or production staging refuses any preview output',async()=>{
 const t=await mkdtemp(join(tmpdir(),'toti-live-preview-'));
 try{
  const src=join(t,'dist'),out=join(t,'preview');
  await mkdir(src);
  await assert.rejects(()=>buildLivePreview({}, {source:src,output:out}),/BLOCKED staging/);
  await assert.rejects(()=>buildLivePreview({
    ...env,STAGING_SUPABASE_URL:PRODUCTION_SUPABASE_URL
  },{source:src,output:out}),/BLOCKED staging/);
  await assert.rejects(()=>readFile(join(out,'index.html'),'utf8'));
 }finally{await rm(t,{recursive:true,force:true});}
});
