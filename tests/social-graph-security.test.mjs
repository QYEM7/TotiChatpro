import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011194500_verified_social_graph.sql',import.meta.url),'utf8');
test('social graph is backend-only RLS, session verified, never fabricated',()=>{
 assert.match(sql,/alter table public\.social_follows enable row level security/);
 assert.match(sql,/revoke all on public\.social_follows from public,anon,authenticated/);
 assert.match(sql,/declare me uuid:=phase3\.actor\(\)/);
 assert.match(sql,/constraint tc_social_no_self check\(follower_id<>followed_id\)/);
 assert.match(sql,/from public\.dm_blocks b/);
 assert.match(sql,/after insert on public\.dm_blocks/);
 assert.doesNotMatch(sql,/\btruncate\b|sampleFollower|insert into public\.wallets|fakeUsers/i);
});
test('follow and discovery APIs use private authority with invoker wrappers',()=>{
 for(const name of ['follow','overview','list','search']){
 assert(sql.includes('create function phase3.social_'+name+'('));
 assert(sql.includes('create function public.phase5_social_'+name+'('));
 }
 assert.match(sql,/Follow idempotency conflict/);
 assert.match(sql,/Follow rate limit exceeded/);
 assert.match(sql,/from public\.social_follows reciprocal/);
 assert.match(sql,/to authenticated;/);
 assert.match(sql,/returns jsonb language plpgsql security invoker/);
});
