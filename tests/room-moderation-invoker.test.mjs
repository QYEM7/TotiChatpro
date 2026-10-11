import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011164500_room_moderation_invoker.sql',import.meta.url),'utf8');
test('moderation privileged owner roster lives outside exposed API; public wrapper verifies session',()=>{
 assert.match(sql,/alter function public\.phase2_room_moderation_state\(uuid\) set schema phase3/);
 assert.match(sql,/create function public\.phase2_room_moderation_state/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/perform phase3\.actor\(\)/);
 assert.match(sql,/return phase3\.phase2_room_moderation_state\(p_room_id\)/);
 assert.match(sql,/revoke all on function public\.phase2_room_moderation_state/);
 assert.doesNotMatch(sql,/drop table|truncate|delete from/i);
});
