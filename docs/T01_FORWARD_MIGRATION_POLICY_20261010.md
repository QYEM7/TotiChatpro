# T01 historical integrity and safe forward migrations

The 32 SQL files already applied in Supabase production sqedsnyvjblvbjbizcay
remain immutable: filename, version and recorded SQL MD5 must remain identical.

From now on, a new migration can be added with a unique **later timestamp**
without changing the production-history fingerprints. GitHub CI replays all
historical and pending migrations in an unlinked local DB. New SQL is **not**
automatically applied to production or marked as already applied in Supabase.

Before any future production migration:
1. Obtain a VERIFIED full DB snapshot/PITR recovery point (T49).
2. Replay all migrations in local CI and isolated hosted staging.
3. Perform SQL authorization and financial conservation tests.
4. Check the migration list against production and explicitly approve rollout.
5. Promote code and schema by PR under protected branch rules (T07).

The old test incorrectly assumed there could never be a 33rd migration.
This change fixes that false constraint while still guarding all 32 applied
SQL versions byte-for-byte. No production DB writes or data changes.
