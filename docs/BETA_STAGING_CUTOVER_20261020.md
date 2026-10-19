# TotiChat Project 01 — Actual Staging security/gift cutover

Date (Baghdad): 2026-10-20. Repo: `QYEM7/TotiChatpro`, branch: `rebuild/flutter-v1`.
Supabase Staging ID: `rziaedugbdwefbefcxjt`. **No production / main changes.**

## Deployed to Supabase Staging — verified against real schema

All four migrations were applied through Supabase migration tracking and then verified through read-only SQL:

| Migration/version | Effect | Actual result |
|---|---|---|
| `20261019222311_staging_verified_room_gift_chat_v1` | Add `room_messages.event_kind`, `gift_event_id`, unique gift event constraint and deferred financial proof trigger | Applied; columns, deferred trigger, authenticated INSERT denial and trigger EXECUTE denial verified |
| `20261019222338_staging_verified_room_seat_gift_totals_v1` | Current room members may read per-seat recipient gift totals only from completed financial operations with matching two-sided ledger | Applied; RPC exists; authenticated EXECUTE allowed, anon EXECUTE denied |
| `20261019222504_staging_verified_sfu_moderation_relay_acl_v1` | Close public/private direct SFU-bypass of mute, kick, ban, seat release; relay is service-role-only | Applied; authenticated cannot EXECUTE `phase3.room_moderation_action` or service-only relay; service_role can execute relay |
| `20261019222702_staging_public_room_moderation_invoker_v2` | Avoid public authenticated SECURITY DEFINER by adding private, strictly allowed benign moderation function | Applied; `public.phase2_room_moderate` now SECURITY INVOKER; direct sensitive function remains inaccessible to authenticated |

Deployed Supabase Edge Function `phase2-voice-moderate` version **2**, status **ACTIVE**, `verify_jwt=true`. Its source checks the same verified user session before using a server-only service key, rechecks database authorization, and calls LiveKit removeParticipant with explicit `revokeTokenTs`. It reports success only when database and SFU confirmation are both returned.

**Source correspondence:** All applied SQL is checked into `supabase/migrations/` under the same migration version/name as Supabase Staging history. Existing source candidates remain under `supabase/patches/` for review only; do not reapply them.

## Verification evidence

- [Voice source, Deno and PostgreSQL role integration CI #39334961764](https://github.com/QYEM7/TotiChatpro/actions/runs/39334961764): passed, including the subsequent SECURITY INVOKER/public private allowlist design.
- [Gift-room-chat PostgreSQL settlement CI #39333385132](https://github.com/QYEM7/TotiChatpro/actions/runs/39333385132): passed (one chat per fully settled gift, no chat for incomplete or failed transactions).
- [Verified seat totals PostgreSQL member isolation CI #39334064037](https://github.com/QYEM7/TotiChatpro/actions/runs/39334064037): passed (matching room only, complete ledger only, seat reassignment, stale session denial).
- [Flutter analyzer/tests #39333946888](https://github.com/QYEM7/TotiChatpro/actions/runs/39333946888): passed prior to SQL cutover; no Flutter code changed during these deployments.
- Read-only Staging SQL verified precise function privileges, public security invoker status, trigger existence and schema columns after deployment.
- Supabase security advisor no longer reports the earlier **authenticated public SECURITY DEFINER** moderation warning. Another security advisor warning for leaked-password protection is unrelated to Google-only beta sign-in and has not been modified.

## No claims of end-to-end device validation

- Real Android Google OAuth and callback: **NOT VERIFIED**.
- Two phones connected through LiveKit, mute/kick/rejoin: **NOT VERIFIED**. LIVEKIT_URL and credential availability were not independently exercised with an authenticated participant. The Edge function's ACTIVE status proves deployment, not SFU connectivity.
- Financial real-money wallet/gift acceptance with two users, 1/7/17/77/777 quantities, idempotent retries: **NOT VERIFIED**.
- Room gift chat actual realtime appearance on two phones and settled counters under 15 seats: **NOT VERIFIED**.
- Visual parity to approved Flutter UI, 15-seat constraints across device sizes, admin access: **NOT VERIFIED**.
- New APK for this commit: **NOT BUILT**. Earlier test APKs predate the security and gift fixes; they must not be used as proof of this latest build.

## Immediate acceptance plan

1. Install a newly built **Staging-only test APK**, with the correct package and Google redirect, on two physical Android phones. Sign in to two separate legitimate Google accounts; confirm sign-out, re-auth and callback.
2. Create and join one real voice room; verify both phones see the same 15 seats and seat changes. Join LiveKit and confirm mutual speech/listen and microphone behavior.
3. From authorized room owner account: mute, release seat, kick and reconnect. Verify *both* DB state and SFU behavior; a disconnected/stale participant token must not rejoin without authorization. Try a non-moderator denial.
4. Authorize and perform one controlled Staging gift, with actual wallet source/recipient and price confirmation. Confirm exactly one wallet debit, one recipient credit, one `gift_events` row, one gift room-chat notice, and current recipient seat counter. Retry the same UUID without a second charge.
5. Verify no banner unless a real settled gift with unit price >=7000 qualifies. Finish visual/device QA and operator sign-off.

**Release remains blocked** until critical end-to-end acceptance passes. No seed data or fabricated gifts, no production data mutations, no public release.
