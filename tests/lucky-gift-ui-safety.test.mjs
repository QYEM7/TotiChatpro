import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const ui=readFileSync(new URL('../app/phase2-catalog-ui.js',import.meta.url),'utf8');
const catalog=readFileSync(new URL('../app/phase2-catalog-data.js',import.meta.url),'utf8');
const db=readFileSync(new URL('../supabase/migrations/20261011220000_fail_closed_unapproved_lucky_gift.sql',import.meta.url),'utf8');
test('published lucky gift is visibly disabled until approved, rather than masquerading as a deterministic payout',()=>{
 assert(catalog.includes('diamond_source_type,is_active'));
 assert(ui.includes("g.diamond_source_type==='LUCKY_GIFT'"));
 assert(ui.includes('disabled aria-disabled="true"'));
 assert(ui.includes('⏳ الاحتمالات قيد الاعتماد'));
 assert(ui.includes("if(gift.diamond_source_type==='LUCKY_GIFT'){"));
 assert(ui.includes("pendingGift=null;"));
 assert.match(ui,/if\(gift\.is_active!==true\)/);
 const guard=ui.indexOf("if(gift.diamond_source_type==='LUCKY_GIFT')");
 const payment=ui.indexOf("'/rest/v1/rpc/phase3_send_gift'");
 assert(guard>0&&payment>guard,'lucky guard MUST occur before payment RPC');
});
test('server retains independent transactional lucky guard against malicious clients',()=>{
 assert(db.includes("before insert on public.gift_events"));
 assert(db.includes('LUCKY_GIFT_PENDING_RULEBOOK'));
 assert(db.includes("c.diamond_source_type='LUCKY_GIFT'"));
 assert(db.includes("new.diamond_source_type='LUCKY_GIFT'"));
 assert(db.includes("'paidPayoutsAllowed',false"));
});
