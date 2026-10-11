import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261011171000_vip10_entitlements.sql',import.meta.url),'utf8');
test('VIP ten-tier server model defaults to no entitlement and requires audited Owner action',()=>{
 assert.match(sql,/tier smallint not null check\(tier between 0 and 10\)/);
 assert.match(sql,/if not phase3\.is_owner\(\)/);
 assert.match(sql,/caller uuid:=phase3\.actor\(\)/);
 assert.match(sql,/insert into public\.security_audit/);
 assert.match(sql,/VIP idempotency key conflict/);
 assert.match(sql,/phase3\.vip_action_requests/);
 assert.doesNotMatch(sql,/update public\.wallets|insert into public\.financial_operations|\bTRUNCATE\b/i);
});
test('VIP functions do not expose privileged helpers as public SECURITY DEFINER RPCs',()=>{
 assert.match(sql,/create function phase3\.vip_action/);
 assert.match(sql,/create function public\.phase5_vip_owner_action/);
 assert.match(sql,/create function public\.phase5_vip_status/);
 assert.match(sql,/security invoker/);
 assert.match(sql,/revoke all on public\.vip_entitlements from public,anon,authenticated/);
 assert.match(sql,/grant execute on function public\.phase5_vip_status\(uuid\) to authenticated/);
});
test('VIP expiration is enforced when reading entitlement instead of requiring a paid scheduler',()=>{
 assert.match(sql,/current_entitlement\.expires_at<=now\(\)/);
 assert.match(sql,/jsonb_build_object\('userId',p_target,'tier',0,'active',false/);
});
