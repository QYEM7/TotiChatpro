import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011201500_verified_medal_entitlements.sql',import.meta.url),'utf8');
test('owner medals are real persisted approved records without wallet or XP mutation',()=>{
 assert.match(sql,/create table public\.medal_entitlements/);
 assert.match(sql,/create table public\.medal_catalog/);
 assert.match(sql,/alter table public\.medal_entitlements enable row level security/);
 assert.match(sql,/revoke all on public\.medal_entitlements from public,anon,authenticated/);
 assert.match(sql,/if not phase3\.is_owner\(\)/);
 assert.match(sql,/insert into public\.security_audit/);
 assert.doesNotMatch(sql,/update public\.wallets|insert into public\.wallet_ledger|auto_grant|insert into public\.vip_entitlements/i);
});
test('client RPCs are security invoker and do not allow anonymous grant',()=>{
 for(const name of ['phase5_medal_owner_action','phase5_medal_user','phase5_medal_catalog'])
  assert(sql.includes('function public.'+name+'('),name);
 assert.match(sql,/phase3\.actor\(\)/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/revoke all on function public\.phase5_medal_owner_action/);
 assert.match(sql,/Medal idempotency conflict/);
 assert.match(sql,/Medal action rate limit exceeded/);
});
