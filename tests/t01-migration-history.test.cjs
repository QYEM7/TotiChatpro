'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// Read-only fingerprint of 32 migrations actually recorded on 2026-10-10 in
// Supabase TotiChatpro (sqedsnyvjblvbjbizcay). Never auto-run these on prod.
const expected = Object.freeze({
  '20261009115627_home_banners.sql': '550c3c8a715676a87a0292ab419d5c4a',
  '20261009222727_phase2_identity_profiles.sql': 'a0f39b96049f095d6079b05cdfd79874',
  '20261009223430_phase2_signup_display_name.sql': '6a36b41c1c06a28c3128f9e20d1ee1fb',
  '20261009223845_phase2_rooms_chat_seats.sql': '8d9dda863a5b48f26cd67d4a50556b93',
  '20261009231024_phase2_private_room_invitations.sql': '860cd3a38bee0208777c239e08d61cfd',
  '20261009231117_phase2_private_room_rls_and_chat_race.sql': '1798e98c715071c228f8b02790535e86',
  '20261009231753_phase2_fk_indexes.sql': 'd639d85de314e23bea503cc23d30a7d0',
  '20261009235109_phase2_readonly_wallet_foundation.sql': '7ed860882806db7e9810e9a8553bdea4',
  '20261010003152_phase2_actual_mic_mute.sql': 'a1b5598a1da50472c4a58d5d16114fa2',
  '20261010004404_phase2_feedback.sql': '4e276d4736060bd49c14d5150abd579d',
  '20261010005433_phase2_reference_catalogs.sql': '1edf7f01fb885867f8ef9e38cdfccd38',
  '20261010011419_phase3_financial_core.sql': '52f2b9c4e2d53572cc9144530807180c',
  '20261010011718_phase3_store_operations.sql': '6d3c334da0953c7cb6e86353b64c28c8',
  '20261010011950_phase3_gift_membership_guard.sql': '4fc5c18f6f1920dd83e92d89a36bf1fa',
  '20261010012020_phase3_wallet_transfer.sql': '2c5e518fe9d873fbf44176a070a35eda',
  '20261010012317_phase3_room_rpc_security.sql': 'a7d55ae432a02e90ed8e901f8b101f9f',
  '20261010012843_phase3_admin_catalogs.sql': 'e9c2613e9e010e932dab6f84363d6134',
  '20261010012937_phase3_catalog_column_validation.sql': '7e4a1a0c36f33a82a22a06ff8dddff9b',
  '20261010013049_phase3_catalog_form_schema.sql': '1cb5a0950584800fdfa680a41999d640',
  '20261010013638_phase3_confirmed_prices.sql': '70b9b17b1ed8efe0a6898e910b5a1b81',
  '20261010015119_phase4_diamond_redemption.sql': '68b7c561233954aff7eab96200e6fb9d',
  '20261010015203_phase4_cp_relationships.sql': '2e4ba9cdbe73f87bc00638a91264cde5',
  '20261010015810_phase4_admin_reports.sql': '717bbb85cbf2d9c258b7fe414cc0adf8',
  '20261010015845_phase4_report_relationship_state.sql': '069922ae333445e3906ec80e944307eb',
  '20261010020346_phase4_verified_session.sql': '03604eefbe55446779f2ad45ed097533',
  '20261010024133_phase4_agencies.sql': '2c33248408b47be34760fd176be96025',
  '20261010024245_phase4_agency_variable_scope.sql': '957d8b2eb7996ae4ab5da50553c01214',
  '20261010024326_phase4_agency_registration_assignment.sql': '03c6c7f0afd085f17f01ce674ed8bb5b',
  '20261010025125_phase4_voice_messages.sql': '8667b0f5f8536de86215828d2c977d0c',
  '20261010030849_phase4_treasury_recharge.sql': '93d5b27cd3235ce3206ca32a79be19ba',
  '20261010031010_phase4_recharge_scope.sql': '064a2ce83c768306a78b425e656a9c39',
  '20261010031301_phase4_recharge_limits.sql': 'a7ebb6fd300c3adb9ad2964e4b426e00',
});
const dir = path.join(__dirname, '..', 'supabase', 'migrations');
test('T01: applied SQL migration history has 32 unique canonical filenames and hashes', () => {
 const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort();
 const expectedFiles = Object.keys(expected).sort();
 const immutable=files.filter(f=>Object.hasOwn(expected,f));
 assert.deepEqual(immutable,expectedFiles,'One of the 32 already-applied production SQL statements is missing');
 const cutoff=expectedFiles.at(-1).slice(0,14);
 const later=files.filter(f=>!Object.hasOwn(expected,f));
 for(const f of later){
  assert.match(f,/^\\d{14}_[a-z0-9_]+\\.sql$/,'new migration filename must have Supabase timestamp format');
  assert(f.slice(0,14)>cutoff,'Do not inject earlier migrations before production-applied SQL history');
 }
 assert.equal(new Set(files.map(f=>f.slice(0,14))).size,files.length,'Migration timestamps must be unique');
 for(const filename of expectedFiles){
  const contents=fs.readFileSync(path.join(dir,filename));
  const digest=crypto.createHash('md5').update(contents).digest('hex');
  assert.equal(digest,expected[filename],filename+' has different SQL than the recorded production migration');
 }
});
