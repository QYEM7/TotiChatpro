import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=readFileSync(new URL('../supabase/migrations/20261011210000_authoritative_room_tictactoe.sql',import.meta.url),'utf8');
test('voice-safe game server persists authoritative no-stakes turn state',()=>{
 assert.match(db,/create table public\.room_game_matches/);
 assert.match(db,/board text not null default '\.\.\.\.\.\.\.\.\.'/);
 assert.match(db,/where status in \('waiting','active'\)/);
 assert.match(db,/pg_advisory_xact_lock/);
 assert.match(db,/Game idempotency request conflict/);
 assert.match(db,/substring\(current_game\.board from p_cell\+1 for 1\)/);
 assert.match(db,/when has_won then 'won'/);
 assert.match(db,/tc_game_cancel_on_member_departure/);
 assert.doesNotMatch(db,/\b(wallet|ledger|coin|diamond|livekit|mute|set_microphone)\b/i);
});
test('game client has session and membership checks, private RLS and no anon writes',()=>{
 assert.match(db,/phase3\.actor\(\)/);
 assert.match(db,/not exists\(select 1 from public\.room_members/);
 assert.match(db,/alter table public\.room_game_matches enable row level security/);
 assert.match(db,/revoke all on public\.room_game_matches from public,anon,authenticated/);
 assert.match(db,/public\.phase5_room_game_state/);
 assert.match(db,/public\.phase5_room_game_action/);
 assert.match(db,/security invoker/);
 assert.match(db,/on public\.room_game_matches\(room_id\)/);
});
