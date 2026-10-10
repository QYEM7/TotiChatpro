# TotiChatpro T08–T50 Verification Matrix — 2026-10-10

**Scope:** QYEM7/TotiChatpro branch develop/phase-2; independent Supabase sqedsnyvjblvbjbizcay. No code is deployed to production by this audit. The official app brand stays TotiChat.

This file separates demonstrated results from unverified hopes; every task is accounted for in `docs/50-task-verification.json`. Running `node scripts/t50-release-readiness.mjs` prints exact status counts. Running it with `--strict` fails closed until all release gates are verified.

## Verified automated controls
- T01 32 migration fingerprints and local replay.
- T02 Git code recovery references and full commit inventory.
- T03 local Auth signup for two accounts, JWT, RLS, REST/Storage smoke, and secret scan.
- T04/T05 local RLS, Owner/partner and session revocation assertions.
- T06 local 30/minute financial operation budget and idempotency; **not** general denial flood protection.
- T10 live-mode query `phase2Demo=1` can no longer bypass the real Auth adapter inside Android or an explicitly-live web client. Explicit labelled design preview remains only as user-initiated login-page action.

## Missing release evidence
No production/hosted Supabase branch, no verified 30-day beta, no signed AAB and two-phone audio tests, no full PostgreSQL backup-and-restore, no cost authorization, no real data proving transaction settlement or monthly payroll. Features existing only as source or mocked browser tests must not be marked complete.

## Owner-controlled tasks
- T07 GitHub branch protection/rulesets require repository Admin authorization. Evidence issue: https://github.com/QYEM7/TotiChatpro/issues/9
- T08 Vercel preview scope returns 403; reauthorize project/team scope before a real preview.
- T12/T13/T20 require separately owned SMTP, OAuth and LiveKit/TURN provider credentials configured in their service dashboards; never paste credentials in ChatGPT.
- T47 requires two real Android devices and verified signed-in accounts.
- T49 requires actual DB backup/PITR verification on authorized account and restore drill.
- T50 needs signed install build, safeguards, privacy/market compliance and 30 consecutive days of monitored field testing.

## Rules
- Do not merge UI work into main without Owner acceptance.
- No production mock members, coins, rooms, gifted diamonds, music or ratings.
- All test coins/identities only in transaction-rolled-back disposable local database.
- No paid hosted staging branch until user authorizes the quote at final stage.
- A passing code/build CI run is **not** a claim of complete functional production readiness.
