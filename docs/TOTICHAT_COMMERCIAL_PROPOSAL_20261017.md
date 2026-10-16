# TotiChat — proposed commercial settings (NOT APPROVED / NOT LIVE)

Status: **draft for Owner approval, never auto-applied**. Prepared 2026-10-17.
Scope: separate Flutter branch `rebuild/flutter-v1`, Supabase **Staging only**. This file changes no prices, coins, commissions, salaries, or permissions.

## 1. Existing Staging recharge price list — verified, not a proposal

| Package USD | Server coins | Coins / USD (approx.) |
| ---: | ---: | ---: |
| 0.99 | 5,247 | 5,300 |
| 4.99 | 26,447 | 5,300 |
| 9.99 | 52,947 | 5,300 |
| 24.99 | 132,447 | 5,300 |
| 49.99 | 264,947 | 5,300 |
| 99.99 | 529,947 | 5,300 |

These are already in `public.recharge_packages`. **No schema or value changes recommended before financial and policy review.**
Actual monthly reward thresholds and bonus coins can create significant liabilities and require an all-in margin audit.

## 2. Suggested pilot agent economics — nonbinding

- Recharge reseller proposed gross **8% discount** to the agent from an approved retail package price, not 8% extra coins. Example: a listed $9.99 package would hypothetically cost the reseller $9.19 before processing, taxes and FX charges (rounded from $9.1908). **Not a live tariff or transfer instruction.**
- Charging agent must be prepaid in coins by Owner. Agent cannot borrow coins or run a negative treasury.
- Never allocate coins based on claimed cash without evidence, reconciliation, receipt uniqueness, owner approval and backend idempotency.
- Proposed Host Agency service share: **10% of separately verified, eligible platform net margin** after obligations; not 10% of gifts, diamonds or arbitrary top-ups. Accounting definition and actual platform margin are not yet approved.
- **22 host salary levels:** no fixed salary numbers can be safely set until target thresholds, minimum activity days/hours, verified monthly receipts, and agency liquidity are signed off. Any 22-level table must be audited against existing backend earning units first. Salaries are paid by Host Agency within the agreed following-month 1st–10th window, escalated from the 11th; accrued diamonds evidence must **never** be mislabeled as paid salary.
- Monthly zeroing: **not activated**. Preserve immutable accrual evidence and settlement ledgers. Do not reset while payroll/settlement is unimplemented.

## 3. Policy-dependent launch decision

Google Play Payments policy presently states that virtual currencies and other digital goods generally require Play Billing when purchased inside a Play-distributed app unless a defined exception/program applies. Do not steer Play customers to off-platform payment via in-app buttons, chat, links or text. Options for a compliant product design must be reviewed against current market/eligibility before enabling in-app coin orders:
1. Approved Play Billing flow for in-app digital currency purchases;
2. A genuine consumption-only Play client with no in-app checkout or steering and purchases managed independently of the Play app (where permissible);
3. Other registered payment choices **only after** obtaining eligibility and complying with terms.

Agent console support is technical infrastructure, **not** a clearance for off-platform in-app consumer payment solicitation.
Official policy: https://support.google.com/googleplay/android-developer/answer/9858738

## 4. Lucky Gifts — deliberately locked

Staging has a genuine noncash random-reward mechanism, but `phase5_lucky_gift_readiness` reports `approvedOddsPublished=false` and `oddsAreProvisionalStaging=true`. Published purchase-adjacent win odds are not yet approved; paid client activation is blocked.
Server-defined non-redeemable Lucky points are **not** diamonds, wages, or cash. Never simulate multipliers or imply withdrawable winnings.

## 5. Verification before any money flows

- Verify every pricing/commission rule and customer-facing disclosure with Owner.
- Financially model coin minting, rewards, refunds, gift-to-diamond rules, reseller spread, exchange rate, tax and agency payroll under peak and refund cases.
- Set up separate authorized Staging users for Owner, agent and customer. Run real auth-guarded RPC end-to-end tests including duplicate request IDs, insufficient funds, support escalation, refunds and rollbacks.
- Production migration requires backups, a reviewed ordered migration, reversible deployment plan, and separate authorization.
- No APK/AAB and no production rollout under this document.

## 6. Current front-end known differences

Server catalog presently exposes VIP 1–8 as purchasable items; desired visual levels 9–10 need valid catalog entries, permissions, artwork and pricing approval. Never display dummy VIP ownership or make up levels.
Room music queue exists but licensed playback/source and shared playback timestamp are not implemented.
