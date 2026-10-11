import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const s=readFileSync(new URL('../supabase/migrations/20261011200500_owner_special_id.sql',import.meta.url),'utf8');
test('Owner-controlled special identity remains unique, permanent and server audited',()=>{
 assert.match(s,/public_id text not null unique/);
 assert.match(s,/phase3.is_owner\(\)/);
 assert.match(s,/phase3.actor\(\)/);
 assert.match(s,/Special ID idempotency conflict/);
 assert.match(s,/Public ID already assigned and cannot be changed/);
 assert.match(s,/insert into public.security_audit/);
 assert.match(s,/create function public.phase5_special_id_status/);
 assert.match(s,/revoke all on public.account_special_ids from public,anon,authenticated/);
 assert.doesNotMatch(s,/update auth.users set id|alter table auth.users|sampleIds|auto_generate_public_id/i);
});