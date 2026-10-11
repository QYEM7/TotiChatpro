# TotiChat — Backend Staging execution and delivery audit (2026-10-11)

## Execution scope and actual state
- GitHub: `QYEM7/TotiChatpro`; allowed development branch: `develop/phase-2`.
- Isolated Staging Supabase: `rziaedugbdwefbefcxjt`.
- Database production and GitHub `main`: **not modified**.
- Approved UI and 15 mic seats: **no design or UI changes** in this backend execution.
- Inspected starting branch head: `5ae1ab1d244388b140fa20224281a0f4a200097a`.
- Last source commit independently tested: `070363a288d7617dba3098ca51972bbbd7b90070`.
- Staging migration count increased from **47 to 51** by four explicit additive/hardening migrations. Staging history uses different migration timestamps than the older GitHub prototype files: never run a blind remote db push or a reset to reconcile version IDs.

## Migrations ACTUALLY APPLIED to STAGING
1. `staging_t14_profile_avatar_storage`: existing source `20261010124900_t14_profile_avatar_storage.sql`. WebP 2MB bucket; 3 owner-scoped Storage object policies.
2. `staging_t17_room_realtime`: existing source `20261010133600_t17_realtime_rooms.sql`. Adds public.rooms, room_members and room_messages to Realtime publication without removing their RLS.
3. `staging_t23_saved_music_queue`: existing source `20261010152000_t23_saved_music_queue.sql`. Two persisted tables, 6 explicit RLS policies, user bookmark ownership and room-owner queue writes, no licensed audio stream.
4. `staging_backend_actor_serialization_support_privacy`: new source `20261011141000_backend_actor_serialization_support_privacy.sql`. Preserves the existing `phase3.agency_action`, `phase3.recharge_action`, and `phase3.support_action` business logic, inserts verified per-actor transaction locks before idempotency/quota checks, and stores SHA-256 retry fingerprints rather than duplicate support-ticket plaintext.

### Direct SQL verification
- 51 applied migrations; 2 music tables; 6 music RLS policies; avatar bucket with 3 policies; 3 room Realtime tables.
- `anon` cannot SELECT music bookmarks or room queue; `authenticated` has no broad UPDATE grant there.
- All 3 sensitive private functions have verified-actor transaction locks; the support retry function contains the fingerprint logic; the exposed actions remain inaccessible to anonymous callers.
- Financial operations, wallet ledger, gift events and support retry records remained at 0 during the migration verification. **No artificial financial activity was added to Staging**.
- The reserved, email-verified sole Owner account existed in Staging but `owner_id` had never been materialized. It was linked using an atomic conditional check of the approved reserved email plus verified active Auth identity, and an `owner_bootstrap_verified` audit event was saved. Rechecked: exactly one matching Owner, no new staff grants and no main partner grant or rank changes. **No second Owner created**.
- Two existing Auth users have matching profiles and wallets, and integrity checks found no missing linked profile/wallet or negative balances.

## GitHub changes delivered
- `supabase/migrations/20261011141000_backend_actor_serialization_support_privacy.sql`
- `supabase/tests/t52_actor_lock_support_privacy.sql`
- `supabase/tests/t53_canonical_phase5_support.sql`
- `scripts/prepare-staging-schema-replay.mjs`
- `scripts/t06-parallel-support-e2e.mjs`
- `tests/backend-actor-lock-contract.test.mjs`
- `tests/staging-schema-replay.test.mjs`
- `tests/t06-parallel-support-contract.test.cjs`
- `.github/workflows/t03-full-stack.yml`
- `.github/workflows/t03-local-schema-replay.yml`

Historical prototype migrations `t36_host_month_preflight`, `t42_support_tickets`, `t42_support_roster_thread_paging`, and `t06_support_concurrency_private_retry` are retained untouched in the repository, but excluded *only from disposable canonical Staging replay*, because later authoritative Phase 5 migration versions replace them and otherwise generate duplicate table errors. This is not a deletion or rewriting of existing data/history.

## Verified GitHub CI at commit 070363a288d7617dba3098ca51972bbbd7b90070
- [Comprehensive staging source QA](https://github.com/QYEM7/TotiChatpro/actions/runs/38142630444) — **SUCCESS**, 167/167 source-level Node tests, 0 failures; syntax, secret audit, Staging web compile and artifact passed.
- [Foundation QA](https://github.com/QYEM7/TotiChatpro/actions/runs/38142630456) — **SUCCESS**.
- [Full-stack isolated integration](https://github.com/QYEM7/TotiChatpro/actions/runs/38142630445) — **SUCCESS**, actual unlinked Docker Supabase Auth/PostgREST/Storage/Postgres tests:
  - 2–3 real disposable GoTrue identities/JWTs, public/private room invite/members/15 seats/mic reservation, session and privacy denial.
  - Binary avatar upload and denial of cross-user changes, genuine local Realtime websocket delivered room INSERT to another signed-in account.
  - Persisted saved music and owner-only queue, unauthorized reads/writes denied; no music streaming claimed.
  - Six parallel identical support creates persisted one ticket/message; 28 parallel replies respected the current **15/min** limit (14 accepted + 14 rejected after initial create); idempotent replay, another user's independent quota and support IDOR/staff elevation denial passed.
  - Local Storage public and private object backup/restore with byte-identical SHA256 validation, denied private outsider access.
  - Database security assertions including actor-lock and hashed retry log passed.
  - Six parallel Owner issuance requests committed once, separate cash reference duplicates rejected, 30/min quota respected, coin/ledger conservation in local-only tests.
  - Local reseller transaction: 500 test coins issued and allocated; 7 credited to test customer, 493 remaining with agent and 0 with Owner; exact conservation and duplicate cash confirmation defense.
  - Host agency registration and transfer required old agency approval then new agency acceptance; concurrent approvals remained idempotent, 30/min quota enforced.
  - Disposable local pg_dump/pg_restore preserved 1,200 synthetic coins and 155 test entitlement diamonds; not a production/offsite restore.
- [Canonical clean-schema replay](https://github.com/QYEM7/TotiChatpro/actions/runs/38142448813) — **SUCCESS**, 53 active source migration files replayed in a never-linked local Postgres; 4 superseded historical source files preserved in GitHub.

## Outstanding backend gates: NOT a 100% deliverable
1. **LiveKit**: deployed Staging `phase2-voice-token` source previously verified to match GitHub and verify JWT, but the Staging-only `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` configuration and actual two-phone/two-network audio/mute/moderation remain unverified. Do not copy production secrets.
2. **Month-end payroll**: `phase5_host_month_preflight` remains read-only with `canZeroDiamonds=false`, `paysSalaries=false` and no agreed payroll commission/target rate snapshot. Do not settle, pay or reset operational diamonds without signed business rules, immutable liabilities and dedicated tests.
3. **Hosted real-account acceptance**: successful disposable local credentials, operations and concurrency DO NOT prove these flows under two distinct authenticated remote Staging users or physical Android devices. Hosted Owner/partner/staff/agent negative tests and controlled, approved financial test funding remain to be performed.
4. **Authentication/configuration**: latest Supabase Auth security advisor had a warning that leaked-password protection is disabled. Need authenticated OAuth/deep-link recovery and email delivery checks. Staging Owner is linked; designated main partner is intentionally **not** assigned until its approved real account is validated.
5. **Remaining backend features**: complete backend entitlement logic and live E2E for VIP levels, medals, games, gifts, real music licensing/playback, notification delivery, moderation and 30-day release reliability remain subject to separate acceptance; do not represent purely visual client screens as connected features.
6. **Deployment and recovery**: no confirmed Cloudflare deployment of the new source, no independently verified production/offsite database AND Storage restore, no signed Android acceptance, no two-device LiveKit audio. All financial/production release gates remain closed.
7. Staging security advisor previously reported 30 informational RLS-no-policy findings (often deliberately private, do not auto-open RLS) and one leaked-password WARN. Recheck with manual security review before release.

## Decision
**Verified progress:** Staging backend schema, user-account ownership, room Realtime, avatar Storage, music metadata, support privacy, agency/recharge request concurrency, clean disposable DB replay and full-stack test suite. **Release decision: NOT READY FOR COMPLETE CLIENT PRODUCTION**, because actual audio infrastructure, hosted two-user/device tests, payroll liability settlement, business approvals, external Auth settings and backups remain unverified.

Never merge to `main`, change production, auto-mint coins or clear diamonds based on a green local test.
