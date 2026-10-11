import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const migration=readFileSync(new URL('../supabase/migrations/20261011225500_private_android_push_consent.sql',import.meta.url),'utf8');

test('mobile notification device destination is private and consent is disabled by default',()=>{
 assert.match(migration,/push_enabled boolean not null default false/);
 assert.match(migration,/alter table phase3\.push_devices enable row level security/);
 assert.match(migration,/revoke all on phase3\.push_devices from public,anon,authenticated/);
 assert.match(migration,/phase3\.actor\(\)/);
 assert.match(migration,/public\.phase5_push_opt_in/);
 assert.match(migration,/public\.phase5_push_status/);
 assert.match(migration,/security invoker/);
});
test('disabling notifications removes registered device destinations without claiming delivery',()=>{
 assert.match(migration,/delete from phase3\.push_devices where user_id=me/);
 assert.match(migration,/Maximum 5 registered devices/);
 assert.match(migration,/'deliveryConfigured',false/);
 assert.match(migration,/token_digest bytea generated always/);
});
