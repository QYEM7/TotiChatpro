# TotiChat T49 encrypted export staging helper (2026-10-11)

The new scripts/t49-secure-db-export.sh is an OPT-IN, encrypted, logical PostgreSQL backup helper for the correct Supabase project sqedsnyvjblvbjbizcay only. It requires explicit per-run approval, the exact direct database host/port/user/name, PGSSLMODE verify-full, a trusted PostgreSQL authentication source, an age X25519 public encryption recipient, and a private absolute output directory outside the repository.

It streams pg_dump directly to age; no plaintext dump is created on disk. It emits an encrypted local file plus SHA-256 manifest, but does not upload anything or start any paid service. CI tests only its failure modes and bash syntax; CI NEVER runs it with real production credentials.

Actual export has NOT been performed yet: connection secrets, trusted operator workspace, age recipient and confidential backup destination are not accessible in this chat and must never be written to GitHub or the conversation. Do not consider the production DB backed up.

An encrypted dump is NOT verified recovery. T49 remains blocked until the actual export is decrypted and restored to an independent test DB, finance/ledger/RLS records compared, separate Storage object bytes restored and checked, and recovery reviewer/timings recorded. Auth provider and Edge secrets are not backed up by pg_dump.

Do not run in GitHub Actions or with bash -x. No APK/AAB, no SQL production write, no designs changed, no paid services. Release remains disabled with both score thresholds, 40/50 live tasks, all nine proof flags and explicit Owner permission.
