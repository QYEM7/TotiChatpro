import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011213000_verified_personal_gift_history.sql',import.meta.url),'utf8');
test('gift receipts count only real committed gift and diamonds; no salary claims',()=>{
 assert.match(sql,/from public\.gift_events e/);
 assert.match(sql,/public\.diamond_lots l/);
 assert.match(sql,/l\.gift_event_id=e\.id/);
 assert.match(sql,/where l\.user_id=me and e\.recipient_id=me/);
 assert.match(sql,/isSalaryReport',false/);
 assert.match(sql,/isBalance',false/);
 assert.doesNotMatch(sql,/(?:update|delete from|insert into)\s+public\.(?:wallets?|wallet_ledger|diamond_lots|gift_events)/i);
});
test('gift history is private, paged and uses verified active account, never caller-specified user ID',()=>{
 assert.match(sql,/declare me uuid:=phase3\.actor\(\)/);
 assert.match(sql,/p_direction not in\('received','sent','all'\)/);
 assert.match(sql,/p_limit not between 1 and 50/);
 assert.match(sql,/e\.sender_id=me/);
 assert.match(sql,/e\.recipient_id=me/);
 assert.match(sql,/\(e\.created_at,e\.id\)<\(p_before_at,p_before_id\)/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/revoke all on function public\.phase5_gift_summary\(\)/);
 assert.doesNotMatch(sql,/p_target uuid|p_user_id uuid/);
});
