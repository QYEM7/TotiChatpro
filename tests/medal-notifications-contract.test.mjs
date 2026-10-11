import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011203000_verified_medal_notifications.sql',import.meta.url),'utf8');
const ui=readFileSync(new URL('../app/phase5-notifications-ui.js',import.meta.url),'utf8');
test('medal grants only reach recipient from server-audited grant and revoke',()=>{
 assert.match(sql,/when 'medal_grant' then 'medal_granted'/);
 assert.match(sql,/when 'medal_revoke' then 'medal_revoked'/);
 assert.match(sql,/when kind like 'medal_%' then/);
 assert.match(sql,/jsonb_build_object\('medalKey',medal\)/);
 assert.match(sql,/new\.actor_id/);
 assert.match(sql,/on conflict\(recipient_id,source_type,source_id\) do nothing/);
 assert(!/insert into public\.wallets|update public\.wallets|coin_bonus|add fake/.test(sql));
});
test('medal notifications have actual text in the authenticated inbox',()=>{
 assert(ui.includes("medal_granted:'حصلت على ميدالية معتمدة'"));
 assert(ui.includes("medal_revoked:'تم سحب ميدالية من حسابك'"));
 assert(ui.includes('phase5_notification_feed'));
});
