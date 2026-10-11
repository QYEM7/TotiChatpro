import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011234000_host_month_immutable_accrual.sql',import.meta.url),'utf8');
const ui=readFileSync(new URL('../app/phase5-host-month-review-ui.js',import.meta.url),'utf8');

test('monthly host accrual evidence is private, immutable and strictly historical',()=>{
 assert.match(sql,/phase3\.host_month_accrual_headers/);
 assert.match(sql,/phase3\.host_month_accrual_lines/);
 assert.match(sql,/before update or delete/);
 assert.match(sql,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(sql,/phase3\.actor\(\)/);
 assert.match(sql,/join public\.diamond_lots l on l\.gift_event_id=g\.id/);
 assert.match(sql,/p_month>=date_trunc\('month',now\(\) at time zone 'UTC'\)::date/);
 assert.match(sql,/alreadyCaptured',true/);
 assert.match(sql,/paysSalaries',false/);
 assert.match(sql,/canZeroDiamonds',false/);
 assert.match(sql,/hasPayrollRates',false/);
});
test('no automatic diamond reset or salary, frontend requires explicit authorized capture',()=>{
 assert.match(sql,/public\.phase5_host_month_snapshot_capture/);
 assert.match(sql,/language plpgsql security invoker/);
 assert.match(sql,/revoke all on function public\.phase5_host_month_snapshot_capture/);
 assert.match(ui,/phase5_host_month_snapshot_state/);
 assert.match(ui,/phase5_host_month_snapshot_capture/);
 assert.match(ui,/confirm\(/);
 assert.match(ui,/crypto\.randomUUID\(\)/);
 assert.match(ui,/stamp!==epoch/);
 assert.doesNotMatch(sql,/\b(?:update|delete)\s+(?:public\.(?:wallets|diamond_lots)|phase3\.host_month_accrual)/i);
});
