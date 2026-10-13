# TotiChat — Reference Fusion UI Implementation Plan
**Date:** 2026-10-13  
**Source baseline:** `develop/phase-2`  
**Implementation branch:** `design/totichat-ui-20261013`  
**Status:** Planning + isolated design-system foundation. No release approval and no live UI replacement.

## 1. The approved direction and protection rules
The latest generated multi-screen concept board is the **visual direction**, not production-ready artwork or proof of implementation. Build a distinct TotiChat design language informed by Echo, Haza, Saada, Funni, PotaLive, Dana (Party Now), Chamoji and Ebla **equally, by feature**, not by copying any one app.

- Brand shown to users: **TotiChat**, falcon symbol. Never expose “pro” in app identity.
- Visual character: premium and lively, predominantly **light pearl/lavender/ivory**, restrained gold, sky blue and warm rose; decorative but legible. Not the old heavy/dark theme.
- Arabic-first, RTL-ready, mobile-first. All graphical navigation icons must be vectors, not emoji/image substitutes.
- The room retains **15 fixed seats**, all ornamental avatar frames/badges, chat, room controls, gift effects and event ribbons. Never hide decorative features as a performance workaround.
- Fixed bottom navigation outside rooms; hidden only inside a voice room.
- Exit/minimize actions in a two-option translucent blur overlay; avoid opaque black/full-screen sheets and avoid a separate destructive X flow.
- Gifts: **bottom sheet**, room visible behind it; tap gift = select only; confirmed Send triggers real server payment via idempotency. Quantity chips: **1 / 7 / 17 / 77 / 777**.
- Global gift strip appears only for **verified real gifts at/above 7000 coins**, across voice rooms. If zero events, show no strip. Admin banners likewise appear only when real approved published entries exist.
- Sign in: **Google only** for current beta. No phone/Apple sign-in, no password recovery as an accessible beta flow.
- Coins sold via **charging agents only**. The reference-board sample card prices, Apple Pay, Google Pay and credit card checkout **must NOT** be copied into functioning recharge UI. No fabricated balances.
- “Admin Center” entry exists **only in My/Profile** and only for server-authorized staff. A single unified permission-filtered in-app center. Host Agency management remains restricted to Owner and main partner, with all access checked on the server.
- No voice messages in direct messages. Voice-message feature, if ever surfaced, belongs to room-only flow.
- Keep all work on isolated branch until the user approves visual QA and functionality. **Do not write to main, deploy production, change Supabase production/Staging, update stable LiveKit transport, or build APK/AAB.**

## 2. Source-of-truth and current verification
Source repository: QYEM7/TotiChatpro, `develop/phase-2`. Staging database: `rziaedugbdwefbefcxjt`.

Observed code: `app/index.html` remains a large legacy page; UI extensions are split across `app/*-ui.js` and numerous CSS layers. Build currently packages `/app/` with `scripts/build-approved-web.mjs`. Keep that path untouched in the design phase.

Observed server capabilities in Staging include: authenticated profiles; room create/join/leave, real seats and text chat, private DM RPCs, wallets/ledger, gift catalog and sending RPC, CP RPCs, agency RPCs, in-app notifications, VIP status, and privileged admin RPCs. **Presence of an RPC does not prove two-account, device, security, audio or financial acceptance.** Staging has active voice Edge Functions but must still pass actual two-phone audio tests.

The previously written engineering estimate of ~65% backend is an estimate, not verification that the backend is finished. The old 41-screen inventory predates new staging migrations; use it for **route coverage**, not to declare features missing today.

## 3. Screen contracts — cover every route
Status meanings: **A** real contract available but needs end-to-end integration verification; **B** partial contract/UI enhancement needed; **C** visual route/future capability, no claim of operational backend. Every route gets an empty/loading/error/permission state, mobile screenshot and navigation/back test.

| ID | Existing route / screen | Frontend action / backend contract | Status |
|---|---|---|---|
| 01 | loginPreview | Google OAuth, session and secure return | A |
| 02 | signupPreview | Legacy route; beta hides unsupported providers, show controlled account onboarding only | C |
| 03 | passwordResetPreview | Legacy route: not exposed while Google-only login is enforced | C |
| 04 | verifyAccountPreview | Legacy OTP route: hide unless actually required by supported provider | C |
| 05 | home | Real rooms, real banners or no banners | A |
| 06 | discoverPreview | Search rooms/users via verified API; don't show made-up discovery/events | B |
| 07 | tour | Internal UI-only design QA map; not a consumer navigation item | C |
| 08 | ranks | Real leaderboard only after audited stats exist | C |
| 09 | missionsPreview | Disabled/coming later unless verified rewards backend exists | C |
| 10 | treasurePreview | Disabled until server-backed feature is approved | C |
| 11 | notificationsPreview | `phase5_notification_feed`, read state | A |
| 12 | welcomePreview | Empty/off until real entitled reward program exists | C |
| 13 | room | rooms, members/seats, LiveKit session + moderation; 15 seats fixed | A |
| 14 | roomAdminPreview | `phase2_room_moderate`, owner-only setting/actions | B |
| 15 | gamesPreview | `phase5_room_game_*` for verified XO; other games explicitly not live | B |
| 16 | musicPreview | room_music_queue metadata; shared synced playback needs real proof | B |
| 17 | giftsPreview | gift_catalog + `phase3_send_gift`; real gift bottom sheet | A |
| 18 | messages | `phase2_dm_inbox`; no fake conversations | A |
| 19 | chatPreview | `phase2_dm_thread/send/mark_read`, text only | A |
| 20 | friendsPreview | `phase5_social_*` social graph | A |
| 21 | me | auth profile, verified stats, privileged admin entry conditionally | A |
| 22 | profilePreview | real profile, entitlement badges, CP, verified medals | B |
| 23 | profileEdit | editable profile + RLS-controlled avatar storage | B |
| 24 | settings | account privacy/security/notifications/logout | B |
| 25 | languages | client i18n; Arabic and other languages only when strings exist | B |
| 26 | block | `phase2_dm_block` plus verified scope of other account blocks | B |
| 27 | report | `phase5_support_*` ticket submission or explicit unavailable state | B |
| 28 | level | verified wealth/charm only; NEVER 50k dummy data | C |
| 29 | honor | `phase5_medal_*`; actual entitlements only | A |
| 30 | storage | owned rewards/items, true inventory state | B |
| 31 | bagPreview | `store_ownership`, equip status, CP cards | A |
| 32 | vip | 10-tier visual catalog, `phase5_vip_status`; no fake purchase | B |
| 33 | wallet | real wallets and ledger, `phase3_transfer_coins` | A |
| 34 | rechargePreview | `phase4_recharge_state/action`, agent-based only | A |
| 35 | storePreview | store_catalog + `phase3_purchase_store/equip_store` | A |
| 36 | cp | `phase4_cp_state/action`; one active Love CP rule | A |
| 37 | agency | rankings only if verified; no fabricated agency medals | C |
| 38 | agencyPreview | `phase4_agency_state` | A |
| 39 | agencyApply | host-agency request via controlled approval/support workflow | B |
| 40 | agencyStatusPreview | persisted agency registration state | B |
| 41 | agencyJoinPreview | `phase4_agency_action` join request + agency permission | A |

**Separately covered components (27):** create room, room settings, room info, seat actions, voice controls, room chat, gift sheet, global gift ticker, admin banners, room members, private invite, exit/minimize overlay, games overlay, music queue, room-only voice recording, DM from room, product details, gift history, coin transfer, diamond redemption, account security, catalog admin, transaction reports, host agency admin, technical support, block/language/report sheets, internal review navigator. The current inventory groups some elements; do not silently omit any.

## 4. Roadmap and deliverables
### P0 — Isolate and freeze references (now)
- Preserve screenshot and comparison board as visual references, not hardcoded app screenshots.
- Freeze route inventory (41) + secondary interactions (27); capture current routes and server APIs.
- Add design tokens in `design/reference-fusion-20261013/tokens.css`. This does not load into active app.

**Gate:** documentation & tokens only; no existing application file changed.

### P1 — Visual shell, four critical screens
- Build an independent code-backed preview with responsive UI, RTL, vector navigation and motion.
- Screen set: **Google Login / Home / 15-seat Room / Gift Bottom Sheet**.
- Keep seats completely visible on 360/390/430px widths; sheet overlays without losing real room state.
- Use a truthful **Visual Preview** label where interaction uses local test UI. Never claim it is connected to Staging.

**Gate:** owner visual approval by comparing phone screenshots to the concept; back navigation and each visible action checked.

### P2 — Essential social and economy screens
- **Discover, messages+DM, Profile/My, VIP, CP, Store+Inventory, Wallet, Recharge, Agency and Notifications**.
- Admin Center accessible only through privileged My entry, with role-aware navigation and backend-side permission mapping.
- Define loading, empty, denied, error, offline and stale-session presentations.

**Gate:** full visual screen map and independent interaction review.

### P3 — Remaining route parity
- Complete all other 41 routes + 27 overlays without dropping any from QA coverage.
- Separate planned-but-unavailable functionality from released functionality; preserve navigation maps without fake confirmations.

**Gate:** complete route manifest; buttons, keyboard, dialogs and RTL accessibility audited.

### P4 — Controlled backend integration (Staging only)
- Swap local presentation adapters for existing `phase2_*/phase3_*/phase4_*/phase5_*` contracts.
- Do not change voice SDK, existing money ledger, settlement policy or RLS just to fit the UI.
- Add scoped feature flags only for actually supported functionality, server-side authorization mandatory.
- Prove idempotent gift send and real events; balances and profiles never seeded to imitate success.

**Gate:** two-account end-to-end success on Staging, including rejected/unauthorized flows; no fake banners, gifts, prices, online counts or VIP.

### P5 — Mobile acceptance and optional release approval
- Test 360/390/430px viewports and real Android phones: joining voice from two devices, microphone, reconnect, 15 seat state, scrolling, gifts, admin guards, logout/relogin.
- Compare screenshots on each iteration; fix spacing, fonts, icons, effects and animations to the accepted concept as physically feasible.
- Only after explicit owner approval consider APK/AAB and production migration/deploy.

**Gate:** actual device and server evidence. No percentage or '100%' label based on static UI.

## 5. Components and visual contract
- Palette in `tokens.css`; palette names not tied to third-party apps.
- Primary device target: Android portrait, responsive 360/390/430px with safe-area handling.
- Components: top status/header, brand lockup, banner carousel with zero-state, cards, seat avatar with VIP frame/level/CP, real gift mini-counter, blurred action overlay, inline chat, bottom gift sheet, role-filtered cards, merchant/agency forms.
- Avatar/room cosmetics: stable dimensions, no scroll of seats, no "white rectangle" artifact behind avatar. Preserve optional frames when their verified entitlement exists.
- Motion states: gift reveal / VIP entrance / seat presence, restrained durations, reduced-motion fallback and clear exit/cancel.
- Language/RTL: source code symbols in English, localization through dedicated resources; readable Arabic labels in UI and mirrored navigation.
- Offline/error: distinguish `loading`, `empty`, `denied`, `error`, `success`. Never mask unavailable backend by mock success.

## 6. Concept-image mismatches that MUST NOT become product behavior
The concept board is inspirational: illustrative faces, statistics, wallet numbers, gift prices, attendance, merchants and ranks **are not real TotiChat records**. In particular:
1. Do not offer phone or Apple login.
2. Do not implement Apple Pay / Google Pay / credit-card coin purchase from the picture.
3. Do not put voice notes in private messages.
4. Do not show fake VIP8, balances, ranks, room occupancy, transactions or global gift events.
5. Do not use picture's full-height gift screen: design actual **bottom sheet** instead.
6. Do not place Admin Center in bottom navigation or on the Home page.
7. Do not mistake a room-management dashboard screenshot for the unified in-app owner/staff Admin Center.

## 7. Honest completion protocol
Track each screen across four independent axes: `visual reviewed`, `interaction wired`, `backend verified`, `device QA passed`. The concept visual alone satisfies none of the backend/device gates.

**Current delivery:** first, documented plan and design-token source in an isolated design branch. No live app replaced, no APK built, no database written, and no claim that preview was deployed.
