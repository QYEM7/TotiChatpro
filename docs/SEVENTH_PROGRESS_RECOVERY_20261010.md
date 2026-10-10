# TotiChatpro — Seventh implementation report: T49 safe backup/restore drill
**Date:** 2026-10-10 · **Repository:** QYEM7/TotiChatpro · **Branch:** develop/phase-2.

## Current evidence-led percentages
| Indicator | Previous | Current |
|---|---:|---:|
| Directional engineering progress (estimate) | 56% | **57%** |
| Real beta launch readiness | 15% | **15%** |
| 50-task statuses | 3 tested_local / 36 partial / 11 blocked | **unchanged** |
| APK release | denied | **denied, no new build** |

The engineering percentage is a directional judgment, **not a computed completed-feature share** and not permission to release.

## Work implemented and checked this run
1. Added [`scripts/t49-disposable-restore-drill.sh`](../scripts/t49-disposable-restore-drill.sh): the script refuses linked/prod credentials, requires `T49_DISPOSABLE_ONLY=YES`, identifies exactly one local Supabase PostgreSQL container, and uses test-only disposable database objects. It performs a custom-format `pg_dump`, intentionally resets source test wallets and deletes source test entitlement rows, then restores the snapshot into a different isolated local database using `pg_restore`.
2. Restored validation covers **1,200 fake coins** and a matching four-entry ledger, **155 fake unpaid entitlement diamonds**, FK consistency, RLS settings and no broadened direct table-reading privileges. A cleanup trap removes the scratch schema, restore DB and dump. **None of these are real user balances.**
3. Attached the drill as an automated step at the end of existing [T03 isolated full-stack GitHub Actions](../.github/workflows/t03-full-stack.yml), after replay of app migrations, local real Auth/REST/Storage scenarios and SQL role/privacy tests. No backup ZIP/SQL is uploaded as a CI artifact.
4. Added [`tests/t49-disposable-restore-contract.test.cjs`](../tests/t49-disposable-restore-contract.test.cjs) to enforce the unlinked-only input contract and test proof.
5. Strengthened [T48 Android hard release gate](../scripts/t48-apk-readiness-gate.cjs) to require independent verified **Storage object backup and byte restoration** in addition to DB recovery before any APK. Added a ninth false evidence entry to [`docs/release-readiness.json`](release-readiness.json) and negative regression test.
6. Prepared operational [T49 production recovery runbook](T49_DISPOSABLE_RESTORE_AND_PRODUCTION_RUNBOOK_20261010.md), clearly distinguishing the successful **local drill** from the unverified and blocked **production** snapshot+restore task.

## GitHub test evidence
- [**PASS** T49 actual disposable `pg_dump/pg_restore` integration + full Supabase tests](https://github.com/QYEM7/TotiChatpro/actions/runs/38062789341). CI shows source fixture `UPDATE 2` / `DELETE 2`, then restored 1,200/155 and verified RLS/ledger.
- [**PASS** T48 separate Storage backup gate contract](https://github.com/QYEM7/TotiChatpro/actions/runs/38062861141).
- [**PASS** earlier foundation test for T49 script](https://github.com/QYEM7/TotiChatpro/actions/runs/38062764818).
- No Android APK job triggered by development changes.

## Current real infrastructure risks
- Checked live project `sqedsnyvjblvbjbizcay`: **ACTIVE_HEALTHY**, 32 migrations applied; development has **41** migration SQL files, leaving **9 pending**.
- Verified connected Supabase organization is on **Free**. No existing development/staging branches. Under published pricing, Free does not include automatic daily database backups or PITR; no paid plan was activated.
- **Production backup is NOT verified; restoring a local synthetic dataset is not a production restore.**
- Supabase DB backups only cover Storage metadata, not actual files. Real avatar/audio assets need separate permitted offsite backup, hashes, restore and private-bucket checks.
- External providers, LiveKit/TURN and true two-physical-phone voice, salary month-close clearing and finance reconciliation remain unverified. T49 stays **blocked**; T03 stays **partial**.
- No production rows, databases, agency roles, balances, room UI/UX or design altered. No APK built. `release_allowed=false` continues to block manual APK until Owner explicitly approves, >=80% engineering AND beta, 40/50 live verified tasks, DB+Storage recovery and other real deployment proofs.

## Recommended execution after this checkpoint
1. Obtain authorized encrypted offsite **production database + Storage** snapshot and verify restore to a separate destination. No remote dump, backup or production restore can be claimed completed merely by code/CI.
2. Establish hosted staging with an approved cost-free or paid setup (no plan upgrade/branch creation without explicit consent).
3. Validate all nine pending migrations, two genuinely authenticated accounts and complete financial/agency authorization on staging under concurrency.
4. Complete two-device LiveKit/TURN tests, actual month-end diamond obligations and payroll, Android performance/security and end-to-end UI.
5. Only recalculate release readiness with live evidence and run APK build once gating requirements are met.

**Verdict: tested local recovery mechanism only; production recovery/staging unverified; no APK until >=80% and release gate proof.**
