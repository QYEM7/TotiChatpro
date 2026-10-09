'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const sql=read('supabase/migrations/20261010133000_phase2_private_room_invitations.sql');
const hardening=read('supabase/migrations/20261010133500_phase2_private_room_rls_and_chat_race.sql');
const js=read('app/phase2-rooms.js');
test('private invitation rows are unreadable and no anonymous RPC calls are possible',()=>{
  assert.match(sql,/alter table public\.phase2_room_invites enable row level security/i);
  assert.match(sql,/revoke all on public\.phase2_room_invites from public, anon, authenticated/i);
  assert.match(sql,/revoke all on function[\s\S]*?phase2_room_invite_join\(uuid,text\)[\s\S]*?from public,anon/i);
  assert.match(sql,/p_room_id=p_room_id and r\.owner_id=caller and r\.is_private/i);
});
test('invitation codes are random and stored only as hashes, short lived and one-use',()=>{
  assert.match(sql,/extensions\.gen_random_bytes\(24\)/);
  assert.match(sql,/extensions\.digest\(secret,'sha256'\)/);
  assert.match(sql,/interval '30 minutes'/);
  assert.match(sql,/for update/);
  assert.match(sql,/inv\.redeemed_at is not null/);
  assert.match(sql,/set redeemed_at=now\(\),redeemed_by=caller/);
  assert.doesNotMatch(sql,/create policy[\s\S]*?on public\.phase2_room_invites for select/i);
});
test('private joined members can read their own room but anonymous users cannot',()=>{
  assert.match(hardening,/Authenticated users see public, owned or joined rooms/);
  assert.match(hardening,/exists\s*\([\s\S]*?from public\.room_members m[\s\S]*?m\.user_id=\(select auth\.uid\(\)\)/);
  assert.match(hardening,/pg_advisory_xact_lock/);
  assert.match(hardening,/created_at>now\(\)-interval '1 second'/);
});
test('real signed-in room chat bypasses guest demo composer on Enter',()=>{
  assert.match(js,/document\.addEventListener\('keydown'/);
  assert.match(js,/event\.stopImmediatePropagation\(\)/);
  assert.match(js,/void sendMessage\(\)/);
  assert.match(js,/let sequence=0,sending=false/);
  assert.match(js,/phase2_room_invite_create/);
  assert.match(js,/phase2_room_invite_join/);
});
