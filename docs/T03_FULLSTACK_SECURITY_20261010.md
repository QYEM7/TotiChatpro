# T03 — Secret audit and isolated real Auth/REST smoke (2026-10-10)

Scope: QYEM7/TotiChatpro `develop/phase-2`, NOT legacy TotiChat.
CI provisions a disposable, unlinked Supabase local stack in a GitHub Actions runner.
Unlike migration-only tests, this verifies real local Auth, user creation,
token-authenticated `profiles` reads, anonymous denial, REST banner
listing and Storage service response.

## Controls
- `scripts/t03-secret-audit.mjs` scans tracked files, blocks accidentally
  tracked private environment files, keystores and high-confidence static
  token patterns; reports **filenames and rule names only**, never raw tokens.
- `tests/t03-secret-audit.test.mjs` exercises positive and negative detection.
- No production Supabase credentials are provided to the CI workflow.
- `supabase init`, `supabase start` and all migrations run in a temporary,
  unlinked runner directory. No production link or remote push/reset.
- The local Auth smoke creates 2 confirmed test accounts in disposable Auth,
  obtains genuine JWT sessions and checks actual RLS profile isolation.
  These accounts are not production data. Passwords/JWTs stay in memory.
- Supabase CLI output is suppressed to prevent local credential disclosure.
- No frontend UI or production database changes.

## Important limitations
- GitHub tracked-file scanning does not inspect GitHub secret storage or all
  deleted historical commits; it cannot establish that no secret was EVER
  exposed, and historical token revocation may still be necessary.
- This ephemeral local environment is NOT hosted Supabase staging: it is
  short-lived, developer-grade, without public TLS or production hardening.
- LiveKit/TURN, OAuth providers, SMTP deliverability, real wallet credit,
  physical Android devices and complete database backup/restore are not
  verified by the local smoke. They remain separate operational work.
- Creating a **persistent hosted Supabase preview branch** may incur billable
  compute, storage and egress. Requires explicit user cost authorization.
  Do not create branches without that authorization.

Reference: https://supabase.com/docs/guides/local-development/cli-workflows
