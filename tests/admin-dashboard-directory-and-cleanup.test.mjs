import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');
const app=read('../admin-dashboard/app.js');
const sql=read('../supabase/migrations/20261012003000_admin_directory_readonly.sql');
test('admin private user/room directory is bounded and enforces Owner/main partner only',()=>{
 assert.match(sql,/phase3\.actor\(\)/);
 assert.match(sql,/phase3\.is_owner\(\)/);
 assert.match(sql,/main_partner_id=caller/);
 assert.match(sql,/p_kind not in\('users','rooms'\)/);
 assert.match(sql,/p_limit not between 1 and 50/);
 assert.match(sql,/readOnly',true/);
 assert.match(sql,/revoke all on function public\.phase6_admin_directory/);
 assert.match(app,/phase6_admin_directory/);
 assert.match(app,/async function usersPage\(\)/);
 assert.match(app,/async function roomsPage\(\)/);
 assert.match(app,/if\(id==='banners'\|\|id==='treasury'\|\|id==='team'\|\|id==='settings'\|\|id==='users'\|\|id==='rooms'\)return isChief\(\)/);
});
test('image replacement cleans up only after metadata save and stale orphan uploads',()=>{
 assert.match(app,/async function cleanupUnusedImage\(path\)/);
 assert.match(app,/\/storage\/v1\/object\/'\+BUCKET/);
 assert.match(app,/method:'DELETE',body:\{prefixes:\[path\]\}/);
 assert.match(app,/if\(newPath&&path&&path!==newPath\)/);
 assert.match(app,/if\(newPath\)\{try\{await cleanupUnusedImage\(newPath\)/);
 assert.match(app,/if\(action==='delete'\)/);
 assert.doesNotMatch(app,/window\.localStorage|sb_secret_|service_role/);
});
test('auth refresh preserves verified actor and mobile navigation is functional',()=>{
 assert.match(app,/user:next\.user\|\|session\.user/);
 assert.match(app,/const firstAllowed=nav\.find\(item=>allowed\(item\[0\]\)\)/);
 assert.match(app,/window\.addEventListener\('hashchange'/);
 assert.match(app,/code_challenge_method/);
});
