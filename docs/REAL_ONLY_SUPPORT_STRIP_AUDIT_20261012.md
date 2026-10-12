# TotiChat — Real-only content and support ribbon audit
Date: 2026-10-12
Repository: QYEM7/TotiChatpro
Branch: feature/in-app-admin-center-20261012
Supabase: **rziaedugbdwefbefcxjt (STAGING ONLY)**
PR: https://github.com/QYEM7/TotiChatpro/pull/28 (DRAFT; do not merge prematurely)

## Nonnegotiable rules

1. No invented users, members, room counts, paid balances, transactions, VIP, fake online/LIVE statuses, simulated friends, or sample senders in the signed-in real app.
2. **A gift/support ticker or global celebratory strip can appear ONLY for a single real financial gift transfer whose settled total is >= 7,000 coins**. Never sum different people/events to cross threshold. E.g. 6,999: hidden; 7,000: eligible; 1,000 coins × 7 in one transaction: eligible; 500 × 7: hidden. This is **total_coins**, not price of one item.
3. The database trigger must verify a completed `gift` financial operation and both matching wallet ledger legs: sender debited in coins, recipient credited in diamonds. An animation, client flag, debug action or catalog price cannot prove payment.
4. If no eligible recent event exists, hide the complete gift strip; no placeholder/fake donor/0-scroll/dummy support names. The web UI displays recent events only (five minutes, to avoid re-presenting long-old donations as happening now).
5. Do not change production, main, the approved reference `app/index.html`, 15 microphone positions, physical UI artwork, or native APK.

## Source and runtime audit findings

| Area | Finding | Resolution |
|---|---|---|
| Initial illustrated room `giftTicker` | Approved HTML contains a sample sender/100-gift text | Live `phase2-rooms.js` hides it until validated server feed takes control; `phase2-global-gifts.js` hides sample portrait and complete ticker when invalid/empty |
| Global celebrations | Original backend minimum was `gift_catalog.price` (single item), not actual support total | Deferred audited trigger checks `gift_events.amount >= greatest(7000, configured_minimum)`, completed operation, sender debit and recipient credit |
| Announcement table | Previously any positive total was permitted | Added `tc_confirmed_support_only_floor_7000` CHECK; no direct authenticated INSERT |
| Admin configure | Could set minimum 1; label called it unit price | Enforced 7000 minimum in both server setters and Owner client field; label now total of verified support |
| Public feed | Validity previously only checked event/room IDs and `total_coins>0` | Added sender/recipient IDs, positive safe integer quantity/unit/total, exact multiplicative total, >=7000, recent timestamp, server-side total/time filters, fail-closed on read error |
| Demo rooms / fake social numbers | Reference HTML and independent design preview still intentionally contain art + fictional sample content | Live room list uses Supabase room records; legacy `room-ui-enhancements.js`, `agency-hub.js`, `royal-vip15.js` never mount for live/native |
| Fake owner/LIVE/audio claim | Legacy visual room decoration could say Owner/LIVE by default | Real Owner mark requires actual owned room; no assertion of LIVE audio just because page opened |
| Fake preview navigation | QA review button and explicit mock preview could be reached in real entry | Disabled when `mode=live`, Capacitor/native, or registered real-only preview |
| Profile donor image/time/status | Design reference had illustrative donor and fixed clock/4G | Removed those from authenticated live rendering |
| Empty home adverts | Old artwork had a local hero sample | Live home only reads truly published backend banners; zero banners renders none |

## Live Staging data snapshot, 2026-10-12

- Gift operations: 0
- Public gift announcements: 0
- Home banners: 0
- Announcement service enabled **true**, strict minimum **7,000** (changed on isolated Staging)
- 12 genuinely configured active catalog gift **definitions** eligible for announcing if transferred with confirmed settled >=7,000. Catalog entries are configuration, **not** proof that any user has purchased/sent one.
- Staging migration: `20261012124921_verified_support_strips_min_7000.sql`
- DB metadata checks passed: both floor constraints, threshold in all three setting/trigger functions. No fabricated transactions were created.

## Tests

- `tests/verified-support-strip-contract.test.mjs` checks <7000, >=7000, bulk quantities, tampered totals/identities, stale/future events, empty ribbon, both wallet ledger checks and blocking mock runtime.
- Included in `test-inapp-admin-center.yml` and `staging-manual-preview.yml`, alongside existing admin, microphone, responsive, foundation, Royal visual and staging configuration tests.
- Automated tests are not evidence that real devices/credentials/audio/actual money changed. Record each final CI result for current SHA before claiming signoff.

## Unresolved / deliberately not claimed

- User's original approved `app/index.html` and independent visual-review screens still contain sample data **as design fixtures only**. We left the original byte-for-byte untouched. This is distinct from the real signed-in app and should never be used as real end-user content.
- Unverified real two-account transaction test: send gifts worth 6,999 vs 7,000 on authorized Staging wallets, inspect matching ledgers and UI visibility. Do not mint balances or make fabricated financial events to fake this test.
- A complete hands-on walkthrough of all **41 routes and 27 dialogs**, across Android and real accounts, has not occurred. These tests are still required to establish zero fake content across all possible navigation and overlays.
- Real two-phone LiveKit audio, OAuth callback/forgot password and agent cash settlement are independent unresolved UAT/security checks. No deployment, APK or production release from this audit.
- Supabase security advisories and privileges need ongoing review. Do not broadly weaken RLS to make UI appear populated.

## Acceptance

**Code-side and staging database prevention against fabricated/under-threshold gift announcements are implemented.** This does **not** assert full TotiChat product UAT is complete. Keep PR #28 draft and unchanged production until real-device tests prove behavior.