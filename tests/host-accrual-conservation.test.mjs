import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=readFileSync(new URL('../supabase/migrations/20261011235900_host_accrual_deferred_conservation_guard.sql',import.meta.url),'utf8');
const snapshot=readFileSync(new URL('../supabase/migrations/20261011234000_host_month_immutable_accrual.sql',import.meta.url),'utf8');
test('immutable closed-month evidence is checked at commit, not before its lines exist',()=>{
 assert.match(sql,/create constraint trigger tc_host_accrual_commit_conservation/);
 assert.match(sql,/deferrable initially deferred/);
 assert.match(sql,/checked_rows<>new\.entries_count/);
 assert.match(sql,/checked_gifts<>new\.source_gifts/);
 assert.match(sql,/checked_diamonds<>new\.total_diamonds/);
 assert.match(sql,/errcode='23514'/);
 assert.match(snapshot,/create trigger tc_host_accrual_header_immutable/);
 assert.match(snapshot,/create trigger tc_host_accrual_line_immutable/);
});
test('monthly evidence conservation never authorizes release, payroll, or live wallet writes',()=>{
 assert.doesNotMatch(sql,/\b(?:update|delete|truncate)\s+(?:public|phase3)\./i);
 assert.match(snapshot,/canZeroDiamonds',false/);
 assert.match(snapshot,/paysSalaries',false/);
});
