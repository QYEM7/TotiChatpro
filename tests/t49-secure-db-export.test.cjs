'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const {readFileSync}=require('node:fs');
const path=require('node:path');
const file=path.join(__dirname,'../scripts/t49-secure-db-export.sh');
const run=vars=>spawnSync('bash',[file],{cwd:path.resolve(__dirname,'..'),
  env:{PATH:process.env.PATH,...vars},encoding:'utf8',timeout:10000});
test('dangerous export refuses default, foreign project and wrong database',()=>{
 const no=run({});assert.notEqual(no.status,0);assert.match(no.stderr,/approval flag/);
 const wrong=run({T49_EXPORT_APPROVED:'YES',T49_PROJECT_REF:'bfadhdnudmsggylunhlh'});
 assert.notEqual(wrong.status,0);assert.match(wrong.stderr,/wrong project/);
 const host=run({T49_EXPORT_APPROVED:'YES',T49_PROJECT_REF:'sqedsnyvjblvbjbizcay',PGHOST:'evil.example'});
 assert.notEqual(host.status,0);assert.match(host.stderr,/wrong database host/);
});
test('script is syntactically valid, encrypts before disk and cannot mark restore as complete',()=>{
 const content=readFileSync(file,'utf8');
 const check=spawnSync('bash',['-n',file],{encoding:'utf8',timeout:10000});
 assert.equal(check.status,0,check.stderr);
 assert.match(content,/pg_dump[\s\S]*\|\s*\n age -r/);
 assert.match(content,/PGSSLMODE.*verify-full/);
 assert.match(content,/Storage object bytes NOT backed up/);
 assert.doesNotMatch(content,/(curl|gh release|git push|supabase db push|pg_restore|service_role|sb_secret_)/);
});
