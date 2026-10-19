import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync(
 new URL('../supabase/patches/voice_moderation_relay_acl_candidate.sql',import.meta.url),'utf8'
);
const edge=readFileSync(
 new URL('../supabase/functions/phase2-voice-moderate/index.ts',import.meta.url),'utf8'
);

test('voice-affecting actions cannot be committed via public user RPC',()=>{
 assert.match(sql,/if p_action in \('mute','kick','ban','release_seat'\)/);
 assert.match(sql,/VOICE_RELAY_REQUIRED/);
 assert.match(sql,/create or replace function public\.phase2_room_moderate\(/);
 assert.match(sql,/perform phase3\.actor\(\)/);
});

test('direct private action cannot be executed by authenticated or anon',()=>{
 assert.match(sql,/revoke all on function phase3\.room_moderation_action\([\s\S]*?\) from public,anon,authenticated;/);
 assert.match(sql,/security definer/);
 assert.doesNotMatch(sql,/grant execute on function phase3\.room_moderation_action[\s\S]*?to authenticated;/);
});

test('privileged voice relay requires service role and verified session',()=>{
 assert.match(sql,/create or replace function public\.phase2_room_moderate_voice_relay\(/);
 assert.match(sql,/original_role is distinct from 'service_role'/);
 assert.match(sql,/p_verified_user_claims->>'role' is distinct from 'authenticated'/);
 assert.match(sql,/pg_catalog\.set_config\(\s*'request\.jwt\.claims'/);
 assert.match(sql,/perform phase3\.actor\(\)/);
 assert.match(sql,/grant execute on function public\.phase2_room_moderate_voice_relay\([\s\S]*?\) to service_role;/);
 assert.match(sql,/revoke all on function public\.phase2_room_moderate_voice_relay\([\s\S]*?\) from public,anon,authenticated;/);
});

test('edge authenticates both user and current session before privileged call',()=>{
 const authAt=edge.indexOf('auth.getUser(userToken)');
 const verifiedAt=edge.indexOf("supabase.rpc('phase4_verified_session')");
 const trustedAt=edge.indexOf("trusted.rpc('phase2_room_moderate_voice_relay'");
 assert(authAt>=0&&verifiedAt>authAt&&trustedAt>verifiedAt);
 assert.match(edge,/claims\['sub'\]!==auth\.user\.id/);
 assert.match(edge,/claims\['role'\]!=='authenticated'/);
 assert.match(edge,/SUPABASE_SERVICE_ROLE_KEY/);
 assert.match(edge,/if\(!backendUrl\|\|!backendKey\|\|!privilegedKey\)/);
 assert.match(edge,/role:claims\['role'\]/);
 assert.match(edge,/sub:claims\['sub'\]/);
 assert.match(edge,/session_id:claims\['session_id'\]/);
 assert.match(edge,/aal:claims\['aal'\]/);
 assert.doesNotMatch(edge,/p_verified_user_claims:\s*userToken/);
 assert.doesNotMatch(edge,/supabase\.rpc\('phase2_room_moderate',/);
});

test('voice action requires confirmed database and SFU results',()=>{
 assert.match(edge,/databaseCommitted:false/);
 assert.match(edge,/databaseCommitted:true,sfuDisconnected:false/);
 assert.match(edge,/databaseCommitted:true,sfuDisconnected:true/);
 assert.match(edge,/revokeTokenTs: BigInt\(Math\.floor\(Date\.now\(\)\/1000\)\)/);
 assert.match(edge,/await api\.removeParticipant\(roomId,targetId,/);
 assert.doesNotMatch(edge,/SUPABASE_SERVICE_ROLE_KEY.*reply\(200/);
});

test('patch does not touch treasury or wallet or production',()=>{
 assert.doesNotMatch(sql,/\b(?:drop|truncate)\s+table\b|update public\.wallets|insert into public\.gift_events/i);
 assert.doesNotMatch(sql,/\b(?:commit\s+prepared|create extension)\b/i);
 assert.match(sql,/begin;[\s\S]*commit;/);
});
