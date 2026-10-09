'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const sql=read('supabase/migrations/20261010160000_phase2_readonly_wallet_foundation.sql');
const api=read('app/phase2-wallet.js');
test('new accounts start at zero coins/diamonds and wallets have row-level protection',()=>{
 assert.match(sql,/coins bigint not null default 0 check \(coins >= 0\)/);
 assert.match(sql,/diamonds bigint not null default 0 check \(diamonds >= 0\)/);
 assert.match(sql,/alter table public\.wallets enable row level security/);
 assert.match(sql,/alter table public\.wallet_ledger enable row level security/);
 assert.match(sql,/create trigger phase2_after_auth_wallet/);
 assert.match(sql,/using \(user_id=\(select auth\.uid\(\)\)\)/);
});
test('no public or user wallet/ledger write grants or client-side coin minting',()=>{
 assert.match(sql,/revoke all on public\.wallets,public\.wallet_ledger from public,anon,authenticated/);
 assert.match(sql,/grant select on public\.wallets,public\.wallet_ledger to authenticated/);
 assert.doesNotMatch(sql,/grant (update|insert|delete|all)\s+on public\.wallets/i);
 assert.doesNotMatch(api,/method:\s*['"](?:POST|PATCH|PUT|DELETE)['"]/);
 assert.match(api,/auth\.requestData\('/);
 assert.doesNotMatch(api,/service_role|sb_secret_/);
});
test('live wallet never fabricates balances when server is offline',()=>{
 assert.match(api,/if\(!Array\.isArray\(w\)\|\|w\.length!==1/);
 assert.match(api,/wallet=null;ledger=null;error=/);
 assert.match(api,/Number\.isSafeInteger/);
});
