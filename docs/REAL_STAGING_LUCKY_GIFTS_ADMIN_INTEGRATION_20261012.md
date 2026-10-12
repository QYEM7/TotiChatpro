# TotiChat — Lucky Gifts + authoritative in-app administration integration
**Date:** 2026-10-12  
**Repo/branch:** QYEM7/TotiChatpro / feature/in-app-admin-center-20261012  
**Backend:** Supabase Staging `rziaedugbdwefbefcxjt` ONLY. Production and main untouched. PR #28 remains Draft.

## Implemented on Staging

- Real paid Lucky Gift sends now use the **existing transactional financial gift RPC** `phase3_send_gift`: real sender coin debit, recipient BASE diamonds, matching wallet ledgers/financial operation, operation ID, audit log and idempotency request ID. No separate client balance edits.
- Added `phase3.draw_verified_lucky_award` backend trigger. For classified active Lucky gifts only, one server-side CSPRNG draw per completed gift event, persisted in `phase3.lucky_awards` with unique event ID, sender, receiver, room, quantity, rewardTier, multiplier, points, rules version, timestamp. If any step fails, the whole gift transaction rolls back.
- Multipliers award **NON-REDEEMABLE Lucky Points only**, never extra diamonds or coins. Base gift value enters existing financial/agency flow normally. Bonus does NOT affect host salary diamonds, agency targets or monthly settlement. Do not confuse points with cash or a payout promise.
- Staging-only **provisional** configured weights total 10,000: spark ×1 8,000 (80%); double ×2 1,700 (17%, maximum 30/day/recipient); royal ×5 300 (3%, maximum 5/day/recipient). Server excludes exhausted tiers and recalculates weights between eligible tiers; actual per-recipient draw percentages can differ from base odds. UI explains this. Owner has NOT formally approved these exact default odds for production.
- `phase6_lucky_gift_policy`: authenticated read of visible tiers and current status. `phase6_lucky_gift_history`: only sender's/recipient's real award history. `phase6_lucky_gift_configure`: designated Owner/main partner approval UI, backend authorization, strict tier validation, 100% weights, daily caps and audit/idempotency. No user role metadata grants admin rights.
- Existing `phase5_lucky_gift_readiness` now reports **Staging pilot noncash draw** and correctly says paid random bonus payouts NOT approved. Real client gift drawer displays current backend config, real history and genuine confirmed event outcome; rejects unavailable policy.
- Found and corrected the preexisting **diamond redemption rate mismatch**: fixed-source Diamonds 30% (current configurable numerator 3/denominator 10); Lucky-source Diamonds **10%**. Backend `phase3.preview_redemption` feeds the existing atomic redemption, so front-end guesses cannot override the rate. Lucky Points never participate.
- Live app bridge `app/phase6-verified-state-sync.js`: after confirmed admin changes, foreground/online, and while visible ~45-second checks, it asks the real backends to refresh VIP, medals, notifications, home banners, social, wallet, live room and role status. It does not simulate results; unauthorized actions remain server-rejected.
- Admin center navigation includes role-gated **هدايا الحظ والاحتمالات** with actual approve, change odds/caps, on/off form. Admin uses the SAME in-app account via `ملفي`, not any external dashboard login.

## Crucial release and security constraints

- **Fresh installs and production replay default to Lucky DISABLED.** The version-controlled initial SQL migration deliberately does not auto-enable paid random sends. Only the isolated Staging instance was enabled for pilot testing. Do not assume this proves regulatory/payout approval for production.
- Security CI found the new trigger inherited PUBLIC EXECUTE. Fixed in forward migration `20261012134223_staging_lucky_trigger_function_execution_lockdown_v1.sql`; SQL privilege verification now returns draw_anon=false, draw_authenticated=false, configure_anon=false, direct-write=false.
- Staging snapshot at time of review: `lucky_settings.enabled=true`, version 2, weights total 10,000, **0 stored lucky awards and 0 real gift events**. This confirms configuration—not a genuine purchased-gift E2E.
- Current Staging security advisor: **55 INFO** RLS policy notices on locked/private tables and **1 WARN** for leaked-password protection; avoid opening private tables simply to reduce notice counts.
- Do not merge PR, publish public beta, deploy a new APK, or activate production financial randomness from this implementation alone. Mandatory validation with two authenticated accounts on a disposable/local or authorized Staging wallet: check sender debit, recipient base diamonds, 10% redemption, immutable result/idempotency under duplicate requests, real history, daily caps, Owner/partner authorization, and non-Owner rejection.

## Existing admin operations and outstanding limits

The existing in-app admin supports verified role-scoped management actions such as staff permissions, support tickets, room ban/unban, Owner-only VIP and medals, banners and gift announcements. The new change event/periodic refresh connects confirmed actions to the authenticated user interface, but **not every one of the 41 screens and 27 dialogs has been touched or manually verified**. Agency/recharge and settlement operations remain subject to their existing backend restrictions; do not turn read-only finance controls into fake success. Owner/main partner authority for host agency management remains separate from additional Super Admin accounts; DB employees can only open host agency requests, never recharge agencies.

## Verification inventory

- Migration and functions applied to Staging, privileges and math queried read-only.
- `tests/lucky-gifts-real-admin-sync.test.mjs` added to key GitHub CI suites, alongside existing security/real-only/admin/browser/full-stack tests.
- Earlier local T03 full-stack failed due overly broad EXECUTE on new trigger; revoked and committed a forward migration, must recheck on fresh CI SHA.
- No real financial gift is fabricated to claim success. Full UAT remains mandatory.

## Beta acceptance (hard blockers)

1. Two signed-in phones: normal gift and Lucky gift, real room mic state and true idempotency.
2. Display the real odds, cap behavior, actual outcome and matching `lucky_awards` history.
3. Test mixed FIXED_GIFT/ LUCKY_GIFT redemption math, wallet and ledger conservation on isolated test accounts.
4. Owner updates Lucky odds, VIP, medals, banners and staff; another signed-in phone sees server-authorized change. Ordinary user can't see/admin execute.
5. Confirm no backdoor into host/recharge agency scope and no mutation through unauthorized DB/CS roles.
6. Re-run exact-HEAD automated CI; investigate any failure before accepting even the limited beta.
