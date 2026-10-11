# TotiChat — Staging Backend Handoff (2026-10-11)

## Environment
- GitHub repository: QYEM7/TotiChatpro
- Branch: develop/phase-2
- Supabase STAGING project: rziaedugbdwefbefcxjt
- Production database: UNTOUCHED.
- All new financial/privacy capabilities below are **staging-only** until signed-off tests.

## Migrations applied
1. `20261011000200_phase2_private_text_messages.sql`
   - `public.direct_messages` is TEXT-ONLY; authenticated users can read only messages involving themselves.
   - `public.dm_blocks` stores personal block lists.
   - No direct client INSERT/UPDATE/DELETE on either table. Only server-authorized RPCs.
   - Real-time Postgres Changes are enabled, with participant-based RLS.
2. `20261011000201_phase3_verified_global_gift_feed.sql`
   - `public.gift_announcement_settings` is disabled by default, with unset threshold.
   - `public.gift_global_announcements` can be read by **all signed-in users in every room**.
   - Administrative threshold is service-role-only, NOT writable from a browser.
3. `20261011000202_phase2_voice_token_preflight.sql`
   - Membership, seat/mute grants, and 20 token requests/min budget.
   - Does not use client-supplied VIP or moderator status.
4. `20261011000203_deferred_verified_gift_settlement.sql`
   - Deferred trigger checks completed financial operation AND both sender debit / recipient diamond credit entries.
   - Only qualifying `gift_catalog.global_announcement_enabled` gifts above the configured unit-price threshold are announced.
   - Gift event id is unique across announcements (idempotent).

## Browser-safe RPC contract (JWT required)

### Private text messages
- `POST /rest/v1/rpc/phase2_dm_send`
  `{"p_recipient_id":"uuid","p_body":"hello","p_request_id":"new-uuid-v4"}`
- `POST /rest/v1/rpc/phase2_dm_inbox` `{"p_limit":30}`
- `POST /rest/v1/rpc/phase2_dm_thread`
  `{"p_other_user":"uuid","p_before_id":null,"p_limit":50}`
- `POST /rest/v1/rpc/phase2_dm_mark_read`
  `{"p_other_user":"uuid","p_through_id":null}`
- `POST /rest/v1/rpc/phase2_dm_block`
  `{"p_other_user":"uuid","p_block":true}`

Do not put voice-note recording buttons into private conversations. Opening private chat must not disconnect the current LiveKit room, microphone, microphone seat, or listening session.

### Worldwide gift feed
- `GET /rest/v1/gift_global_announcements?select=*&order=created_at.desc&limit=25`
- Supabase Realtime: authenticated `postgres_changes` INSERT on `public.gift_global_announcements`; do not filter by room id.
- Deduplicate by `id` in UI, show sender and recipient names, gift snapshot, real quantity and animation.
- Default feed stays empty until administrator sets `gift_catalog.global_announcement_enabled` and a minimum unit-price threshold AND a genuine successful gift happens.

### Internal-only admin
- `public.phase3_set_gift_global_threshold(p_enabled boolean,p_min_gift_price bigint)` may be executed only by `service_role` on the backend.
- Never expose service-role API credentials to the app. A role-aware administrative Edge Function must be added before the owner dashboard can configure it.

### Voice
- `POST /functions/v1/phase2-voice-token` `{"roomId":"uuid"}`
- JWT authenticated, Supabase Auth verification + room membership + server-side seat/mute access + 20/min DB rate limit.
- Edge deployed as ACTIVE, `verify_jwt=true`, to STAGING, version 1.
- **Blocking requirement**: configure Staging-only `LIVEKIT_URL` (wss), `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` in Supabase Edge Secrets. Never reuse or copy production secrets.
- Actual voice between two devices / networks remains untested.

## Read-only SQL verification
As of implementation, eight checks passed:
- deferred trigger for settled gifts
- global announcements default disabled
- both protected tables in realtime publication
- private messages RLS SELECT policy
- client direct DML denied
- admin threshold RPC unavailable to normal authenticated role
- zero synthetic global announcements
- zero synthetic private messages

## Outstanding
- Browser UI is not yet connected to the five private-message RPCs or the global gift feed.
- No genuine test gift transaction or two-device private chat has been performed.
- Owner role/permission system for browser-side global gift threshold control is pending.
- Staging LiveKit secrets are not confirmed and must be configured before claiming voice works.
- Staging Security Advisor reports intentional executable SECURITY DEFINER RPC warnings (manual permission review recommended) plus leaked-password protection disabled in Auth Settings.
- Do not merge to production before integration, abuse, multi-device and RLS tests.
