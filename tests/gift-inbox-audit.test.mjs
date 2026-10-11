import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011223000_verified_gift_inbox_notifications.sql',import.meta.url),'utf8');
const ui=readFileSync(new URL('../app/phase5-notifications-ui.js',import.meta.url),'utf8');
test('only real completed wallet-audited gifts trigger private inbox',()=>{
 assert.match(sql,/new\.action<>'gift_sent'/);
 assert.match(sql,/new\.operation_id is null/);
 assert.match(sql,/f\.operation='gift' and f\.status='completed'/);
 assert.match(sql,/fin\.actor_id<>new\.actor_id/);
 assert.match(sql,/g\.id=fin\.id and g\.sender_id=new\.actor_id/);
 assert.match(sql,/e\.recipient_id/);
 assert.match(sql,/on conflict\(recipient_id,source_type,source_id\) do nothing/);
 assert.match(sql,/when \(new\.action='gift_sent'\)/);
 assert.doesNotMatch(sql,/update public\.wallets|insert into public\.wallet_ledger/i);
});
test('existing signed-in private inbox names real received gift correctly',()=>{
 assert(ui.includes("gift_received:'استلمت هدية حقيقية جديدة'"));
 assert(ui.includes('phase5_notification_feed'));
 assert(ui.includes("[1,7,17,77,777].includes(entry.context?.quantity)"));
 assert(ui.includes("BigInt(entry.context.coinsAmount).toLocaleString('ar-IQ')"));
 assert(ui.includes('هدية · قيمتها'));
});
