import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011163000_room_owner_moderation.sql',import.meta.url),'utf8');
test('moderation: sensitive tables RLS private, all user mutations via verified actor and owner roles',()=>{
 for(const name of ['room_moderators','room_bans','room_moderation_requests'])
  assert.match(sql,new RegExp('alter table (?:public|phase3)\\.'+name+' enable row level security'));
 assert.match(sql,/caller uuid:=phase3\.actor\(\)/);
 assert.match(sql,/owner_action:=owner=caller/);
 assert.match(sql,/p_action in\s*\([\s\S]*'ban','unban'/);
 assert.match(sql,/not owner_action and \(target_mod or/);
 assert.match(sql,/revoke all on function public\.phase2_room_moderate/);
 assert.match(sql,/grant execute on function public\.phase2_room_moderate/);
 assert.doesNotMatch(sql,/drop table|truncate|update public\.wallets/i);
});
test('moderation: ban enforcement at membership INSERT covers direct join and private invites',()=>{
 assert.match(sql,/create trigger tc_room_ban_on_join/);
 assert.match(sql,/before insert on public\.room_members/);
 assert.match(sql,/raise exception 'ROOM_BANNED' using errcode='42501'/);
 assert.match(sql,/for update;/);
});
test('moderation: independent audit, request key and no forced remote unmute',()=>{
 assert.match(sql,/phase3\.room_moderation_requests/);
 assert.match(sql,/Moderation idempotency key conflict/);
 assert.match(sql,/insert into public\.security_audit/);
 assert.match(sql,/update public\.room_members set is_muted=true/);
 assert.doesNotMatch(sql,/set is_muted=false/);
});
