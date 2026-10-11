import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,readdirSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {prepareStagingReplay,superseded} from '../scripts/prepare-staging-schema-replay.mjs';

test('disposable schema replay retains historic migrations in source, not active staging copy',()=>{
 const parent=mkdtempSync(join(tmpdir(),'totichat-replay-'));
 try{
  const dest=join(parent,'unlinked');
  const result=prepareStagingReplay(dest,parent);
  const active=readdirSync(result.dest);
  const sourceDir=new URL('../supabase/migrations/',import.meta.url);
  for(const file of superseded){
    assert(!active.includes(file),file+' is superseded in canonical stage');
    assert(existsSync(new URL(file,sourceDir)),'the historical source file must not be removed');
  }
  for(const file of [
   '20261011000400_phase5_support_tickets.sql',
   '20261011000401_phase5_host_month_preflight.sql',
   '20261011141000_backend_actor_serialization_support_privacy.sql'
  ])assert(active.includes(file),file+' must be in canonical replay');
  assert(result.active>=35);
  assert.throws(()=>prepareStagingReplay(dest,parent),/existing migration workspace/);
  assert.throws(()=>prepareStagingReplay(sourceDir.pathname,parent),/Only a subdirectory/);
 }finally{rmSync(parent,{recursive:true,force:true})}
});

test('CI production isolation and canonical migration preparation are explicit',()=>{
 for(const path of ['t03-full-stack.yml','t03-local-schema-replay.yml']){
  const wf=readFileSync(new URL('../.github/workflows/'+path,import.meta.url),'utf8');
  assert.match(wf,/scripts\/prepare-staging-schema-replay\.mjs/);
  assert.doesNotMatch(wf,/^\\s*(?:supabase\\s+link|supabase\\s+db\\s+push)\\b/m);
 }
});
