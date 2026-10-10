import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {stagingFromEnv,publicRuntime,assertStagingRuntime,prepareStagingRuntime,PRODUCTION_SUPABASE_URL} from '../scripts/t03-staging-config.mjs';
const valid={STAGING_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',STAGING_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_TESTING_PUBLIC_ONLY'};
test('T03: staging runtime is browser safe and not production',()=>{
 const cfg=stagingFromEnv(valid);
 assert.equal(cfg.projectRef,'abcdefghijklmnopqrst');
 assert.notEqual(cfg.supabaseUrl,PRODUCTION_SUPABASE_URL);
 const js=publicRuntime(cfg);assertStagingRuntime(js,cfg);
 assert(!js.includes(PRODUCTION_SUPABASE_URL));
});
test('T03: production, malformed endpoints and private keys are blocked',()=>{
 for(const bad of [
 {...valid,STAGING_SUPABASE_URL:PRODUCTION_SUPABASE_URL},
 {...valid,STAGING_SUPABASE_URL:'http://abcdefghijklmnopqrst.supabase.co'},
 {...valid,STAGING_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co/path'},
 {...valid,STAGING_SUPABASE_URL:'https://evil.example.com'},
 {...valid,STAGING_SUPABASE_PUBLISHABLE_KEY:'sb_'+'secret_'+'FAKE_PRIVATE_KEY'},
 {...valid,STAGING_SUPABASE_PUBLISHABLE_KEY:'service_role_FAKE'},
 {...valid,STAGING_SUPABASE_PUBLISHABLE_KEY:''}
 ])assert.throws(()=>stagingFromEnv(bad),/BLOCKED staging/);
});
test('T03: output only rewritten in isolated build, not source',async()=>{
 const tmp=await mkdtemp(join(tmpdir(),'t03-'));
 try{
  await mkdir(join(tmp,'dist','app'),{recursive:true});
  await mkdir(join(tmp,'app'),{recursive:true});
  const source=join(tmp,'app','config.js'),output=join(tmp,'dist','app','config.js');
  await writeFile(source,'source config\n');await writeFile(output,'built config\n');
  const result=await prepareStagingRuntime(valid,join(tmp,'dist'));
  assert.equal(result.projectRef,'abcdefghijklmnopqrst');
  assert.equal(await readFile(source,'utf8'),'source config\n');
  assertStagingRuntime(await readFile(output,'utf8'),stagingFromEnv(valid));
  await assert.rejects(()=>prepareStagingRuntime(valid,resolve('app')),/BLOCKED staging/);
 }finally{await rm(tmp,{recursive:true,force:true});}
});
test('T03: all dotenv variants ignored, E2E verifies served stage config',async()=>{
 const ig=await readFile(new URL('../.gitignore',import.meta.url),'utf8');
 assert(ig.includes('.env*')&&ig.includes('!.env.example'));
 const src=await readFile(new URL('../app/config.js',import.meta.url),'utf8');
 assert(!/sb_secret_|BEGIN PRIVATE KEY/i.test(src));
 const readiness=await readFile(new URL('../e2e/readiness.mjs',import.meta.url),'utf8');
 assert(readiness.includes('assertStagingRuntime')&&readiness.includes('stagingFromEnv'));
});
