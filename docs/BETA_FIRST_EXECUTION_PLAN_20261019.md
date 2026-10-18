# TotiChat — Beta-First Execution Plan (2026-10-19)

## Decision and objective
The owner approved a beta-first, staged delivery strategy on 2026-10-19: prioritize one genuine, stable, testable TotiChat beta over completing every planned feature. Defer secondary features. No legacy frontend/UI reuse.

This plan is a **scope and acceptance document**, not an assertion that features are implemented or that the beta is ready.

## Fixed sources and boundaries
- Backend source: `QYEM7/TotiChatpro`, branch `rebuild/flutter-v1` (backend-only).
- Approved visual reference: `mrbalmain11-star/-`, branch `main`, principally `src/` (React/TypeScript is a visual/interaction reference, not the production mobile stack).
- Production mobile target: **Flutter/Dart**, faithful to approved visual reference; no design improvisation.
- Backend validation target: Supabase **Staging** `rziaedugbdwefbefcxjt` only.
- Do not change production, `main`, or the historical UI backup branch.
- No APK/AAB build or store release until explicit owner approval.
- Do not run remote migrations/deployments without first validating consequences; preserve the established LiveKit/audio core.
- No fabricated live data, balances, banners, gifts, or performance/readiness claims.

## Minimum viable REAL beta scope (in priority order)
1. **Identity and session:** Google-only OAuth via Staging; persistent secure session; user profile; assigned ID must come from server/admin. No fake login.
2. **Home and rooms:** actual room listing, room creation (name, picture, welcome message), joining/leaving/minimizing, room permissions and empty states. No fake banners.
3. **Voice and seats:** exactly 15 seats in 3×5 layout as specified; real room membership, take/release seat, mute/unmute, voice join/rejoin using existing `phase2-voice-token` and LiveKit architecture; do not change audio SDK solely for UI development.
4. **Text communication:** realtime room text chat, system notices where backed by actual actions, and basic user-to-user DM reachable from room (no DM voice).
5. **Gifts and wallet:** gift bottom sheet over the visible room; select then send; quantities 1/7/17/77/777; balance, server-authoritative ledger, idempotent gift transfer and concurrency protection, no negative balances; actual seat counter/message. Global gift strip only for real gifts >=7000 coins.
6. **Minimum admin safety:** Profile-only admin entry for authorized accounts; permissions enforced server-side; only essential owner/moderation functions needed to safely run beta. No unverified admin role privileges.
7. **Visual parity and usability:** compare Flutter screens against the newly approved reference for every beta-flow screen; stable bottom bar outside room and accessible room controls.

### Deferred unless a required dependency
Full VIP catalog/effects, CP management, agency business workflows, games, music library enhancements, advanced store/inventory, campaign banners, cosmetic polish beyond visual parity, notification/FCM expansion, and non-essential dashboards. Existing backend code for these remains preserved; no deletion is implied.

## Acceptance gates — proof, not estimates
- G0: Verify each backend contract, current migrations/RLS, supported Edge Functions, Flutter toolchain, approved reference screens and assets; record gaps.
- G1: Real Google account can sign in/out and restore session on Staging. IDs and private data are server-authoritative.
- G2: Two different test accounts can discover/create/join rooms; state is consistent across clients. 15 seats and permissions behave correctly.
- G3: Two physical devices can join the same room and pass **real audio** publish/subscribe/mute/rejoin tests without echo/mic failures.
- G4: Room messages and DM deliver to the correct real recipients; unauthorized access is rejected.
- G5: Concurrent/double gift-send tests produce one correct settled transaction per unique request; wallet and recipient records reconcile; insufficient balance fails safely.
- G6: Approved visual comparison across beta screens; real empty states; permissions tested on separate admin/ordinary accounts; owner signs off on release candidate.
- An item is **NOT VERIFIED** until test evidence exists. A passing static review or presence of code is not runtime proof.

## First implementation sequence
1. Audit read-only backend contracts and visual reference; produce a screen-to-API map and a checklist of missing schema/functions.
2. Establish a clean Flutter project in an authorized destination; preserve presentation/state/data separation and feature flags for LIVE mode, without mock financial/social content.
3. Deliver the complete Google login → real Home → room join vertical slice; test it before building out remaining features.
4. Add real seats/voice, then real chat, then wallet/gifts, then necessary admin functions; regression-test each vertical slice.
5. Run all acceptance gates and only then request build approval.

## What has been verified at plan authoring
- `rebuild/flutter-v1` exists and `README.md` explicitly identifies it as backend-only.
- `BACKEND_ONLY_STATUS.json` records approved UI source and confirms it was **not** ported/connected.
- Approved source's `src/context/AppContext.tsx` imports `mockData` and includes local balance/gift actions; it must not be treated as integrated production logic.
- `supabase/functions/phase2-voice-token/index.ts` exists and calls `phase2_voice_token_preflight`. Presence alone does **not** demonstrate that the deployed service passes real-device tests.

## Status at this checkpoint
Planning/traceability completed; actual Flutter integration, remote service validation, voice-device QA and beta acceptance remain **unverified/not completed**. No schema changes, production changes, frontend migration or APK build were made by creating this document.
