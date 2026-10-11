import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const ui=readFileSync(new URL('../app/phase5-push-privacy-ui.js',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const migration=readFileSync(new URL('../supabase/migrations/20261011225500_private_android_push_consent.sql',import.meta.url),'utf8');

test('private Android push preferences are real server RPCs, not fake toggle state',()=>{
 assert.match(loader,/phase5-push-privacy-ui\.js/);
 assert.match(ui,/phase5_push_status/);
 assert.match(ui,/phase5_push_opt_in/);
 assert.match(ui,/p_enabled:enabled/);
 assert.match(ui,/result\.userId!==id/);
 assert.match(ui,/data\.userId===id/);
 assert.match(ui,/stamp!==epoch/);
});
test('push UI is consent only: no token harvesting, no fabricated delivery, no app builds',()=>{
 assert.match(ui,/خدمة إرسال إشعارات الهاتف غير مهيأة/);
 assert.match(ui,/الموافقة على الإشعارات مستقبلاً/);
 assert.doesNotMatch(ui,/phase5_push_device_action|fcm\.googleapis\.com|service_role|npm run build/);
 assert.match(migration,/push_enabled boolean not null default false/);
 assert.match(migration,/delete from phase3\.push_devices where user_id=me/);
});
