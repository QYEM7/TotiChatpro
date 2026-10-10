# TotiChatpro — Eleventh engineering and beta readiness report
**Date:** 2026-10-10 · **Branch:** develop/phase-2 · **Production:** unchanged
**Strict owner decision:** NO APK/AAB until BOTH engineering score and real beta readiness reach at least 80% independently, and all release evidence gates pass.

## Verified progress
| Metric | Tenth | Eleventh |
|---|---:|---:|
| Directional engineering estimate | 62% | **63%** |
| Real 30-day beta readiness | 15% | **15%** |
| 50-task ledger | 3 tested_local / 36 partial / 11 blocked | **unchanged** |
| Migrations in dev branch | 41 | **42** |
| Migrations applied in production | 32 | **32** |
| Not applied to production | 9 | **10** |
| Hosted Supabase staging branches | 0 | **0** |
| APK/AAB built this round | 0 | **0** |

**Percentages are directional engineering judgments, NOT measured percentage of user functions passing production QA.**

## Changes actually committed
1. [`supabase/migrations/20261010202000_t35_agency_atomic_actor.sql`](../supabase/migrations/20261010202000_t35_agency_atomic_actor.sql): forward-only update of `phase3.agency_action` itself, with transaction-scoped per-verified-actor advisory locking **before** idempotency lookup and the rolling 30/minute quota. Unlike guarding only the public wrapper, this also covers authorized direct execution of the `phase3` function. Existing Owner authority, main-partner-only host-agency administration, old agent consent, investigation exceptions, agency data, rates and financial rules are preserved, not relaxed. Unapplied in production.
2. [`scripts/t35-parallel-host-transfer-e2e.mjs`](../scripts/t35-parallel-host-transfer-e2e.mjs): genuine 5-account disposable local Supabase GoTrue/PostgREST test. Actors: Owner, old host agent, new host agent, host, unrelated outsider. Explicit loopback-only and secret-denial guard; the local Docker DB only is used to assign fixture Owner and verify durable local rows.
3. [`tests/t35-parallel-host-transfer-contract.test.cjs`](../tests/t35-parallel-host-transfer-contract.test.cjs): ensure SQL protects the private direct function and retains old-agent consent/exception permissions, and the test environment cannot use production credentials.
4. [`.github/workflows/t03-full-stack.yml`](../.github/workflows/t03-full-stack.yml): executes the new contract tests and real network concurrency acceptance **after** established isolated SQL, finance and Storage tests.

## Real integration test proof
- **[PASS full local Supabase Auth/REST/PostgreSQL integration, CI 38066242936](https://github.com/QYEM7/TotiChatpro/actions/runs/38066242936):**
  - Six concurrent **same-key** host agency registrations produced one application in PostgreSQL.
  - An actual disposable Owner account approved two separate host agencies; one initial host membership was accepted.
  - Host requested transfer; state was `pending_old`. New agent could NOT accept prematurely; unrelated user and host themselves could NOT grant old-agent consent.
  - Six concurrent duplicate `approve_old` calls with the same key resulted in one old-agent consent. Six concurrent duplicate `accept_join` calls resulted in exactly one completed membership transfer.
  - Database showed exactly one host agency_members row, correct new agency id, old_approved_by and accepted_by values, and completed transfer status.
  - A different key could not accept the same transfer again.
  - Owner's two approvals plus **28 parallel edits** yielded exactly 30 recorded actions within a minute; the 31st was denied. This supports actor-lock rate-limit correctness.
- **[PASS independent local migration/schema replay, CI 38066093035](https://github.com/QYEM7/TotiChatpro/actions/runs/38066093035)** and **[PASS original local full-stack migration replay, CI 38066093034](https://github.com/QYEM7/TotiChatpro/actions/runs/38066093034)**.
- Previous T30 Owner-to-recharge-agent-to-customer coin conservation CI 38065706706 remains green; approved voice room UI, seats/VIP/animations, agency separation and Owner/main-partner account hierarchy were not altered.
- All GoTrue accounts, registrations, approvals, month state and permissions exercised were local disposable test fixtures, NOT real operator actions.

## What has NOT been completed
- Production remains on **32** applied SQL migrations. **10** development migrations are unapplied and should NOT be pushed before a proven encrypted real production database AND actual Storage-object backup/restore in an independent environment. There is no paid/free persistent staging confirmed.
- Formal customer-service ticket-to-host-agency operational application workflow and hosted notification/SLA still need acceptance (T34 partial).
- Exceptional host-transfer dispute review has existing rollback SQL tests but not a real hosted operator exercise (T35 partial).
- Neither LiveKit/TURN two-device real voice, true monthly immutable payroll entitlements+safe diamond clearing, physical Android battery performance, external cash proof nor a full independent security assessment has passed.
- No APK built. `docs/release-readiness.json` explicitly records `release_allowed=false` and **63% engineering / 15% beta**. Android CI gate still checks both >=80 plus 40/50 live-verified tasks, independent DB and Storage recovery, Owner approval, two-phone audio and more.

## Remaining highest-impact next work
1. Authorized **production-derived offsite backup and independent restore** of PostgreSQL plus actual Storage bytes; document RPO/RTO and redaction/privacy rules.
2. Cost-approved hosted Staging, run all ten pending migrations with real separate Owner, designated partner, generic Super Admin, customer service, host agent, recharge agent and customer identities; keep production unchanged.
3. Actual two-phone LiveKit/TURN/microphone/moderation and Android UI accessibility/performance tests, without removing room decorations or altering the approved look.
4. Complete T36 historical entitlement preservation and monthly payroll rates/targ​ets and safe end-of-month clearing after immutable audited financial settlement (never zero before preserving obligations).

**Verdict: 63% engineering estimate, 15% real beta readiness; no APK and no production database mutation.**
