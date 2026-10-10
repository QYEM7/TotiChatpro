'use strict';
const fs=require('node:fs'),test=require('node:test'),assert=require('node:assert/strict');
const script=fs.readFileSync('scripts/t49-disposable-restore-drill.sh','utf8');
const fullstack=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T49 only allowed in disposable Docker Supabase without production connection',()=>{
 for(const term of ['T49_DISPOSABLE_ONLY','SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','PGHOST','DATABASE_URL',"grep '^supabase_db_'","LOCAL_DBS[@]","trap cleanup EXIT"])assert(script.includes(term),term);
 assert(!script.includes('sqedsnyvjblvbjbizcay'));
 assert(!script.includes('supabase db dump --linked'));
 assert(!script.includes('supabase link'));
 assert(!script.includes('docker exec "$DB_CONTAINER" pg_dump -U postgres -d "$RESTORE_DB"'));
});
test('T49 restore drill tests local monetary conservation and month-end entitlements',()=>{
 for(const term of ['pg_dump','--format=custom','pg_restore','--single-transaction','createdb','template0','update t49_drill.wallets set coins=0','delete from t49_drill.month_entitlements','sum(coins)','<>1200','sum(owed_diamonds)','<>155','relrowsecurity','has_table_privilege'])assert(script.includes(term),term);
 assert(fullstack.includes('scripts/t49-disposable-restore-drill.sh'));
 assert(!fullstack.includes('actions/upload-artifact'));
});
test('T49 restore is not mislabelled as production recovery',()=>{
 assert(script.includes('production backup and Storage object recovery remain NOT verified'));
 assert(script.includes('never real user, wallet or payroll data'));
});
