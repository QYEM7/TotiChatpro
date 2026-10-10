# TotiChatpro — Fifth implementation report: no APK until >=80%
**Date:** 2026-10-10 (Asia/Baghdad). **Repo:** QYEM7/TotiChatpro. **Branch:** develop/phase-2.

## Readiness (conservative, evidence-based estimates)
| Metric | Previous report | Current |
|---|---:|---:|
| Engineering progress | 53% | **54%** |
| Real 30-day beta readiness | 15% | **15%** |
| Evidence status in 50-task ledger | 3 locally tested / 36 partial / 11 blocked | **unchanged** |

Progress estimates are judgmental, not actual percentage of working controls. No completed hardware integration, signed release or real customer uptake may be inferred.

## Critical user constraint implemented first: NO APK before independently verified 80%
1. [Android CI workflow](../.github/workflows/phase2-android-beta.yml) no longer has a push event; Android is **manual only**, not triggered by app/source changes.
2. Before installing Java, Gradle, Capacitor or assembling any APK, [scripts/t48-apk-readiness-gate.cjs](../scripts/t48-apk-readiness-gate.cjs) must approve.
3. The gate defaults to deny and requires **all**: explicit Owner `APPROVED` input; `release_allowed=true`; both engineering and real beta score >=80; **at least 40 of 50 tasks independently marked `verified_live`** with evidence; signed-off reviewer/date; eight public, reviewable proofs including production backup and successful restore, hosted staging, two separate authenticated users, two physical phones, real voice/moderation, financial month-end conservation, agency authorization, full mobile regression.
4. [docs/release-readiness.json](release-readiness.json) is presently **release_allowed=false**, engineering 54, beta 15, and all eight live rollout criteria false.
5. [T48 release gate CI](https://github.com/QYEM7/TotiChatpro/actions/runs/38061274547) succeeds precisely because the negative test confirms APK compilation is **blocked** today. No new Android APK build was triggered by any subsequent push after the workflow change.
6. Re-running old historical build workflow jobs or modifying release-gate code is outside this gate; only the current development workflow is controlled.

## New T42 actual implementation
- Owner can grant/revoke separate support-agent rights and now see their **live staff directory**, including revoked accounts, in the account support sheet, without seeing an invented list.
- Created private, Owner-only staff roster RPC: `phase5_support_staff_list`. Signed-in, active session verified via `phase3.actor`; `phase3.is_owner` is rechecked on the backend, and direct table access is never granted.
- Added `phase5_support_thread_page` for the **newest 30 real messages** and older pages rather than returning only the original 500 messages. IDOR/tenant access checks remain on the server: creator or an explicitly authorized support handler.
- All three types of operation are separate: support authority does **not** open host agencies, approve recharge agencies or grant wallet/currency powers. In particular, it does not change the designated main partner Super Admin role.
- New forward-only migration `20261010183000_t42_support_roster_thread_paging.sql` and rollback-only fixture `supabase/tests/t42_support_roster_paging.sql`.
- Browser fixture checks grant/revoke list, normal customer tickets, 45 extra historical messages, older-page navigation, account cleanup and mobile width.
- Did **not** alter approved room design, VIP seats, animations or `app/index.html`.

## Completed test evidence
- [Disposable full-stack Supabase PostgreSQL/Auth/REST CI](https://github.com/QYEM7/TotiChatpro/actions/runs/38061109118) — **PASS**, includes new roster/page 66-message private SQL fixture in rollback, staff grant/revoke, Owner-only list, outside account denied.
- [Isolated T42 Chromium UI](https://github.com/QYEM7/TotiChatpro/actions/runs/38061220445) — **PASS** after updating browser contract fixtures for real API shape. This is *not* hosted real-user E2E.
- [Foundation Node/security contract](https://github.com/QYEM7/TotiChatpro/actions/runs/38061220423) — **PASS** after fixing an overescaped test fixture newline assertion.
- [Full Royal browser regression](https://github.com/QYEM7/TotiChatpro/actions/runs/38061057688) — **PASS** for latest tested UI content.
- [Latest T48 foundation CI](https://github.com/QYEM7/TotiChatpro/actions/runs/38061274547) — **PASS**, release remains blocked.

Older failing CI runs were investigated and corrected; current passing links above supersede them.

## Production and deployment safety
- Supabase `sqedsnyvjblvbjbizcay` is `ACTIVE_HEALTHY` (read-only API evidence).
- Supabase development branches: **none** (verified).
- Applied production migrations: **32**. Repo migrations: **38**. **Six pending**, including new T42 support SQL. NONE of these were applied on production.
- There is NO evidenced independently restorable production database snapshot/PITR and NO hosted staging. No real Owner support staff, customers, wallets or rooms were modified by this work.
- The old APK build 38059820356 predates the requested freeze; **no APK build after the freeze** is counted as executed.

## Blocking items before any APK (in order)
1. T49 backup/PITR with independently demonstrated restore; T03 persistent staging without production database risk (cost requires explicit acceptance if a paid branch/project is necessary).
2. T01 safely replay and review 6 pending migration versions against a real hosted staging database and verify no permission/financial regressions.
3. T12/T13/T15 real SMTP, provider secrets, 2 real accounts, session/MFA; T20/T21 hosted LiveKit/TURN and 2-device voice/seat/moderation checks.
4. T36 complete revenue/payroll policy, immutable monthly entitlements, tested 30%-diamond conversion, legal/month-end clearing without loss; other economy/agency integrity acceptance.
5. T42 customer service notifications and SLA, all screen buttons and UX, real device performance, store and multiplayer game validation.
6. T46/T47 independent adversarial security tests, actual hardware regressions and Owner sign-off.
7. Recalculate the conservative task evidence scores. **Do not build** until the release gate verifies >=80 engineering AND >=80 real beta, 40/50 live task proof and Owner approval.

**Current release decision: DENIED. No APK was built during the fifth report work.**
