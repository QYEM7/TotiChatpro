# TotiChat Backend — actual staging / disposable QA evidence
Date: 12 October 2026
Source PR: #29, branch feature/staging-finance-reconciliation-20261012
Staging backend ONLY: rziaedugbdwefbefcxjt
NEVER merge to production or main until signed acceptance.

## Proven by actual CI, not estimated
- GitHub run 38240798781: PASS unlinked local Supabase schema replay after fixing semicolon-terminated function migration files (GitHub migrations 20261012095808 and 20261012095924).
- GitHub run 38240798700: PASS isolated LOCAL real GoTrue/PostgREST/PostgreSQL full-stack integration. Auth, RLS, Storage, support concurrency, admin security, transfer and finance tests passed.
- Real LOCAL issuance: 6 concurrent same-key requests = one issuance; four distinct-key same external cash reference = one issuance and three rejections; 46 simulated coin units exactly balanced across Owner treasury and issuance ledger. Ordinary user denied.
- Real LOCAL reseller: Owner approved one recharge agent, minted/allocated 500 temporary coins; confirmed 7 coin customer recharge, agent retained 493; duplicate and same-reference case/space replay blocked; customer wallet and ledgers conserved; ordinary user could not call Owner audit RPC.
- Real LOCAL agencies: Owner-only creation and verified approval, consent-based host transfer, duplicate/parallel approvals and 30-per-minute rate limiting.
- Real LOCAL backups: PostgreSQL pg_dump/pg_restore into *another disposable database*, balances and host accrual figures conserved. Storage object backup/restore checks preserved identical bytes; does not constitute disaster recovery for production.
- GitHub run 38234003195 and 38240793530: PASS Owner/private treasury + host evidence + normalized receipt contract suites.
- Staging actual SQL introspection after deployment showed: two finance audit RPCs with anon EXECUTE denied; private Owner/partner role gates; recorded month snapshot trigger exists; receipts have case/trim normalized unique completed index and nonblank check.
- Staging current business data: 0 host month snapshots, 0 settled salaries, 0 recharge operations, 0 issued coins, 0 wallet coins, 0 public gift events. This is legitimate absence of real transactions, not fake or seeded activity.

## New high-confidence monthly evidence test — latest CI status pending
- `supabase/tests/t67_host_month_real_gift_integrity.sql` uses *ONLY* rollback-only disposable local fixtures.
- Tests a real server gift + corresponding issued diamond lot + historical agency, closes an actual monthly evidence snapshot, detects an intentionally tampered gift, refuses a second incomplete snapshot with a missing lot, and asserts no cross-month contamination.
- Latest GitHub full-stack run must be checked before calling T67 passed. Do not claim it is successful until the job outcome and PASS T67 log appear.

## Operational NO-GO
- Financial business rules needed: exact agency targets, host salary tiers, commission percentages, consent and dispute exceptions, reconciliation of earned-vs-redeemed diamonds, months and close handling, payout recipient validation, automatic reset only after immutable obligations exist. No source edits to settle or reset hosted funds have been made.
- Voice: Edge Functions phase2-voice-token and phase2-voice-moderate are active with JWT verification and server authorization. LiveKit project-specific secrets, two-physical-device audio and actual SFU kick/mute outcomes are not established by CI.
- OAuth/password recovery, actual native Android builds and push permissions still require hosted test accounts/physical devices.
- Supabase security advisor: 1 leaked-password-protection WARN, 51 RLS-without-direct-policy INFO. Interpret RLS observations contextually, not by granting broad access.
- No real-money cash settlement, top-ups or payroll have been performed; never create invented external receipts, host incomes, agency clients, fake app notifications or customer activity.

## Handoff gates
- Owner/partner/ordinary user/CS/DB roles must be authenticated separately on Staging and permission denials recorded.
- End-to-end agent cash reference issuance and customer recharge must be reconciled on **approved Staging test accounts only**, with explicit test funds and cleanup plan. Production remains forbidden.
- One full previous UTC host month with genuinely attributable gift events: immutable evidence capture, audit, salary/commission rate authorization, precise liabilities, independent ledger review, only then safe close and reset. Rates are not inferred or silently invented.
- Live voice on two physical phones with microphone on/off, listening, 15-seat transitions, network loss and rejoin.
- Repeat restore drill for backups and Storage on independent authorized isolated environment.
- Keep PR #29 as DRAFT until signed financial and security QA. No APK and no production data changes.
