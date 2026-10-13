# TotiChat Home Screen 02 — actual implementation & owner review
Date: 2026-10-14 | Branch: `design/totichat-ui-20261013`
Status: **IMPLEMENTED AND DEPLOYED TO ISOLATED REVIEW HOST; PENDING VISUAL AND REAL-ACCOUNT ACCEPTANCE.**

## Boundary
Owner conditionally approved Login Screen 01 **90%**. This is **not** completion of its outstanding backend Email provider/Android-native gate. Owner subsequently explicitly instructed work to start on Home; continue with Home while preserving Login's open defects. No change to `develop/phase-2`, `main`, production Supabase, current Cloudflare live app, wallet, agency, music or LiveKit.

## Independent preview
**https://totichat-login-review-20261013.vercel.app/home/** (same-origin Login and Home), requiring a verified Google/Supabase Staging session. If user is not signed in, Home redirects to sibling Login. After verified Google login the login screen's approved sign-in state offers a same-origin `Open Home` link. No token is ever copied into a URL.

## UI work
- Mobile-first RTL light pearl/lavender/pink/gold home, falcon vector mark, microphone illustration, embossed tiles, generous ornaments, clean cards, responsive 360–430px and centered desktop.
- Fixed five-position bottom bar with inline vector SVG icons. It does not appear as a fake in-room navigation.
- Home search and public/mine/all filtering operate on current real server-authorized room records; refresh fetches Supabase.
- Admin banners queried from `public.home_banners`, published status only, hidden entirely when no rows; image and expiry guarded by RLS and checked against HTTPS.
- Global gift announcements queried from `public.gift_global_announcements` only with `total_coins >= 7000`, hidden when no rows.
- Room list from authenticated `public.rooms` RLS, no invented viewers/seat counts. Private rooms only visible to their owners/members. Room card shows detail and explicitly refuses to fake a live-voice join until the separately approved Room screen exists.
- Create-room form has title, welcome text, cover image, and optional private toggle. On actual user submit (never by QA/live seed): `phase2_room_create` RPC → authenticated room cover WebP upload → `phase2_room_customize` RPC → server confirmation. Failed multi-step writes are explicitly identified, with the newly created room ID so the user does not inadvertently create duplicates. No broad DB migration.
- Creation blocked client-side when `room_members` shows the current account already occupies another room, mirroring `phase3.phase2_room_create`; DO NOT call `phase2_room_leave` to make room because that function deletes the owner's room.
- CP, agencies, VIP, messages, discover, notifications and full profile are separate screens. Tapping exposes an honest explanation, not synthetic data or falsely functioning controls. The My sheet can perform real current-session signout with remote-revocation warning.

## Staging read-only evidence at implementation
- `public.rooms`: **1**, private, no cover.
- `public.room_members`: **1**.
- `public.home_banners`: **0**.
- `public.gift_global_announcements`: **0**.
- Real logged-in users may see **zero** room cards if RLS does not authorize them to access the private room. This is correct and must not be "fixed" with fake cards.
- Rooms RLS permits signed-in users to read public rooms, their own private rooms, and rooms they have joined. Room members exposes own membership. Home banners reads only currently published rows. Gift events reads for signed-in users. All existing migrations and DB untouched.

## Functional acceptance targets
1. Login using Google → same-origin Home link → navigate to Home without losing session.
2. Header, tiles, room section and nav all render at 360/390/430px without horizontal scrolling or black full-screen overlays.
3. Test Search, All/Public/Mine filters, refresh, room details and screen explainers.
4. Confirm current true data; no banners or gift strip until real qualifying rows exist; private rooms not leaked.
5. Create requires real image/name/welcome and RPC calls; if account is already room member, creation is correctly rejected without deleting room.
6. Return to login and signout from 'My' sheet; no false remote logout success; verify signed out after refresh.
7. Compare actual browser screenshots with owner-approved concept board; obtain explicit visual approval before any Home layout freeze.
8. Test Chrome/Android with actual authorized account; backend functions/banners/gift queries only to **Staging**.
9. Do not move to voice Room screen before Home is accepted separately.

## Honest limits
Actual creation on a real authenticated staging account **requires a user-triggered test**, not an autonomous write. Browser automation uses synthetic data only in intercepted test responses; the published preview never populates mock data. Full voice-room navigation (LiveKit join) is intentionally not implemented in Home. Banner data currently absent and must not be rendered. Login visual stays as approved.
