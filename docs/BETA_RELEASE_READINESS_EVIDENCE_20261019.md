# TotiChat — Beta release readiness / 90% acceptance gate
Date: 2026-10-19

## Release policy
Owner requested continued development toward **at least 90% evidenced release readiness**. This is a release-quality target, NOT permission to invent scores or an authorization to build APK/AAB. Historical explicit approval requirement for an Android test build remains active.

Only use `rebuild/flutter-v1`, staging `rziaedugbdwefbefcxjt`, new Flutter client `flutter_app/`, and approved design source `mrbalmain11-star/-` main. Do not modify `main`, production database, deprecated UI, external production deployments or old audio services.

## Functional implementation (source exists; device acceptance NOT implied)
- [x] Flutter/Dart client with Google OAuth, backend verified-session gate, static URL guard and public Staging client key.
- [x] RLS-filtered Home banners and real public room list; no fabricated banner/listener.
- [x] Room creation title + welcome + real selected WebP cover, storage owner-policy upload, failure cleanup.
- [x] Real room join/leave, 15 numbered seats, server seat reservation, 10-second member refresh.
- [x] Minimized room retained in Home overlay, with restore bubble and audio bridge state preserved in widget tree.
- [x] LiveKit Flutter client requests a token from the existing JWT-protected Staging `phase2-voice-token` service and uses server seat/mute preflight; device output still unverified.
- [x] RLS-scoped room chat and text-only DMs (room direct overlay plus private inbox).
- [x] Wallet balance from RLS-scoped `wallets` and gifts from genuine catalog; send RPC with unit-price guard, quantities 1/7/17/77/777 and a retry-stable request ID.
- [x] Global gift strip reads only verified, settled announcement rows with unit price >=7000; hides entirely when there are none.
- [x] Room owner moderation uses server-checked mute, allow, release seat and kick action.
- [x] Admin Center entry is Profile-only and derived from `phase3_admin_session`; only authorized read-only beta capabilities shown, no fake administrative success.
- [x] CI workflow installs Flutter SDK, resolves dependencies, analyzes, runs tests, prepares Android host source, checks OAuth intent and prevents APK/AAB generation.

## Latest Flutter CI — VERIFIED
- [Successful GitHub Actions run 39188427349](https://github.com/QYEM7/TotiChatpro/actions/runs/39188427349).
- `flutter pub get` succeeded; `flutter analyze lib test` reported **No issues found**.
- All Flutter unit/widget tests passed.
- Android host source and OAuth intent filter generated and verified; no Android application built.
- Exact source SHA-approved public JPG assets copied into `flutter_app/assets/images/` (login falcon + galaxy room background). UI code now uses `Image.asset` instead of network hotlinks for those assets.

## Staging read-only checks observed
- Project active and relevant tables/RPCs present.
- All nine sensitive exposed tables checked (rooms, room_members, room_messages, direct_messages, wallets, gift_catalog, gift_events, gift_global_announcements, home_banners) had RLS enabled; authenticated users have SELECT but **no direct INSERT, UPDATE or DELETE grants** on those tables. Write operations go through RPCs.
- `phase2-voice-token` and `phase2-voice-moderate` functions ACTIVE with JWT verification enabled.
- Snapshot: 3 existing Auth accounts, 2 existing rooms, 2 memberships, 0 room messages, 0 direct messages, 0 gifts, 0 global gift announcements, 3 wallets. Do not seed fake transactions.

## Acceptance gates — precise evidence
| Gate | Required | Current evidence | Status |
| --- | --- | --- | --- |
| G0 | Contracts, Flutter compiler and approved UI inspection | RLS/permissions checked read-only; Flutter analyzer/tests and Android source preparation PASSED (run 39188427349); visual parity not signed off | PARTIAL |
| G1 | Real Google sign in/out and session restore on Android, including callback | Auth code and generated manifest only | NOT VERIFIED |
| G2 | Two real accounts create, join, leave and reserve 15 seats; state stays synced | RPC availability verified, client code written | NOT VERIFIED |
| G3 | Two physical devices transmit/receive audio, mute, rejoin, avoid echo, enforce moderation | LiveKit code + Edge Function status only, secrets not confirmed | NOT VERIFIED |
| G4 | Actual room and DM delivery, recipient privacy and unauthorized denial | Table/RPC RLS reviewed read-only, client code written | NOT VERIFIED |
| G5 | One authoritative gift settlement per request, concurrent retries, zero-negative wallet | RPC expected-price and idempotent client usage, no real settled gifts on Staging | NOT VERIFIED |
| G6 | Approved visual parity, role split, support/admin safety, owner acceptance | Partial screen structures and read-only admin entry; no signed visual comparison | NOT VERIFIED |

**DO NOT CLAIM 90% RELEASE READINESS** until every critical gate passes actual runtime acceptance. Static checks do not substitute for two-phone, Google or financial tests. Avoid reporting a fabricated readiness percentage.

## Outstanding source/UI work before actual release
- Exact fidelity to *approved new* UI across beta screens, VIP frames and room decor. Current room/Home/login are structural Flutter ports, not screenshot-verified parity.
- One real voice and mic permission path with LiveKit Staging secrets configured; enforce fast SFU-side publish permission revocation on owner/moderator changes, not only cooperative client disconnect.
- Real room creation/storage upload smoke and Google deep-link callback after explicit Android build approval.
- Real room chat and DM multi-account security tests, server-to-all gift system notice and seat counter reconciled to financial events.
- Admin permissions, user reports, legal privacy terms and minimal release security review.
- Release signing and Play Store policy check (no paid plans required now).

No remote staging writes, migrations, production changes, APK/AAB builds or external deployment were performed in this iteration. The source CI success is **not** device/runtime acceptance and is **not** evidence of 90% release readiness.
