# TotiChat Flutter V1 — Verified work log, 2026-10-16

## Change controls
- Rebuilt client code is exclusively on **rebuild/flutter-v1**, directory `flutter_app/`.
- Production Supabase `sqedsnyvjblvbjbizcay` **was not modified**.
- Staging Supabase `rziaedugbdwefbefcxjt` **was not modified** (read-only metadata/security/RPC investigations).
- The current old Reborn app, `develop/phase-2`, and `main` **were not modified** in this work.
- No user balances were created, transferred or reset.
- No APK or AAB was produced or released.

## Flutter modules implemented as source
- Google-only PKCE login, new light Flutter application and Falcon branding (OAuth return URI still needs staging Auth allowlisting).
- Home, discovery, **real** public room list, live published banners.
- 15-seat room, real join/leave/mute RPCs, real room messages and authenticated LiveKit voice grant.
- Room creation requires name, gallery cover image converted to WebP, welcome; uses Storage owner RLS and `phase2_room_customize`.
- Private room invitation creation and joining with authenticated server token.
- Real-time subscribed room messages/members, infrequent fallback refresh; gift announcements from real inserts, with global 7000-coin threshold and 11-second visibility.
- Direct text-message inbox and threads, mark-read; social member search and follow.
- CP state and requests, agency request form, support tickets.
- Gift bottom sheet in live room, recipient and fixed quantities 1/7/17/77/777, confirmed and server-idempotent gift transactions; Lucky Gifts deliberately not exposed without approved client/API semantics.
- Store and server-confirmed purchase RPC, existing inventory, VIP state, gift history and notifications.
- Self profile editor (ownership-constrained RLS) and account deletion support ticket request.
- Admin Center only linked on **My** and when `phase3_admin_session` grants access; reports require server permission. Host-agency section not exposed for ordinary admins.
- No hard-coded mock room IDs, coins, wallet values, banners or event streams.

## Important launch blockers — not yet complete
1. **Native OAuth setup and device test:** add `com.totichat.next://auth/callback` to **Staging** redirect URLs, verify Google credentials and real Android browser-to-app return.
2. **Real two-phone audio QA:** join/leave, speaker routing, microphone grants/revocation, reconnection, Bluetooth/earpiece behaviour and echo must be tested on devices.
3. **Backoffice parity:** staffing, recharge agent operations, salaries, treasury, host settlement, advanced moderation, admin approvals and auditing screens are not fully implemented in new Flutter UI.
4. **Room advanced UX:** minimize with persistent audio, shared licensed music playback/synchronisation, full VIP framing, animated vehicle/entrance/gift assets, Lucky Gifts and other complex animations are pending.
5. **Games:** server has room game RPCs; Flutter game UX is not complete.
6. **Financial live E2E:** transactions use real preexisting APIs, but bank/payment flows, duplicate request retries, permissions, refunds and Play billing compliance require testing with safely provisioned test accounts.
7. **Account deletion:** support ticket exists in-app; completion mechanism, public web deletion form and retention policy still need implementation.
8. **Production schema drift:** production is still missing parts of staging public schema/RPCs and production Owner binding. Back up and review before migration; never copy staging user balances to production.
9. **Build/release:** no signed Play App Bundle, no signed release, no Play Console review, no real-user pilot.
10. **Performance:** Flutter source tests are not load tests; Supabase free quotas and LiveKit free minute budget need monitored operational constraints.
11. **Visual acceptance:** live room/store/profile polished design still awaits direct user evaluation and refinement.

## QA
- Flutter analysis and architecture/widget tests are run by `.github/workflows/flutter-v1-check.yml` on this branch.
- Source compilation is not evidence of actual OAuth, payments, live user concurrency, or a production release.
- **No public distribution is authorized** from this source revision.

## Backend interfaces checked
`phase2_room_create`, `phase2_room_customize`, `phase2_room_join`,
`phase2_room_take_seat`, `phase2_room_set_muted`, `phase2_dm_inbox`,
`phase2_dm_send`, `phase3_send_gift`, `phase3_purchase_store`,
`phase4_cp_action`, `phase4_agency_action`, `phase5_support_action`,
`phase5_notification_feed`, `phase3_admin_session` and others were checked
against **Staging** SQL function names/signatures.
