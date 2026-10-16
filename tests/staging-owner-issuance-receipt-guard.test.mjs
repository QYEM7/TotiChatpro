import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261012111646_staging_owner_coin_issue_cash_reference_unique_v1.sql',import.meta.url),'utf8');
const e2e=readFileSync(new URL('../scripts/t30-reseller-flow-e2e.mjs',import.meta.url),'utf8');
test('one normalized Owner receipt cannot mint new coins twice, even with parallel requests',()=>{
 assert.match(sql,/create unique index tc_owner_coin_issue_cash_reference_normalized_unique/i);
 assert.match(sql,/on public\.financial_operations/i);
 assert.match(sql,/lower\(btrim\(payload #>> '\{data,cash_reference\}'\)\)/);
 assert.match(sql,/operation='recharge_action'/);
 assert.match(sql,/payload->>'action'='issue'/);
 assert.match(e2e,/const duplicateMint=await cash\(owner,'issue'/);
 assert.match(e2e,/tc_owner_coin_issue_cash_reference_normalized_unique/);
});
test('migration does not mint currency or tamper with existing operations',()=>{
 const active=sql.replace(/--[^\n]*/g,'');
 assert.doesNotMatch(active,/\b(?:update|delete|insert|truncate)\s+(?:public|phase3)\./i);
 assert.doesNotMatch(active,/\bdrop\s+index\b/i);
});
