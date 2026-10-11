import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011183000_verified_voice_session_preflight.sql',import.meta.url),'utf8');
test('voice preflight is an invoker that checks a live verified Auth session',()=>{
 assert.match(sql,/alter function public\.phase2_voice_token_preflight\(uuid\) set schema phase3/);
 assert.match(sql,/create function public\.phase2_voice_token_preflight/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/perform phase3\.actor\(\)/);
 assert.match(sql,/return phase3\.phase2_voice_token_preflight\(p_room_id\)/);
 assert.match(sql,/revoke all on function public\.phase2_voice_token_preflight\(uuid\) from public,anon/);
 assert.doesNotMatch(sql,/\btruncate\b|drop table|update public\.wallets/i);
});
