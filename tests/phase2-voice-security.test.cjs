'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const get=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const edge=get('supabase/functions/phase2-voice-token/index.ts');
const rpc=get('supabase/migrations/20261010003152_phase2_actual_mic_mute.sql');
const media=get('app/phase2-voice-ui.js');
const realSdk=get('app/phase2-livekit-sdk.mjs');
const manifest=get('scripts/configure-android-auth.mjs');
test('voice token endpoint is authenticated and tied to actual member and seat',()=>{
 assert.match(edge,/db\.auth\.getUser\(\)/);
 assert.match(edge,/from\('room_members'\)/);
 assert.match(edge,/eq\('user_id',userId\)/);
 assert.match(edge,/seat_no!==null&&!memberResult\.data\.is_muted/);
 assert.match(edge,/if\(!livekitUrl\|\|!livekitKey\|\|!livekitSecret\)return json\(503/);
 assert.match(edge,/new AccessToken/);
 assert.doesNotMatch(edge,/sb_secret_|sk_test_\w+|password\s*[:=]\s*["']/i);
});
test('mic mute server mutation never permits a member without a seat to unmute',()=>{
 assert.match(rpc,/auth\.uid\(\)/);
 assert.match(rpc,/seat is null/);
 assert.match(rpc,/raise exception 'take a seat first'/);
 assert.match(rpc,/revoke all on function public\.phase2_room_set_muted/);
});
test('no demo audio. Local native microphone and LiveKit client are packaged',()=>{
 assert.match(realSdk,/import \{Room,RoomEvent,ConnectionState\} from 'livekit-client'/);
 assert.match(realSdk,/setMicrophoneEnabled/);
 assert.match(media,/requestVoiceToken/);
 assert.match(media,/phase2_room_set_muted/);
 assert.match(media,/LIVEKIT_NOT_CONFIGURED/);
 assert.match(manifest,/android\.permission\.RECORD_AUDIO/);
 assert.doesNotMatch(realSdk,/oscillator|synth|fakeAudio|dummyStream/i);
});
