# TotiChat Admin Dashboard — Staging only

Standalone responsive RTL management website, not part of the consumer mobile app.

## Implemented
- Premium responsive light cream/green/gold UI with the exact approved falcon logo and icon copied to admin-dashboard/assets.
- Real Supabase Auth email/password login and GitHub OAuth PKCE flow. Account authorization comes from the phase3_admin_session server RPC.
- Private Owner/main-partner Banner Studio powered by real phase6_admin_banner_list and phase6_admin_banner_action RPCs.
- Image-only upload: input JPG/PNG/WebP, convert and crop to 3:1 WebP, compressed to <=512000 bytes. No GIF or video. Staging storage enforces matching limits.
- Scheduled banner publication, sorting, controlled internal app routes, drafts/archives, and audited changes.
- Real KPI reports, read-only financial reconciliation, host/recharge agency state, gift catalog, medal catalog, VIP lookup and support API integration.
- User/room moderation pages are honest integration stubs, with no fake users, balances or functioning-looking destructive buttons.

## Local source viewing — no build
Serve repository root using python3 -m http.server 8080 and visit http://localhost:8080/admin-dashboard/.
To test GitHub login, allowlist that URL in Supabase Staging Auth redirect URLs. Email/password requires an existing verified Staging admin account.
Sessions reside only in browser memory, not localStorage. Refreshing the page requires login again.

## Security
- Only Supabase STAGING rziaedugbdwefbefcxjt; no production/database main changes.
- Browser uses only a publishable key; privileged actions enforced in Postgres.
- No app release, APK, Vercel deploy, public dashboard URL or data seeding.
- Banner images can only be removed when unreferenced; replacing a photo may leave old unreferenced assets pending cleanup.

## Repository separation
The available GitHub connection cannot create a new GitHub repository. The isolated website lives in admin-dashboard/ on develop/phase-2 as a temporary source home. Its assets and runtime are self-contained and can be moved to an independent GitHub repo when created.

## Still incomplete
Admin E2E/device testing, social login allowlist for the final domain, real authorized upload flows with an owner account, role-management UX, user/room moderation RPCs, actual staging audio, production cutover and release approval are NOT complete.