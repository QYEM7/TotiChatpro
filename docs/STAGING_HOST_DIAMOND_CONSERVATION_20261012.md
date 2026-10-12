# TotiChat — host month earned / redeemed / remaining conservation (2026-10-12)

**Environment:** Supabase Staging project `rziaedugbdwefbefcxjt`; production/main remain unchanged.
**Applied migration:** `20261012120127_staging_host_month_diamond_conservation_readonly_v1`.
**API:** `public.phase7_host_month_diamond_conservation(p_month date, p_offset integer default 0, p_limit integer default 30)`.
**Private DB implementation:** `phase3.host_month_diamond_conservation` with session-verified Owner or **designated main partner** authorization. Generic Super Admin, DB, customer service, recharge agents and ordinary users cannot read.

## How it works
- A *closed UTC calendar month* is required; offset must be 0–100,000, page size 1–50.
- Historical earned diamonds = SUM of the original `gift_events.amount` for actual host agency gift events within the month (uses historical `gift_events.agency_id`, never a user's present agency).
- Redeemed-to-date diamonds = the immutable `diamond_redemption_allocations.amount` recorded against the corresponding gift lots. A redemption may include lots from multiple months. It is never correct to infer monthly diamond consumption from `diamond_redemptions.diamonds_amount` without consulting its lot allocations.
- Unredeemed diamonds **NOW** = SUM of `diamond_lots.remaining` corresponding to those events. The API explicitly does **not** claim this is the historical closing balance on the last day of the requested month.
- Per-host/agency summary lists IDs, real gift count, earned, redeemed-to-date, and remaining-now, with deterministic pagination. It does not invent names, salary, rate tiers, or agency target progress.
- The audit detects missing/wrong-owner/incorrect-value/incorrect-type diamond lots; lot balance not conserved (amount != redeemed + remaining); allocations referring to a redemption from another user; redemption totals not matching all their cross-month lot allocations; fixed/lucky source splits inconsistent; and each relevant host's *overall* wallet diamond balance mismatching all their lots (including other months/non-agency gifts).
- The existing `phase6_host_month_evidence_integrity` is called independently to compare any immutable monthly snapshot and flag unassigned gifts.
- The response always says `isReadOnly=true`, `canApprovePayroll=false`, `canPaySalaries=false`, `canZeroDiamonds=false`, `hasPayrollRates=false`, and `isReadyForFinalClose=false`.

## Safety / truth-in-reporting
- Issued, redeemed and remaining numbers are **not** payout amounts, and no bonus salary or agent commission is inferred.
- A diamond redemption at 30% generates coins for the host but **must not erase that month's originally earned host diamonds** from the eventual agency target/payment calculations. Avoid crediting the same realized value twice in different financial obligations once actual business payout policy is approved.
- No funds are credited, debited, paid, converted or reset by this API.
- Staging currently has zero actual gift events, diamond lots, redemptions, agency payroll or monthly snapshots. Do not show fabricated stats in an app dashboard.

## QA plan / observed before latest CI outcome
- SQL function compiled inside a transaction and was rolled back before its versioned migration was deployed. Migration and GitHub copy match.
- Anonymous Execute is denied on the private and public functions, authenticated role has invocation privilege but private function applies Owner/partner identity verification.
- Added `tests/staging-monthly-diamond-conservation.test.mjs` to the existing CI suite.
- Extended rolled-back `supabase/tests/t67_host_month_real_gift_integrity.sql` to create a real local gift + monthly snapshot, invoke an authentic 30% server-quoted diamond redemption, ensure original earned diamonds remain 10 while redeemed becomes 10 and current remaining 0; deny host access to finance audit; deliberately tamper gift amount and delete a lot in another month to require discrepancy detection. **Treat as pending until the latest T03 full-stack job succeeds.**

## Production blockers
- Staging Owner/partner and customer denied-access checks using **legitimately signed in hosted sessions**, actual funded Staging recharge test cases, complete salary and commission formulas approved and versioned, immutable payroll obligations and payout settlement before monthly diamond reset, genuine independent backup restore and two-device LiveKit voice.
- This phase is intentionally only authenticated **read-only reconciliation**. Zeroing active diamond balances from monthly accounting must not start until obligations and all cross-month and redeemed allocations reconcile.
