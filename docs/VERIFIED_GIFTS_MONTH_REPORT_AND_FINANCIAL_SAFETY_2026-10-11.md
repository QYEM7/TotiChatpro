# TotiChat — verified gift receipts, host-month read-only review, and payment safeguards
**Date:** 11 October 2026  
**Allowed destination:** `QYEM7/TotiChatpro`, `develop/phase-2`; dedicated Supabase Staging `rziaedugbdwefbefcxjt`  
**Release permission:** **NO-GO** — this records an actual safe Staging increment, not a ready-to-ship payment or Android release.

## Deployed and connected to real authenticated UI

### 62nd Staging migration: personal gift receipt history
`supabase/migrations/20261011213000_verified_personal_gift_history.sql` deployed as `staging_verified_personal_gift_history`.

- `phase5_gift_summary` computes **actual persisted** sent/received gift counts, historical gift coin costs and diamond lots issued to the recipient. All values are obtained only from gift events joined to `financial_operations` with `operation='gift'` and `status='completed'`. The RPC does **not** equate issued diamonds to current balance, commission or owed salary.
- `phase5_gift_history` pages by `(created_at,id)`, restricts rows to signed-in owner who actually sent or received the gift, and returns gift name/icon, counterparty, source category, quantity, committed cost, and actually issued recipient diamond lot. No user_id parameter or trust in frontend identity.
- `app/phase5-gift-history-ui.js` and scoped styles show true receipts and empty states in the approved Profile. No changes to `app/index.html`. All server currency values are strings where appropriate to avoid JavaScript precision loss. Auth changes clear private state.
- **Verified rollback-only database fixture**: [T64 full-stack PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38155302663). Actual gift-send transactions on local isolated PostgreSQL, sender vs recipient counts, diamonds, cursor no duplication, outsider denial, invalid cursor rejection.

### Host agencies: real monthly source review, NO mutation
`app/phase5-host-month-review-ui.js` reuses existing server `phase5_host_month_preflight`. The review entry is shown only if the signed-in account is the **Owner** or explicitly designated **main partner** — never all Super Admins or DB staff by implication.

The report pages an already-closed UTC month, with agency/host gift diamond totals, current remaining and allocated/converted amounts. UI verifies that the server answer has `isDraftPreflight:true`, `canZeroDiamonds:false`, `paysSalaries:false`, and `hasPayrollRates:false`. It does not invent payroll targets, salaries, commissions or conversion prices. There is **no** client call to debit, pay, create, or zero wallets. Month close / liabilities **remain blocked** until the actual approved business rates, safe immutable settlement, and reconciliation are delivered.

### 63rd Staging migration: critical Lucky Gift fail-closed protection
`supabase/migrations/20261011220000_fail_closed_unapproved_lucky_gift.sql` deployed as `staging_fail_closed_unapproved_lucky_gift`.

**Finding:** catalogue `g11` is labeled `LUCKY_GIFT`, while existing `phase3.send_gift` credits a deterministic amount as diamonds — not a true probability-based payout. This is an unacceptable mismatch for the approved Lucky Gift product.

- A verified enabled **BEFORE INSERT** gift trigger rejects a Lucky Gift from the catalog or recorded source with `LUCKY_GIFT_PENDING_RULEBOOK`. Because the entire gift RPC is one PostgreSQL transaction, the earlier coin debit and diamond credit are **rolled back** on rejection, with no ledger, financial operation, gift event or diamond lot persisted.
- Safe ordinary `FIXED_GIFT` still works. `phase5_lucky_gift_readiness` accurately returns `enabled:false` / no approved odds or payout engine.
- `app/phase2-catalog-data.js` fetches actual `diamond_source_type,is_active`, while `app/phase2-catalog-ui.js` **disables** the luck gift item with Arabic status and rejects it before any payment RPC even if an older selection was held.
- [Local full-stack T65 and legacy-redemption regression PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38155887324). Local historical-redemption testing safely suspends the trigger **only within a disposable BEGIN/ROLLBACK fixture**, to preserve coverage of previously created `LUCKY_GIFT` diamond lots. The trigger is restored automatically by rollback. The separate T65 test proves all NEW lucky purchases are blocked and ordinary fixed gifts remain valid.
- **NOT implemented:** the Owner-approved prize multipliers/probability table, secure randomized draw and atomic payout/audit. Do not label Lucky Gifts completed or release them as paid/randomized rewards.

### 64th Staging migration: actual received gift notification
`supabase/migrations/20261011223000_verified_gift_inbox_notifications.sql` deployed as `staging_verified_gift_inbox_notifications`.

- Extends verified private `user_notifications` to `gift_received` and adds a server-only audit trigger. The server matches `gift_sent` audit `operation_id` to a **completed** financial operation and authoritative `gift_events` row with matching actor, then generates the recipient's private notification.
- `(recipient_id, source_type, source_id)` idempotent uniqueness prevents replay duplicates. Payload contains gift identifier, sender ID, quantity, room and committed coin amount, but no free-form message body or external payment details.
- `app/phase5-notifications-ui.js` labels genuine gift receipt notifications and renders the server-verified quantity and coin cost when valid.
- [T66 full local Auth/SQL integration, PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38155969583): actual committed gift leads to exactly one recipient-only notification, no forged outsider read, duplicate request does not repeat it.

## Verified security state
After all four milestones, direct Staging SQL showed:
- **64 schema migrations applied**.
- **0** real gift events, **0** user notifications, **0** financial operations, **0** wallet-ledger entries, **0** live room members injected during deployment.
- Live enabled trigger `tc_reject_unapproved_lucky_gifts`, live enabled trigger `tc_notification_on_verified_gift_audit`, valid `gift_received` constraint, anon access to gift history and lucky-readiness RPC denied.
- [239/239 comprehensive frontend/source tests PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38156037147); source audit and staging-only live web build passed without producing an APK or modifying production.
- Supabase advisor WARN **`auth_leaked_password_protection`** remains, requiring separately approved Auth provider configuration. Closed internal-table RLS informational notices are not silently disabled.

## Required before a true client-ready beta
Exact Owner-approved lucky-gift odds and payouts; host-salary/agent-commission/target model with immutable month-close and liability preservation; two hosted real-user gift/role/agency tests; LiveKit SFU/phone audio and moderation; Google OAuth Android callback and account recovery; signed Android install/update; background FCM push delivery; full active UI route audit, accessibility/soak, and offsite database + private Storage backup/restore. None of these can be assumed complete because a local test suite is green.

**Previous directional overall estimates remain Backend ~65%, full app ~50%, pending external real-world acceptance. `release_allowed=false`.** No production/main changes, no fabricated money, no invented odds, no unapproved diamond reset.
