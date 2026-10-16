import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261012100127_staging_recharge_receipt_replay_guard_v1.sql',import.meta.url),'utf8');
test('approved agency cash reference cannot be reused with case or whitespace variants',()=>{
 assert.match(sql,/create unique index tc_recharge_completed_receipt_normalized_unique/i);
 assert.match(sql,/on public\.recharge_requests\(agency_id,\(lower\(btrim\(cash_reference\)\)\)\)/);
 assert.match(sql,/where status='completed' and cash_reference is not null/);
 assert.match(sql,/tc_recharge_completed_receipt_nonblank/);
 assert.match(sql,/char_length\(btrim\(cash_reference\)\) between 3 and 120/);
 assert.match(sql,/status <> 'completed'/);
});
test('receipt replay guard must not rewrite historic records or change wallet balances',()=>{
 const active=sql.replace(/--[^\n]*/g,'');
 assert.doesNotMatch(active,/\b(?:update|delete|truncate|insert)\s+(?:public|phase3)\./i);
 assert.doesNotMatch(active,/alter\s+table\s+(?:public\.)?(?:wallets|wallet_ledger|treasury_accounts)/i);
 assert.doesNotMatch(active,/drop\s+index|drop\s+constraint/i);
});
