import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync(new URL('../supabase/migrations/20261011235500_fk_covering_indexes_phase5.sql',import.meta.url),'utf8');
const expected=[
 ['phase3','host_month_accrual_lines','host_id'],
 ['phase3','social_follow_requests','target_id'],
 ['phase3','special_id_grant_requests','target_id'],
 ['public','account_special_ids','granted_by'],
 ['public','medal_catalog','created_by'],
 ['public','medal_entitlements','granted_by'],
 ['public','medal_entitlements','medal_key'],
 ['public','medal_entitlements','revoked_by'],
 ['public','room_bans','banned_by'],
 ['public','room_game_matches','player_o'],
 ['public','room_game_matches','player_x'],
 ['public','room_game_matches','winner_id'],
 ['public','room_moderators','assigned_by'],
 ['public','room_music_queue','added_by'],
 ['public','room_music_queue','bookmark_id'],
 ['public','room_mutes','muted_by'],
 ['public','vip_entitlements','granted_by'],
];
test('all 17 verified FK advisor findings have idempotent indexes',()=>{
 for(const [schema,table,col] of expected){
  assert(sql.includes('create index if not exists tc_fk_'+table+'_'+col+'_ix on '+
    schema+'.'+table+'('+col+');'),'Missing covering index for '+schema+'.'+table+'.'+col);
 }
 assert.equal((sql.match(/create index if not exists /g)||[]).length,17);
 assert.doesNotMatch(sql,/\b(?:insert|update|delete|drop|truncate)\s+(?:table|from|into|public|phase3)\b/i);
});
