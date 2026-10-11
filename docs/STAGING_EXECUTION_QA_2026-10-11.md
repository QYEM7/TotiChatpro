# TotiChat — Staging-only execution and verification report (2026-10-11)

## Exact scope
- Repository: `QYEM7/TotiChatpro`.
- Development branch: `develop/phase-2` **only**.
- Staging Supabase: `rziaedugbdwefbefcxjt` **only**.
- Production database and `main`: **no modifications performed**.
- Approved UI (2026-10-09): no layout, brand, screen, 15-seat, or illustration modifications.
- Starting inspected commit: `2c012171222f38102c60638dd6b98c6f16f49899`.
- Last tested source commit: `50530525af69535509ba78718dc41dd94af8f1f8`.

## Actual changes
1. `app/phase2-voice-ui.js` — stop local microphone publication **before** a network mute request; disconnect fail-closed if stopping the local track fails. On unsuccessful unmute, stop possibly partially published audio locally or disconnect, then attempt the database mute rollback.
2. `tests/voice-immediate-mute.test.mjs` — four fail-closed microphone regression contracts.
3. `scripts/inspect-google-auth-readiness.mjs` — read-only Google provider inspector explicitly refuses any backend URL other than the approved staging project, even if a legacy production URL has a valid public key.
4. `tests/google-auth-readiness.test.cjs` — remove obsolete assertion requiring legacy production URL; test approved staging and explicit rejection of the production host.
5. `.github/workflows/comprehensive-staging-qa.yml` — CI job runs **every** offline source test, syntax checks browser and script JS, secret audit, locked dependency installation, and registered public Staging web build; checks for incorrect backend or APK/AAB and uploads browser-only short-lived QA artifact.

## Git commits
- `fe6d173724cb69ecd7b6446119ed4bdfdf6268fa` — stop microphone locally before RPC.
- `3a7d6be00656aeae27c1e582cccee667816d2547` — add privacy regression tests.
- `d2d5d1616e2d60b93447517a8d287650333be335` — comprehensive Staging QA workflow.
- `f0f08af41255e23c9c18623fd4323a0d807cff9f` — prevent Auth preflight querying non-Staging backend.
- `2824a59ff8381c9455a1249e9993dc3f30cb571b` — correct outdated Auth test and enforce production denial.
- `2468e63bbd9052505f1159ba861f58b8b33925f7` — build preview using existing registered Staging public configuration (no private environment variables).
- `8aa180f9407892ca15a49f0d45010c3304379414` — stop potential partial microphone publication when unmute fails.
- `50530525af69535509ba78718dc41dd94af8f1f8` — add regression coverage for partial unmute failure.

## Verified automated outcomes
- [GitHub Actions comprehensive Staging QA](https://github.com/QYEM7/TotiChatpro/actions/runs/38141189835): **SUCCESS** at commit `50530525af69535509ba78718dc41dd94af8f1f8`.
- Offline repository tests: **154 passed, 0 failed**, sequential Node test run.
- Script/app JavaScript syntax checks: **passed**.
- Secret audit: **passed**.
- Approved Android-wrapper asset build plus registered STAGING browser compile: **passed** (not an Android APK).
- Browser preview confirms Staging project ID, rejects known production project, `release_allowed=false`, no APK/AAB.
- Browser-only artifact `totichat-comprehensive-staging-web` attached to this run; retention through October 18, 2026.
- [Phase 2 foundation QA](https://github.com/QYEM7/TotiChatpro/actions/runs/38141189849): **SUCCESS** at same source commit.

## Read-only Supabase Staging verification
- Project is ACTIVE_HEALTHY.
- **47 applied Staging migrations** (previous count of 46 is superseded by this verification).
- **36 public tables** and **49 public phase2–phase5 RPCs** were found during this audit.
- `phase2-voice-token` function is deployed and ACTIVE with `verify_jwt=true` but real LiveKit connectivity is NOT proven.
- At final read-only check, room membership, gift events, financial operations, redemptions, direct messages, support tickets, and agency tables all contained **0 operational rows**. Therefore hosted two-user user-journey validation is NOT established.
- Security advisor still reports **leaked-password protection disabled** and 30 INFO notices for RLS tables with no policies (may be intentionally private: inspect grants before changing).
- No staging schema migration, financial write, voice function redeployment, balance adjustment, diamond reset, or salary payout performed in this session.

## Outstanding blockers — NOT client release ready
1. Configure Staging-only `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` via Supabase project secrets, then perform verified two-phone, two-network audio and moderator/mute tests.
2. Authenticate two real isolated test users and conduct real DM/block, room join/leave, gifts, wallet and permission denial workflows without fake stored data or unauthorized coin issuance.
3. Cloudflare build workflow source checks pass, but its `publish-preview` job was **skipped** because the required Cloudflare account variable was not available. The requested live-preview URL is NOT verified as serving this new commit.
4. Review exact monthly salaries, host targets, agent rates, historical accounting, payout authorization, immutable closing journal, appeal windows, and diamond liability handling. Current month preflight remains **read-only** and explicitly disallows payment or reset until approved rules/tests.
5. Enable leaked-password protection in Supabase Auth settings, review sensitive grants, and perform remote authenticated privilege tests.
6. Complete missing remaining screens/flows, performance soak, Android signed install test, real-device QA, backend restore, and release gates. Source tests are not substitutes.
7. The current release gate must remain `release_allowed=false`; do not merge into `main` or distribute as a fully working month-long beta without Owner-approved acceptance evidence.

**Decision:** Staging source quality and media privacy improved and comprehensive CI is green; live services and client delivery are still gated by external credentials, business rules and device-based tests.

## Continued execution — same day, room races and isolated LiveKit events

### Changes committed to development branch
- `app/phase2-rooms.js`: fixed the unjoined-room scrub to iterate **all fifteen seats** and every legacy chat bubble with querySelectorAll. Request coalescing now keys by `roomId` AND local account/session sequence; a slow previous-room response cannot block a fresh room or overwrite the current one. Explicit room joins and private invite joins guard against late authenticated responses after account switch, and increment the generation to supersede a stale restore.
- `tests/room-state-race.test.mjs`: four behavioral tests simulate out-of-order asynchronous room membership replies, stale request lock cleanup, an account switch during a join, and cleanup of all 15 disabled seats plus stale messages.
- `app/phase2-livekit-sdk.mjs`: stale disconnected `TrackSubscribed`, `TrackUnsubscribed`, `Disconnected`, `Reconnecting`, and `Reconnected` events cannot update the new room's UI or attach/remove its audio. A delayed `play()` rejection is scoped to the originating room.
- `tests/livekit-stale-events.test.mjs`: two mocked asynchronous WebRTC event tests with actual deferred connect/disconnect reordering. No simulated audio is shown to real app users.

### New verified CI and staging state
- Verified **source commit**: `d158ea47067656452d860d1ed5bb8be9eb6a3af8`.
- [Comprehensive staging QA run](https://github.com/QYEM7/TotiChatpro/actions/runs/38141936573): **160/160 Node offline tests passed**, zero failures; JS syntax checks, secret audit and the registered public Staging web build all succeeded.
- Browser-only QA artifact `totichat-comprehensive-staging-web`, ID `11702734085`, created in this successful workflow. It is **not** a signed APK or a verified Cloudflare release.
- Earlier [room-source run](https://github.com/QYEM7/TotiChatpro/actions/runs/38141810962) was green at **158/158** after fixing an observed selector regression detected by the new behavioral tests.
- Fetched deployed `phase2-voice-token` Edge Function v1 from Staging and compared its `index.ts` against GitHub `develop/phase-2`: **exact textual match**, `ACTIVE`, `verify_jwt=true`. This does NOT establish configured LiveKit secrets or successful two-phone voice.
- Read-only PostgreSQL permission audit of **45 sensitive phase2–phase5 public RPC functions** found **zero** executable by `anon`. The two privileged global-gift-related functions in this selection are not directly executable by `authenticated` or `anon`.
- Existing **47 applied Staging migrations**, original release gate and financial hold remain unchanged; no SQL writes, balance mutations, diamond reset or payroll activation occurred.

### Still blocked
- Full real authenticated multi-account journeys and voice with two phones/networks, microphone permission, server credentials/TURN, and device background/foreground acceptance.
- Cloudflare workflow `publish-preview` skipped without its Cloudflare account variable; browser site not confirmed updated to the source commit.
- Monthly commission/salary terms and immutable liability-preserving settlement are **not implemented or authorized** for payout and zeroing. Keep `phase5_host_month_preflight` read-only.
- Real hardware, security role-denial, SDK behavior, stress/load/performance and account recovery checks; manual Owner approval remains required for client release.
