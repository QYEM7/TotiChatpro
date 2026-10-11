import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const file=(name)=>readFileSync(new URL('../'+name,import.meta.url),'utf8');

test('TotiChat live room is served from its real backend, not preview gifts',()=>{
 const gate=file('app/phase2-live-mode.js');
 assert.match(gate,/showGifts\(\);return;/);
 assert.match(gate,/data-live-room-action/);
 assert.doesNotMatch(gate,/op==='chatTab'&&\['هدية','أدخل'\]\.includes\(route\)/);
 const catalog=file('app/phase2-catalog-ui.js');
 assert.match(catalog,/rpc\/phase3_send_gift/);
 assert.match(catalog,/p_expected_price/);
 assert.match(catalog,/data-catalog-quantity/);
 assert.match(catalog,/p_quantity:giftQuantity/);
});
test('room create keeps owner-only persisted image and welcome settings',()=>{
 const room=file('app/phase2-rooms.js');
 const auth=file('app/phase2-auth.js');
 const sql=file('supabase/migrations/20261011000100_phase2_room_identity_background.sql');
 assert.match(room,/tc-phase2-room-cover/);
 assert.match(room,/tc-phase2-room-welcome/);
 assert.match(room,/tc-phase2-room-background/);
 assert.match(room,/phase2_room_customize/);
 assert.match(room,/openSettings/);
 assert.match(room,/roomMeta/);
 assert.match(room,/image_revision/);
 const revision=file('supabase/migrations/20261011000101_phase2_room_image_revision.sql');
 assert.match(revision,/gen_random_uuid\(\)/);
 assert.match(auth,/uploadRoomImage/);
 assert.match(sql,/room owner required/i);
 assert.match(sql,/owner_id=\(select auth.uid\(\)\)/);
 assert.match(sql,/allowed_mime_types/);
});
test('new light room visual identity retains original seat layout',()=>{
 const html=file('app/index.html');
 const css=file('app/phase2-lavender-identity.css');
 assert.match(html,/phase2-lavender-identity\.css/);
 assert.match(html,/room-seats-finish\.css/);
 assert.match(css,/tc-live-visual-identity/);
 assert.match(css,/--tc-room-wallpaper/);
 assert.doesNotMatch(css,/\.seats\s*\{[^}]*display\s*:\s*none/i);
 assert.match(css,/roomview\.room-v2/);
});
test('voice UI reports unavailable SFU and allows explicit playback resume',()=>{
 const voice=file('app/phase2-voice-ui.js');
 assert.match(voice,/LIVEKIT_NOT_CONFIGURED/);
 assert.match(voice,/dataset\.realVoice='resume'/);
 assert.match(voice,/resumeAudio/);
 assert.match(voice,/tc-real-voice-feedback/);
});
