# TotiChat — Pre-beta real UI, roles and buttons readiness
**Date:** 2026-10-12  
**Scope:** `QYEM7/TotiChatpro` on `feature/in-app-admin-center-20261012` (PR #28, Draft).  
**Backend:** independent Supabase Staging `rziaedugbdwefbefcxjt` only.  
**Release verdict:** **NOT YET READY FOR PUBLIC/OPEN BETA**. Eligible for a controlled manual UAT when the correct updated Staging build is available. Production, main, approved HTML and APK were not changed.

## Implemented in this feature branch

| Surface | Verified change / source |
|---|---|
| Real mic seats | `app/phase2-rooms.js` preserves the five-by-three / 15-seat layout and real profile name/photo. Adds verified VIP tier only if active (1–10), equipped eligible store frame only if active and owned, and real completed in-room gift **count** directly below the name. Roster-only identities; null/offline data does not create sample labels |
| Mic design | `app/phase6-mic-presence.css` gives coherent premium treatment for active VIP, verified frame indicator and gift count. Existing LiveKit real-speaker, mute and owner controls stay unchanged |
| Mic data security | `supabase/migrations/20261012131252_verified_room_mic_cosmetics_gift_count_v1.sql` defines membership-restricted `phase6_room_mic_decorations` wrapper and audit-backed count. Calls authenticated Staging and fails closed for unverified entitlement/decoration |
| Gift picker | `app/phase2-catalog-ui.js` and `app/phase6-gift-tray.css`: fixed lower drawer maximum height `min(67dvh,535px)` (62dvh when very short), scrollable grid and independently scrollable tabs/recipients, anchored send controls, ARIA tab state. Real gift catalog, quantities, recipient and server-confirmed payment remain authoritative |
| Home banner lifecycle | `app/home-banners.js` and `app/banner-core.js` display ONLY valid real published banners during their active date window. Nothing renders if there are zero approved entries. `app/phase6-admin-banners.js` refreshes Home only after real admin save/publish acknowledgement |
| Official sign-in | `app/official-auth-screen.js`, `app/official-auth-screen.css`: improved pearl/violet/gold falcon-branded layout on Android and desktop, accessible input/pass visibility and recovery preserved. Unconfigured OAuth providers hidden instead of unusable fake buttons |
| Unified admin | `app/phase6-inapp-admin.js`, `app/phase6-inapp-admin.css`: SVG icon family, one server-verified `مركز الإدارة` entry inside `ملفي` only. Ordinary users don't get an admin entry; backend enforces individual actions. No daily redirect to standalone panel |
| Two formerly-disabled Home buttons | `app/royal-visuals.js`, `app/phase2-rooms.js`: VIP chip leads to My/Profile, and Search looks through at most 40 genuinely loaded room records and opens real join path; no invented search results |
| Verified support strip | PRIOR work still applies: a single **settled gift transaction >=7,000 coins** with matching sender/recipient ledger; empty or failing feed hides the ribbon entirely; no fake gift senders |
| Icon consistency | `app/phase6-premium-icons.js` keeps icons unified in authenticated mode. New admin SVG glyphs do not alter route permissions |

## Live Staging inspection (no synthetic data inserted)
- Published valid Home banners: **0**. Therefore the live Home must not render a banner until Owner/authorized partner uploads & publishes a valid one.
- Confirmed gift events: **0**; no fake gift count may be injected.
- Snapshot includes a seated room member; real role/audio and cosmetics UAT must still be performed from actual devices/accounts.
- Active frame item catalog has definitions with mostly `preview_url=null`, no independent verified art for every frame. **Current mic visibly renders a premium frame ring + authenticated item icon; it does NOT assert the unique custom illustration of each collectible is already delivered.** Art assets require their own published/mapped images and visual review.
- Supabase migration / RPC and permissions were inspected; privileged APIs aren't callable as anonymous users.

## Automated QA summary
As of this report, the **code HEAD `690575e17adf33f6da1bcbdb0296c65b8a9e7352` passed 10/10 named GitHub Actions workflows**: T03 local schema replay, T03 isolated local full stack, Phase 2 foundation, Royal browser QA, premium icon mobile QA, real mic presence visual QA, Admin Center tests, real-only Staging preview, T36 host month, T42 support. This establishes automated test success on THAT SHA only. Subsequent UI improvements/search and this report introduce newer commits and must pass their own exact-HEAD checks before signed-off build or deployment. `tests/beta-ux-prelaunch-contract.test.mjs` was added to multiple relevant CI suites.

## Blockers / incomplete controls — do NOT claim all buttons work
- `app/royal-visuals.js` intentionally disables certain home category filtering tabs without server-backed classifications. They must either receive real backend contracts or stay unavailable/clearly labelled.
- **Lucky gifts** cannot send until probabilities/prize obligations are server-authoritative and approved; intentionally disabled to prevent fake winnings.
- **Agency recharge** lacks verified real end-to-end agent cash & top-up fulfillment. Store purchase confirmations are separate from this.
- Admin `settlement` page is explicitly labelled **not active** for real payment and zeroing; read-only monthly preflight exists but not financial execution. Several administration actions are role-bound or partly read-only.
- The original independent design-review HTML still contains **visual fixtures**; it is separate from authenticated live app. Its presence is NOT proof any route is live-backed.
- New verified frame condition can show only a ring and icon while no actual frame artwork URI exists in official catalog.
- Cannot certify **every button on 41 screens + 27 dialogs** without real manual navigation across role-specific flows. CI covers defined contracts and browser paths, not every Android input, permission, or backend side effect.
- No verified simultaneous two-phone LiveKit mic audio test, end-to-end actual 7,000-coin gifts or live OAuth/password reset on target phone, admin banner publish/unpublish visual confirmation, or production rollback drill.

## Tonight's mandatory hands-on acceptance

| Test | Expected evidence (record actual PASS / FAIL) |
|---|---|
| Real sign-in | Valid and wrong credentials, Google if enabled, forgot/reset password and no redirects to external admin unintentionally |
| Two real users / Android | Each joins/leaves same room, takes/releases a mic, muted/unmuted and real sound & speech halo on two phones |
| Real seated identity | Different users' name/avatar; user with active VIP and with no VIP; equipped/un-equipped/expired frame; gifted vs no gifts count (real transactions only) |
| Gift drawer geometry | Open/reclose and swap `gift`, `luck`, `cp`, `nation`, `custom` tabs at 320×720, 360×780, 390×844, 440×915, 360×570. Box never expands or collapses with item count; room remains visible; successful real send once authorized |
| Public support ticker | Real audited settled 6,999 does not show; 7,000+ in a **single transaction** does; no gift is fabricated for testing |
| Home real banners | With zero published banners: none displayed. Owner publishes via My > Admin center: real banner visible. Archive/unpublish or expiry: disappears |
| User vs admin roles | Ordinary user sees no management entry; authorized Owner/partner/DB/CS see only permitted sections; forbidden RPCs fail server-side |
| Every key user button | Navigation, room search, room create/join, contacts, profile edit, gifts, wallet, CP, notifications, safe back/close under Android |
| Every authorized admin button | Search, paginated lists, staff, agency/host scope, user moderation, GIFTS/VIP, banner upload, save/delete, status, audit, no unauthorized financial actions |
| Reliability | Poor network, background/resume, logout/login as different user, small screen, font scaling, keyboard/safe-area, no blank screens/crashes |

Do not assert unsupported features are live. Mark unimplemented features intentionally unavailable and either defer them from beta scope or implement and re-test them. If a critical test fails, remain NO-GO; no APK or production merge until final review.

## Acceptance opinion
**Controlled invite-only hands-on UAT:** reasonable as the next step once an updated Staging build is verified.  
**Public beta / app-store customer release:** **NO-GO pending manual results and closing critical gaps.**
