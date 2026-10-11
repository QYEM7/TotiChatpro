import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const code=readFileSync(new URL('../supabase/migrations/20261011181500_verified_notification_inbox.sql',import.meta.url),'utf8');
test('notification inbox is owner-RLS and denies direct client mutations',()=>{
 assert.match(code,/alter table public\.user_notifications enable row level security/);
 assert.match(code,/recipient_id=\(select auth\.uid\(\)\)/);
 assert.match(code,/grant select on public\.user_notifications to authenticated/);
 assert.match(code,/revoke all on public\.user_notifications from public,anon,authenticated/);
 assert.doesNotMatch(code,/grant (insert|update|delete) on public\.user_notifications to authenticated/i);
});
test('only server verified audit actions and support replies create notifications',()=>{
 for(const phrase of ['after insert on public.security_audit','after insert on public.support_messages',
  'vip_granted','vip_revoked','room_banned','room_muted','support_staff_replied',
  'on conflict(recipient_id,source_type,source_id) do nothing'])
  assert(code.includes(phrase),phrase);
 assert.match(code,/if owner is null or new\.author_id=owner then return new/);
 assert.match(code,/jsonb_build_object\('ticketId',new\.ticket_id\)/);
 assert.doesNotMatch(code,/new\.body|t\.subject|message_text|fcm_token|service_role_key/);
});
test('invoker RPCs validate session, bound pages and own-only read acknowledgment',()=>{
 assert.match(code,/create function public\.phase5_notification_feed/);
 assert.match(code,/create function public\.phase5_notification_mark/);
 assert.match(code,/perform phase3\.actor\(\)/);
 assert.match(code,/p_limit not between 1 and 50/);
 assert.match(code,/cardinality\(p_ids\)>100/);
 assert.match(code,/where recipient_id=caller and read_at is null/);
 assert.match(code,/where recipient_id=caller and \(p_before is null or id<p_before\)/);
 assert.doesNotMatch(code,/\btruncate\b|\bdrop table\b|update public\.wallets/i);
});
