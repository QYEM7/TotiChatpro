# TotiChat (Project 01) — Release readiness gate
Date: 2026-10-19
Branch: `feature/approved-ui-flutter-v1`
Approved design source: https://github.com/mrbalmain11-star/-

## Real implementation
- A new Flutter/Dart client isolated from all previous UI copies.
- Google OAuth via Supabase Staging; no fake login.
- Staging rooms, 15 seats, room chat and LiveKit token transport.
- Realtime notifications of room members/chat changes (RLS applies).
- Private text DM and user lookup, notifications, CP, agency registration/joining.
- Catalog-based store purchases and gift confirmation using expected server prices and idempotency tokens.
- Real profile, wallet read, VIP status, support ticket creation, admin access read check.
- Newly saved room welcome message; an explicit voice retry button for weak networks.
- No fake rooms/banners/VIP levels or placeholder wallet amounts.

## Release blockers — not optional
1. **Two real Android devices**: authenticate with Google, enter the same room, verify join/leave/mic/seat/reconnect/echo/minimize/music and notification behavior over real networks; no test passed yet.
2. **Financial signed-in testing**: verify eligible gifts, balance ledger, insufficient funds, repeated request id, price changes and store purchase refund/reconciliation. No live financial transactions executed as part of this change.
3. **Visual parity**: the user-approved React source contains many screens and full visual assets. Flutter currently includes a subset: exact screenshots for every modal, GIF, VIP frame, effects, CP cards and gifts have NOT been compared/accepted.
4. **Incomplete functional screens**: actual admin report/actions, recharge agent order flow, advanced agency management, VIP animated visuals, music playlist synchronization, avatar/room cover upload, global gift announcement strip, unlucky/lucky gift UX, full CP visuals, private room invitation UI, moderation UIs, and privacy/account controls are NOT fully integrated.
5. **Supabase/Auth staging**: confirm Google OAuth redirect, Google provider and token expiration on Android before release; no real mobile-login assertion yet.
6. **Release packaging and store**: debug/staging test builds are not production release signing. Production secrets, Play upload, signing identity, store listing and final policy checks are not done.
7. **Deployment**: previous external legacy previews are not confirmed disabled. Production and `main` are untouched.
8. **Accessibility and bandwidth**: approved images are fetched from the public source via HTTPS rather than shipped in an offline-optimized asset package; test slow networks and image cache.

## Read-only backend smoke evidence
- Supabase Staging project active; both voice token/moderate Edge Functions ACTIVE.
- Database contracts exist for DM, gifting with price confirmation, agencies, CP, VIP, store, support, notification and admin.
- Authentication role can execute those RPCs; per-actor permission is still enforced by server.
- Database inspection found zero negative wallets and zero pending financial operations at inspection time.
- Published home banners=0; public rooms=0; 12 active gifts. Do not replace the empty state with mocks.
- Security advisor findings: RLS-no-policy informational items on intentionally RPC-only tables; leaked password protection warning. Review affected tables and Auth features before rollout.

## Decisions
- Keep the new approved design as the ONLY visual reference.
- Do not merge this branch into `main`, redirect existing production clients, fund agent wallets or open production registrations yet.
- Build testing APKs only from this branch and label every download **Staging Alpha**.
- Never state `ready for final release` until the critical real-world checks above are completed.

## Latest implementation check (code commit `1fa48a3`)
- Flutter QA passed: https://github.com/QYEM7/TotiChatpro/actions/runs/39173501166
- Realtime inbox, DMs and user notifications now subscribe to RLS-approved tables.
- Users can block/unblock other DM accounts through server RPC with confirmation.
- Real support ticket threads, replies and authorized staff-only ticket statuses are exposed in Flutter.
- The global 7000+ coin announcement strip listens to actual server-created events and auto-expires after 12 seconds. Backend staging threshold was confirmed enabled at 7000.
- Audio publishing is stopped before moving or releasing the speaking seat, and minimized room membership is cleaned up on logout.
- Actual Flutter asset and APK builds remain separate from runtime acceptance checks.
- Backend has `room_music_queue` and `user_music_bookmarks` tables, but **no verified public music RPC exists** in the current Staging catalog. Music synchronization is not ready.
- No full end-to-end signed-in user journey, purchase ledger verification, or two-device LiveKit voice session was run.
