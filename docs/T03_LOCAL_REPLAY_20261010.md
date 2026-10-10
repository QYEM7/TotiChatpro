# T03 — Optional isolated schema replay in GitHub Actions

This workflow executes all 32 canonical Supabase migrations inside LOCAL ephemeral
Docker containers provided by the Supabase CLI on the GitHub Actions runner.

It does not connect to production, install secrets, create a billable hosted
Supabase branch, or copy any user data. It does consume GitHub Actions minutes.

Workflow file: .github/workflows/t03-local-schema-replay.yml

Checks:
- First verifies all 32 applied SQL statements match the checked-in historical fingerprints.
- Uses supabase/setup-cli to start a separate local database in an empty temporary directory.
- Runs supabase db start, db reset, and migration list --local.
- Any failure means the replay is not verified and requires investigation.

This local replay is NOT a full Supabase production database backup, restore/PITR
test, or a two-account LiveKit and wallet end-to-end test. Production is never
linked. A separately provisioned hosted staging instance is still required for
full authenticated and mobile acceptance testing.
