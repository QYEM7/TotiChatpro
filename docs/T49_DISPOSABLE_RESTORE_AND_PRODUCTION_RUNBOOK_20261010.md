# T49 · TotiChatpro backup, isolated recovery, and release hold
**Updated:** 2026-10-10 · **Source:** `develop/phase-2`
**Production project:** `sqedsnyvjblvbjbizcay`, organization currently **Supabase Free**.
**Authority:** no production writes, production restore or paid plan activation authorized by this document.

## 1. What is genuinely verified
- GitHub Action [38062789341](https://github.com/QYEM7/TotiChatpro/actions/runs/38062789341) successfully ran `scripts/t49-disposable-restore-drill.sh` in unlinked ephemeral Supabase Docker/PostgreSQL.
- Custom-format local `pg_dump` captured a scratch schema with fake wallets, immutable-like ledger rows, RLS-protected tables and unpaid entitlements.
- The local *source* fixture was intentionally changed (two wallet records reset to zero, two entitlement rows deleted).
- `pg_restore` restored a **separate local PostgreSQL database**, checked 1,200 fictional conserved coins, four ledger entries, 155 unpaid diamond entitlement units, FK integrity and RLS/denial of direct reading.
- The dump was stored only in the ephemeral runner temp directory, never committed to Git or uploaded as an Actions artifact; a cleanup trap removes the scratch schema/database/archive.
- A Node test makes this local drill refuse credentials for linked/prod PostgreSQL and verifies that it cannot silently be mistaken for a production backup.

**This does NOT validate a snapshot of actual TotiChatpro production records, Storage files, users, extension configuration, service credentials or a standalone hosted restore. The T49 production recovery requirement remains BLOCKED.**

## 2. Production limitations verified without mutations
- `sqedsnyvjblvbjbizcay` is active in `eu-central-1` and the parent Supabase organization is on **Free**.
- Production has **32** applied migrations at time of check; development repository contains additional migrations that must not be applied before verified recovery/staging.
- No Supabase preview/development branches existed at time of check.
- Free plan does not provide daily automatic database backups, PITR or Supabase Branching under the current published product terms. Upgrading or creating a billable environment requires separate financial authorization.
- Supabase's database backups do **not** capture actual object bytes from Storage; they capture metadata only. Storage object loss requires a **separate** backup strategy.
- Backups of the database do not automatically replicate Edge Functions, Auth provider settings, API keys, OAuth provider secrets, Realtime settings, payment/cash evidence outside the database, or platform configuration.

Supabase references:
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/migrating-within-supabase/dashboard-restore

## 3. Required production-safety workflow before any migrations
1. Confirm source project ID, production owner permissions, retention requirement, and approved isolated restore destination. Do not treat a console screenshot saying "backup enabled" as a successful restore.
2. Obtain a **full permitted logical database export** using approved secure tools on a trusted machine, with role/schema/data requirements assessed. Database credentials must never be committed, printed in GitHub logs, placed in an unencrypted attachment or exposed to web clients.
3. Record backup creation time, format, source DB engine version, byte length, SHA-256 and encrypted/offsite storage location **without publishing secrets or the dump**. Review data minimization and access controls.
4. Export separately any required Storage object files and metadata, then verify bucket privacy, referential mapping and a sample of actual byte-for-byte restored object hashes in an isolated environment.
5. Restore the database **only into an approved independent temporary database/project**, never overwrite production. Reconcile user profiles, agency ownership, treasury coin issuance, wallet balance vs ledgers, gift/diamond lots, unpaid monthly entitlements, refund/cash records and RLS privileges. Check app login/realtime/storage provider configuration in the destination separately.
6. Log the restore timestamp, the reviewer, critical SQL/row-count checks and SHA-256 evidence in access-controlled operational records. Measure actual RPO/RTO rather than assume they are acceptable. Ensure rollbacks are available.
7. Only after a verified recovery drill, provision persistent isolated staging (with explicit cost approval if necessary), run the nine pending development migrations there, test schema security and all critical real multi-user flows.
8. Keep `release_allowed=false`; do not build any APK until separately verified **>=80% engineering and beta readiness, 40/50 live-verified tasks, Owner approval and all required production and Storage restore evidence**.

## 4. Safe repeatable local test (not production)
The existing `.github/workflows/t03-full-stack.yml` starts temporary unlinked Supabase and runs a disposable custom-format dump/restore with the explicit `T49_DISPOSABLE_ONLY=YES` guard and empty Supabase credentials. There is no call to `supabase link`, `db push`, any production URL or paid API. This is a repeatable verification of the mechanism, **not a production RPO/RTO claim**.

## 5. Acceptance checklist
- [x] Controlled PostgreSQL logical dump and successful restore in independent local database
- [x] Local financial/entitlement consistency, key constraints, RLS and privilege checks
- [x] Production credentials not used; dump not uploaded; local cleanup configured
- [x] Storage object backup proof added as an independent APK release gate
- [ ] Approved full production snapshot exists and encrypted off-site copy can be inspected
- [ ] Successful **production-derived** isolated database restore, reconciled against source
- [ ] Storage object backup and verified actual object-byte restore
- [ ] Hosted staging exists and pending migrations validated with real multi-user identities
- [ ] Demonstrated acceptable recovery point/recovery time and documented responsible operator
- [ ] Signed release acceptance by Owner

**Decision:** T49 remains blocked for production; nothing is deployed; Android packaging stays frozen.
