import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=readFileSync(new URL('../supabase/migrations/20261011220000_fail_closed_unapproved_lucky_gift.sql',import.meta.url),'utf8');
test('lucky gift cannot be sold with deterministic full-price payout before approved odds',()=>{
 assert.match(db,/create trigger tc_reject_unapproved_lucky_gifts/);
 assert.match(db,/before insert on public\.gift_events/);
 assert.match(db,/new\.diamond_source_type='LUCKY_GIFT'/);
 assert.match(db,/c\.diamond_source_type='LUCKY_GIFT'/);
 assert.match(db,/LUCKY_GIFT_PENDING_RULEBOOK/);
 assert.match(db,/using errcode='42501'/);
 assert.doesNotMatch(db,/\b(?:insert into|update|delete from)\s+public\.(?:wallets|wallet_ledger|diamond_lots|gift_events)/i);
});
test('readiness is explicit fail closed for genuine signed-in users',()=>{
 assert.match(db,/public\.phase5_lucky_gift_readiness/);
 assert.match(db,/perform phase3\.actor\(\)/);
 assert.match(db,/'enabled',false/);
 assert.match(db,/'purchasesAllowed',false/);
 assert.match(db,/'approvedOddsPublished',false/);
 assert.match(db,/'serverDrawAvailable',false/);
 assert.match(db,/security invoker/);
});
