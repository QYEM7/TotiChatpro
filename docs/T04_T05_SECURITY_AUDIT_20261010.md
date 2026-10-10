# T04 and T05 read-only security audit — 2026-10-10

Scope: TotiChatpro project sqedsnyvjblvbjbizcay; **production SELECT only**.

## Verified metadata
- 31 public + 14 phase3 tables (45 total), all RLS enabled.
- No anonymous-executable SECURITY DEFINER RPCs in public/phase3 catalog.
- Private phase3 tables not directly exposed to anon/authenticated.
- Protected finance and agency tables have no direct client DML grants.
- Wallet and ledger own-account SELECT policies use auth.uid.
- Security Advisor: 24 informational rls_enabled_no_policy warnings, mainly RPC-only tables. Do not add permissive policies blindly.
- Owner authority configuration exists but auth.users is empty; owner account has NOT been bootstrapped or verified.
- Regular Super Admin differs from explicitly designated main partner.

## CI guards
- supabase/tests/t04_security_invariants.sql: RLS, grants, SECURITY DEFINER search_path and finance ledger ownership checks, on disposable Docker DB.
- Re-run supabase/tests/phase3_admin.sql and phase4_sessions.sql using rollback fixtures, to test owner/partner role boundaries and banned/deleted/revoked sessions.
- This is NOT a production penetration test, nor approval for arbitrary security changes or open RLS policies.

## Residual blockers
- T05 actual Owner account cannot be verified until the owner registers and enables MFA.
- Full multi-user hostile-token E2E and financial permission checks require isolated hosted staging after approval.
- T06 must verify rate limiting covers denied requests, not only successfully logged transactions.
- T07 must activate branch protection/rulesets, currently unprotected.

Advisor reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
