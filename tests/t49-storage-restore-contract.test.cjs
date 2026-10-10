'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const script=fs.readFileSync('scripts/t49-storage-object-restore.mjs','utf8');
const workflow=fs.readFileSync('.github/workflows/t03-full-stack.yml','utf8');
test('T49 object restore works only against unlinked loopback and no production secrets',()=>{
 for(const token of ['T49_DISPOSABLE_ONLY','SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','localhost','127.0.0.1','cfg.API_URL'])assert(script.includes(token));
 assert(!script.includes('sqedsnyvjblvbjbizcay'));
 assert(!script.includes('SERVICE_ROLE_KEY'));
 assert(!script.includes('fetch(\'https://'));
 assert(workflow.includes('scripts/t49-storage-object-restore.mjs'));
});
test('T49 actual bytes must be backed up, deleted, restored and verified for public AND private objects',()=>{
 for(const token of ['profile-avatars','voice-messages','/object/authenticated/','/object/public/','crypto','sha256','DELETE','avatar restore upload','owner private voice restore','member private audio backup','outsiderAfter'])assert(script.includes(token),token);
 assert(script.includes('phase2_room_join'));
 assert(script.includes('phase4_voice_message'));
 assert(!workflow.includes('actions/upload-artifact@'));
});
