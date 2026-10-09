# TotiChat — Phase 2 technical decision and risk controls
Date: 2026-10-10

## Owner-approved scope

- Phase 1 approved UI/UX commit: `e19707abbca40f62b4494c2d95c1187dd7c27b08`.
- Never rewrite the interface from the legacy React app. The currently approved
  `app/index.html`, CSS, JS, 27 reference image assets, gifts, VIP decorations,
  navigation and all 15 microphone seats remain the visual source of truth.
- User confirmed **all data in the old TotiChat database is experimental**.
  No users, balances, transactions, IDs, rooms or roles migrate from legacy.
- Old repo `jsjsnsnsnsn0-pixel/TotiChat` and old Supabase project
  `bfadhdnudmsggylunhlh` are READ-ONLY engineering references, not runtime
  dependencies. Do not use their URLs or IDs in new application configuration.
- Phase 2 backend: existing independent `TotiChatpro` Supabase project
  `sqedsnyvjblvbjbizcay`, with existing official-banner functionality preserved.

## Engineering decisions

1. **UI runtime:** Retain the approved HTML/CSS/JavaScript. Wrap exactly these
   files in **Capacitor** for Android, instead of rewriting them in React. A
   framework migration is unnecessary and would greatly increase UI regression risk.
   Modularize behavior behind testable service adapters over time.
2. **Backend:** Build minimal, isolated, RLS-controlled schema changes inside the
   new Supabase project. Never directly import the old database or reuse its
   elevated permission functions without a complete security review.
3. **Authentication first:** Start with new auth users and private-safe profiles.
   Presently static counters, demo memberships, demo account balances and room
   previews must NOT be labelled real data. A staged frontend integration will
   replace fake values only after server + login/permission tests succeed.
4. **Voice architecture:** No claim of working live multi-device audio yet.
   Evaluate a managed SFU such as LiveKit for scaling, reconnects, speaking/
   microphone permission handling, and music before implementation. WebRTC
   signaling alone does not guarantee connectivity behind mobile NAT.
5. **Money and roles:** Never derive gold, diamonds, VIP, inventory, paid gifts,
   settlement or moderation privileges from client-supplied numbers/flags.
   Implement atomic server-side transactions, audit trails, RLS and idempotency.
6. **Controlled rollout:** Develop in `develop/phase-2` or feature branches.
   Hold `main` and `release/uiux-v1-approved` at the approved visual baseline.
   Do not merge to main or advertise APK readiness without visual regression,
   client/API checks, real-device verification and explicit owner review.

## Acceptance gates (ordered)

- A. New project identity: secure `profiles`/Auth and RLS; read-only live banners unchanged.
- B. Approved UI APK/web package reproducible from unchanged source files.
- C. Login, session recovery, profile reads/writes (real accounts, no legacy data).
- D. Real room membership, public/private room permissions and 15 seat states.
- E. Room audio, device tests, moderation, messaging and music.
- F. Wallet, gifts, store, VIP, CP, agency, diamonds/month-end settlement.
- G. Dashboard with separated Owner/staff roles and complete audit.
- H. Android beta signed/installable/tested with repeated clean-install and upgrade tests.

## Current limits

A successful CI browser capture is not an Android functional test.
GitHub branch protection still needs repository settings configured; branch
names alone do not block force pushes. No app service-role credential may be
shipped in a browser, APK or public repository.

This document is a design decision and checklist, not a production readiness certificate.
