# NUMYAR — Project Command Center
Date: 2026-10-19
Status: Operational coordination baseline (not a release approval)

## Purpose
Use ChatGPT and connected developer tools to coordinate verified work across NUMYAR projects. Project 01, **TotiChat**, is the only active release priority. Other projects stay parked unless the owner changes priority. This document records evidence, acceptance gates, operating rules, and next work; it does not itself establish runtime readiness.

## Authorized scope and source of truth
- Source repository: `QYEM7/TotiChatpro`
- Active development branch: `rebuild/flutter-v1`
- New mobile client: `flutter_app/` (Flutter/Dart)
- Approved visual reference: `mrbalmain11-star/-`, `main`; visual reference only, never a trusted backend or mock-data source
- Test backend: Supabase **Staging** `rziaedugbdwefbefcxjt` only
- No modifications to GitHub `main`, production databases, production services, or deprecated clients
- Do not treat historical Vercel previews as a live acceptance test
- No invented users, balances, transactions, ads, banners, listeners, or readiness percentages
- No APK/AAB, external deployment, remote migrations, or production changes through this command-center documentation task

## Read-only connection/evidence audit — 2026-10-19

| System | Evidence | Meaning |
| --- | --- | --- |
| GitHub | `QYEM7/TotiChatpro` accessible; active branch `rebuild/flutter-v1` present | Repository access and active development source confirmed |
| GitHub Actions | [Run 39188427349](https://github.com/QYEM7/TotiChatpro/actions/runs/39188427349): `Analyze and test Flutter (no APK)` completed **success** | Flutter dependency resolution, static analysis, unit/widget tests and Android source/OAuth intent preparation passed; not device acceptance |
| Supabase | `TotiChat Staging` status `ACTIVE_HEALTHY` | Project is reachable and healthy at the service metadata level |
| Supabase | `phase2-voice-token`, `phase2-voice-moderate` ACTIVE and JWT verification enabled | Deployed functions exist; LiveKit secrets/token issuance/audio transport unverified |
| Supabase | Public rooms, members, profiles, messages, wallets, ledger, gifts, banners, DM and related tables present; public table RLS flags enabled | Data contracts exist; specific RLS checks and real-user authorization must still be demonstrated |
| Vercel | Fourteen search-matched TotiChat projects returned | Historical/test deployments require later inventory and cleanup review; nothing has been disabled, changed or validated as the canonical preview |
| Supabase security advisors | 55 `rls_enabled_no_policy` INFO findings, 1 `auth_leaked_password_protection` WARN | No-policy tables may be intentionally inaccessible; verify per intended use. Password warning may be irrelevant if only Google OAuth is enabled; review provider settings, not an assumed vulnerability |
| Supabase performance advisors | 3 unindexed FK INFO and 90 unused-index INFO findings | Triage based on real workloads. Do **not** remove indexes solely because a low-traffic staging database reports them unused |

Advisory references:
- [RLS enabled without a policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Leaked password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [Unindexed foreign keys](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
- [Unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)

## Project 01 release gates

Statuses below refer to **end-to-end acceptance evidence**, not source availability.

| Gate | Acceptance criteria | Status | Next test/evidence |
| --- | --- | --- | --- |
| G0 — contracts/source | CI passes, necessary services and RLS are checked, approved Flutter vs visual-reference parity verified | PARTIAL | Inspect all critical screen paths and document API/visual deltas |
| G1 — authentication | Google OAuth login, logout, redirect, session restore on real Android using Staging | NOT VERIFIED | Test callback and session persistence on approved test APK |
| G2 — rooms/seats | Two distinct accounts create/join/leave; 15 seats; minimize/restore; server authorization | NOT VERIFIED | Paired-device room lifecycle test |
| G3 — voice | Two physical phones pass join/listen/publish/mute/rejoin; no echo; server moderation revokes publish | NOT VERIFIED | Check Staging LiveKit configuration then instrument two-phone QA |
| G4 — messages/privacy | Room text + 1:1 text DM delivery and authorization denial | NOT VERIFIED | Two-account send/receive plus unauthorized read tests |
| G5 — gifts/wallet | Idempotent settle, no negative balances, expected catalog unit price, truthful room notice and gift counters | NOT VERIFIED | Authorized controlled Staging test and reconciliation |
| G6 — visual/admin/release | Approved visual comparison, correct limited admin entry, permissions, owner acceptance | NOT VERIFIED | Screenshot comparisons, role matrix QA and sign-off |

**Do not report 90% readiness** based on a successful CI run or code presence. Refer to `docs/BETA_RELEASE_READINESS_EVIDENCE_20261019.md` for detailed proof and blockers.

## Working board (ordered)
| Priority | Work package | Required outcome | Safety constraint |
| --- | --- | --- | --- |
| P0 | Android Google OAuth + Staging test environment | Real test login/return/session trace | No production credentials; don't build in this coordination step |
| P0 | Real LiveKit audio and moderator revocation | Two-device evidence and server-side kill/revocation semantics | Do not replace stable SDK/audio infrastructure without evidence |
| P0 | Real room/seat and text QA | Two-account room lifecycle and privacy proof | Never seed fake users or messages |
| P0 | Gift/wallet transactional test | Single settlement per request and consistent receipts, display and counters | Staging-only controlled operations and rollback plans |
| P1 | Flutter visual fidelity | Screen-by-screen comparison against approved reference, including seats, room decor, gifts and navigation | No old frontend reuse and no unapproved redesign |
| P1 | Admin minimal permissions | Profile-only entry + server-enforced role controls | Owner-protected; no permission escalation |
| P1 | Security-advisor triage | Classify each relevant advisory as intended, actionable or deferred with rationale | No mass policy/index edits |
| P2 | Vercel preview cleanup inventory | Canonical preview named; redundant previews reviewed before disabling | No deletion/disabling without owner authorization |
| P2 | Park non-essential product features | Beta remains focused | No scope creep |

## Developer tool responsibilities
- GitHub: source, feature branches, CI evidence, issues, pull requests, versioned documentation.
- Supabase: Staging-only schema/RLS/RPC/service introspection, controlled backend QA only with scoped approval.
- Figma/Canva: design artifacts and approved visual references; do not quietly redefine accepted UI.
- Vercel: inspection and separate preview deployments only when deployment is authorized; never promote to production by default.
- ChatGPT: coordinate evidence, identify dependencies, update this work board, and clearly distinguish observed results, code-level assumptions, and blocked tests.

## Definition of a complete task
1. Scope and acceptance criterion written.
2. Exact files, project and branch stated.
3. Relevant test executed, or explicitly marked NOT VERIFIED.
4. Evidence link/artifact recorded.
5. Rollback and privacy/security impact reviewed for stateful changes.
6. User approval obtained for release/deployment or consequential operation.

## Next checkpoint
Prepare the device-test matrix and visual screen checklist from the active Flutter client and approved visual reference, then run only the validations actually possible. Do not build or ship a production app as a substitute for missing real-device evidence.

## 2026-10-19 — Staging debug APK build attempt

Owner previously authorized a **test-only** Android APK on Supabase Staging. The dedicated workflow `/.github/workflows/flutter-beta-apk-staging.yml` was introduced on the active branch at [commit `639ce3b`](https://github.com/QYEM7/TotiChatpro/commit/639ce3bb4a78db8c9ac9df1cc41b261f6d913704) and configured to also trigger for Flutter source changes at [commit `a28c4b1`](https://github.com/QYEM7/TotiChatpro/commit/a28c4b1ccb13bf2b74dbb13265a0c2d68e23d317). It runs source analysis/tests, generates Android host source, checks the Staging URL, package `com.totichat.beta`, OAuth callback and microphone/network permissions, then **attempts** `flutter build apk --debug`, verifies ZIP integrity, and uploads the test APK as a 7-day artifact if all steps succeed.

- [Dedicated Android workflow](https://github.com/QYEM7/TotiChatpro/actions/workflows/flutter-beta-apk-staging.yml)
- **Build status: UNVERIFIED** from the currently available GitHub tool: the workflow file/commit are confirmed, but no build run result, APK artifact, download, installation or device test has been independently confirmed.
- Do not confuse the historical green *source-only* CI with a successful APK build.
- Debug APKs are not production-signed or accepted releases. Never deploy them to a public store or production project.
- If the build succeeds, log its GitHub run ID, SHA256 and Git commit, then perform G1–G6 device acceptance. If it fails, read the exact failed GitHub Actions job logs before modifying code.
