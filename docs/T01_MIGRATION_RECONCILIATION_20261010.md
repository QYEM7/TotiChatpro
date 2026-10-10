# T01 — Supabase TotiChatpro Migration Reconciliation (2026-10-10)

## Scope
- GitHub: QYEM7/TotiChatpro, source branch `develop/phase-2`.
- Supabase: `sqedsnyvjblvbjbizcay` (TotiChatpro, not legacy TotiChat).
- Source baseline commit: `598d92d1bd42d51e90c59adfa12bea2e59df65f4`.
- Immutable code checkpoint: `backup/t01-phase2-before-db-sync-598d92d`.

## Verified findings
- Supabase recorded 32 applied migration versions; GitHub contained 29 SQL files, each with a different timestamp/version from Supabase.
- 27 of the 29 prior file bodies were byte-for-byte identical to the applied SQL statements.
- Two historical differences were found: `phase4_agencies` and `phase4_admin_reports`. The canonical filenames below contain the SQL **as recorded at application time**. The original GitHub variants remain in the backup branch.
- The three missing applied statements were: `phase4_treasury_recharge` (`20261010030849`), `phase4_recharge_scope` (`20261010031010`), and `phase4_recharge_limits` (`20261010031301`).
- All 32 SQL files are now named by **the version recorded by Supabase** rather than a separately assigned timestamp.
- The read-only `node --test tests/t01-migration-history.test.cjs` ensures exact filename and MD5 integrity for all 32 applied statements. MD5 is only a drift-detection checksum, not proof of authorship.

## Safety and restoration
- No SQL was executed against production during this Git-only reconciliation; no user data was altered, imported or deleted.
- The backup branch preserves the previous frontend, server source, and all 29 original migration filenames/bodies.
- The full database contents are **not** backed up by this checkpoint. Before any future destructive DB operation, obtain an actual database backup/PITR snapshot using the approved Supabase database backup process.
- Do not re-run the 32 migrations against existing production. First validate migration history and permissions on a separate test database, then review `supabase migration list` using the connected project with a supported Supabase CLI.
- Neither UI files nor app design were changed for this task.
- Proposed integration: PR to `develop/phase-2`; do not merge into `main` automatically.

## Follow-ups
- End-to-end replay on a disposable database and signed-off migration-history check are required before declaring the project fully release ready.
- Review the two historical SQL divergences when developing further agency/report migrations; never silently edit previously applied migrations.
