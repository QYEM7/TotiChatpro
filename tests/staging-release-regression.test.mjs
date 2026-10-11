import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');

test('approved development app never connects directly to old production Supabase',()=>{
 const cfg=source('app/config.js');
 const expected=JSON.parse(source('docs/preview-public-backend.json'));
 assert.match(cfg,/window\.TOTICHAT_PUBLIC_BACKEND/);
 assert(cfg.includes(expected.supabaseUrl),'Staging URL must match approved public config');
 assert(cfg.includes(expected.publishableKey),'Staging public key must match approved public config');
 assert(!cfg.includes('sqedsnyvjblvbjbizcay.supabase.co'),'Never send beta users to old production backend');
 assert(!/sb_secret_|BEGIN PRIVATE KEY/.test(cfg),'No server secrets in browser');
});
test('room members use protected real profile images, never sample-seat avatars',()=>{
 const room=source('app/phase2-rooms.js');
 const sql=source('supabase/migrations/20261011000402_room_real_seat_avatars.sql');
 assert.match(room,/rpc\('phase2_room_members_visual'/);
 assert.match(room,/members\|members_visual/);
 assert.match(room,/image\.style\.setProperty\('display','none','important'\)/);
 assert.match(room,/new URL\(p\.avatar_url\)/);
 assert.match(room,/glyph\.hidden=!!realAvatar/);
 assert.doesNotMatch(room,/face\.replaceChildren\(\)/);
 assert.match(sql,/room_id=p_room_id and m\.user_id=auth\.uid\(\)/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/phase3\.actor\(\)/);
});
test('Cloudflare preview uses same account variable for guard and deploy',()=>{
 const workflow=source('.github/workflows/live-preview-staging.yml');
 const match=workflow.match(/CLOUDFLARE_ACCOUNT_ID:\s*\$\{\{ vars\.CLOUDFLARE_ACCOUNT_ID \}\}/g)||[];
 assert(match.length>=2,'Guard and deployment must both use authorized Cloudflare variable');
 assert.doesNotMatch(workflow,/CLOUDFLARE_ACCOUNT_ID:\s*\$\{\{ secrets\.CLOUDFLARE_ACCOUNT_ID \}\}/);
 assert.match(workflow,/needs: source-check/);
 assert.match(workflow,/npm ci --no-audit --no-fund/);
});
