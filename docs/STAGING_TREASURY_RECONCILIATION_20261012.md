# TotiChat — Treasury and agent recharge reconciliation (Staging, 12 Oct 2026)

## Changes actually applied
- **Staging project:** `rziaedugbdwefbefcxjt` only. **Production and main untouched**.
- **Applied Supabase migration:** `20261012091412_staging_treasury_integrity_preflight_readonly_v1`.
- **Backend interface:** `POST /rest/v1/rpc/phase6_treasury_integrity_preflight` with the normal authenticated Supabase session.
- **Authorization:** Owner or the *explicitly designated* main partner only, checked inside `phase3.treasury_integrity_preflight` against `phase3.system_authority`. Generic Super Admin / DB / recharge agent / consumer users do not inherit this permission.
- **No writes:** the RPC checks coin issuance, Owner/agent treasury accounts, wallet coin ledgers and issuance/agent transfers/approved recharge operations. It does **not** issue coins, transfer balances, settle salaries, expire diamonds, reset a month, adjust agent wallets, or alter the approved UI.
- **Result flags:** `isReadOnly: true`, `isReadyForMoneyMovement: false`, `canIssueCoins: false`, `canZeroDiamonds: false`, `paysSalaries: false`.
- The `isReadyForMoneyMovement` response field communicates QA status **only**. The existing `phase4_recharge_action` endpoint still exists and should NOT be treated as technically disabled or as independently audited merely because the new endpoint is safe.

## Read-only checks
1. `phase3.coin_issuance.issued` should equal minus the sum of `phase3.issuance_ledger.amount`. Flag orphan issuance entries.
2. Each account in `phase3.treasury_accounts` should have current coins equal to its entire treasury ledger net; flag orphan ledger entries.
3. Each user coin wallet should equal its own `public.wallet_ledger` total for currency `coins`. No corrections are applied; any mismatch is an incident.
4. Every completed Owner `issue` operation should have **one positive treasury line** and **one negative issuance line** against the same `financial_operations.id`.
5. Every completed agency `allocate` operation should have exactly two treasury lines, one Owner debit and one correctly-owned recharge agency credit, with total net zero.
6. Every completed agent `approve` should correspond to a completed recharge request, one agent treasury debit and one customer wallet ledger credit, including recorded reward coins.

## Independently observed after applying
- Supabase migration history includes **78 entries**, new exact version **20261012091412**.
- `public.phase6_treasury_integrity_preflight()` is SECURITY INVOKER; private function is SECURITY DEFINER, explicit `search_path=''` and Owner/partner gate.
- Both functions reject `anon` EXECUTE, and only `authenticated` has EXECUTE grant (actual Owner identity is checked at runtime).
- Attempting RPC without a real authenticated user in SQL returned **42501 Verified account required** (expected denial).
- At inspection: issued coins 0; issuance ledger 0; treasury coins 0; treasury ledger 0; all user wallet coins 0; wallet coin ledger 0; completed recharge operations 0.
- Green GitHub Actions: **Staging treasury reconciliation contract QA** (new tests + previous finance/host snapshots).

**IMPORTANT:** Zero entries are an honest empty Staging data state, *not proof of a real recharge, agent cash receipt, concurrency replay, salary calculation, or cross-ledger transfer*. Do NOT create fake public activity just to fill dashboard numbers.

## Controlled financial QA still required
- With legitimately owned **Staging-only** accounts, verify Owner and specifically designated main partner may read the audit; DB, generic Super Admin, CS, agent and consumer accounts get HTTP 403 / PostgreSQL 42501. Do not reuse production secrets or impersonate principals by SQL.
- Before real customer cash, run audited staged reconciliation for **each** intended flow: Owner issues with unique cash reference; Owner allocates to an authorized recharge agency; customer requests; agent verifies out-of-band cash and approves. Confirm exactly balanced immutable ledger entries and idempotent retries, race conditions, balance limits and duplicate-cash-reference prevention.
- Require explicit test transaction records from real Staging test users, never fictional reports or synthesized UI balances.
- Manual and formal business approval is required for host salary/agency commission tiers; existing immutable monthly diamond accrual is evidence only. It does not settle salary or reset operational diamonds.
- Do not disable RLS or create broad read policies to remove security-info warnings.
- Postgres security advisor still reports leaked-password-protection warning and 51 RLS-no-direct-policy INFO observations; review security context individually.
- Restore/backup drill, real voice, Android OAuth/password reset and actual dual-device tests remain separate launch gates.

## Operational decision
**GO for read-only financial reconciliation in Staging. NO-GO for production cash, salary payout, diamond clearing, production role adjustments or auto-financial close.**

PR for the isolated Backend branch stays **DRAFT** until legitimate authenticated E2E and independent finance review.
