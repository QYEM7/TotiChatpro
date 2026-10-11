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
test('final approved visual identity is preserved without temporary lavender override',()=>{
 const html=file('app/index.html');
 const activeGate=file('app/phase2-live-mode.js');
 assert.match(html,/room-seats-finish\.css/);
 assert.match(html,/identity-return\.css/);
 assert.doesNotMatch(html,/<link[^>]*phase2-lavender-identity\.css/);
 assert.doesNotMatch(activeGate,/classList\.add\('tc-live-visual-identity'\)/);
});
test('private text inbox is authenticated and can be opened without leaving voice room',()=>{
 const html=file('app/index.html');
 const gate=file('app/phase2-live-mode.js');
 const dm=file('app/phase2-private-messages.js');
 const css=file('app/phase2-private-messages.css');
 const sql=file('supabase/migrations/20261011000200_phase2_private_text_messages.sql');
 assert.match(html,/phase2-private-messages\.js/);
 assert.match(html,/phase2-private-messages\.css/);
 assert.match(gate,/'messages','chatPreview'/);
 assert.match(gate,/dataset\.tcDmRecipient/);
 assert.match(dm,/rpc\('send'/);
 assert.match(dm,/rpc\('inbox'/);
 assert.match(dm,/rpc\('thread'/);
 assert.match(dm,/rpc\('mark_read'/);
 assert.match(dm,/rpc\('block'/);
 assert.match(dm,/totichat-private-message-update/);
 assert.match(dm,/data-tc-dm-close/);
 assert.doesNotMatch(dm,/getUserMedia|MediaRecorder|microphone\(/);
 assert.match(css,/\.tc-dm-overlay/);
 assert.match(sql,/dm_two_participants_read/);
 assert.match(sql,/dm_request_unique/);
 assert.match(sql,/dm_block_distinct_users/);
});
test('global gift feed is sourced only from completed audited server transactions',()=>{
 const html=file('app/index.html');
 const feed=file('app/phase2-global-gifts.js');
 const rooms=file('app/phase2-rooms.js');
 const auth=file('app/phase2-auth.js');
 const schema=file('supabase/migrations/20261011000201_phase3_verified_global_gift_feed.sql');
 const settlement=file('supabase/migrations/20261011000203_deferred_verified_gift_settlement.sql');
 assert.match(html,/phase2-global-gifts\.js/);
 assert.match(feed,/gift_global_announcements\?select/);
 assert.match(feed,/seen\.has\(row\.id\)/);
 assert.match(feed,/watchSocialUpdates/);
 assert.match(rooms,/TotiGlobalGiftFeed\?\.decorateTicker/);
 assert.match(auth,/table:'direct_messages'/);
 assert.match(auth,/table:'gift_global_announcements'/);
 assert.match(schema,/min_gift_price/);
 assert.match(settlement,/recipient_ledger\.amount_change=new\.amount/);
 assert.match(settlement,/deferrable initially deferred/);
});
test('voice UI reports unavailable SFU and allows explicit playback resume',()=>{
 const voice=file('app/phase2-voice-ui.js');
 assert.match(voice,/LIVEKIT_NOT_CONFIGURED/);
 assert.match(voice,/dataset\.realVoice='resume'/);
 assert.match(voice,/resumeAudio/);
 assert.match(voice,/tc-real-voice-feedback/);
});


test('admin controls are real, role-gated and never expose service-role secrets',()=>{
 const admin=file('app/phase2-backend-controls.js');
 const html=file('app/index.html');
 const sql=file('supabase/migrations/20261011000303_global_gift_owner_controls.sql');
 const staff=file('supabase/migrations/20261011000302_db_staff_host_agency_open_only.sql');
 const wrappers=file('supabase/migrations/20261011000300_secure_social_rpc_wrappers.sql');
 assert.match(html,/phase2-backend-controls\.js/);
 assert.match(admin,/phase3_admin_session/);
 assert.match(admin,/phase3_global_gift_admin/);
 assert.match(admin,/isMainPartner/);
 assert.match(admin,/host_agency\.open/);
 assert.doesNotMatch(admin,/service_role|SUPABASE_SERVICE_ROLE_KEY|LIVEKIT_API_SECRET/);
 assert.match(sql,/isMainPartner/);
 assert.match(sql,/global_gift_config/);
 assert.match(staff,/p_action='approve_registration' and reg\.kind='host'/);
 assert.match(wrappers,/security invoker/);
});

test('connected support ticket center uses verified server-side actions',()=>{
 const html=file('app/index.html');
 const ui=file('app/phase5-support-ui.js');
 const controls=file('app/phase2-backend-controls.js');
 const sql=file('supabase/migrations/20261011000400_phase5_support_tickets.sql');
 assert.match(html,/phase5-support-ui/);
 assert.match(ui,/phase5_support_/);
 assert.match(controls,/supportOpen/);
 assert.match(sql,/phase3\.actor/);
 assert.match(sql,/phase3\.is_owner/);
});
test('agency historical preflight is read-only by contract',()=>{
 const sql=file('supabase/migrations/20261011000401_phase5_host_month_preflight.sql');
 const ui=file('app/phase4-agencies-ui.js');
 assert.match(sql,/canZeroDiamonds/);
 assert.match(sql,/paysSalaries/);
 assert.match(ui,/phase5_host_month_preflight/);
});
