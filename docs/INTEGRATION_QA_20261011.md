# TotiChat integration continuation — 2026-10-11
Scoped to GitHub `QYEM7/TotiChatpro` / `develop/phase-2` and the **new** Supabase `sqedsnyvjblvbjbizcay` (not legacy TotiChat).

## Confirmed read-only results
- Initial inspected head: `8cffdffed373d64bce4750b508bbbd6f44ca4415`.
- New Supabase `ACTIVE_HEALTHY`; production `auth.users=0`, `profiles=0`, `rooms=0`, `room_members=0`. No hosted two-account acceptance evidence exists.
- Production recorded **32 applied migrations**, most recent `20261010031301`; source currently has **42 SQL migrations**, leaving **10 pending**. These include avatar, realtime, music, host-month preflight, support, financial/support concurrency and indices. Do NOT deploy blindly before independently verified database and Storage-object restore and isolated hosted staging.
- Google OAuth public flag was `google:true` (Apple/Facebook false) in [read-only GitHub CI run 38086251531](https://github.com/QYEM7/TotiChatpro/actions/runs/38086251531) 2026-10-10 21:05 UTC. This proves provider enabled only; Android callback, consent and real profile creation remain UNVERIFIED.
- The Supabase Edge Function `phase2-voice-token` is deployed as **version 5**, `verify_jwt=true`, but its **deployed index.ts differs materially from source**: GitHub source calls `rateVoiceRequest`, while fetched deployed code does not. Hosted rate limiting therefore cannot be certified. Blindly deploying source also risks HTTP 503 because source limiter requires Upstash Redis; never activate paid tier or bypass server abuse controls. Need a verified zero-cost limiter, safe rollout and source/deployment parity check.
- Firebase registration for `com.totichat.beta` passed offline CI [38087626025](https://github.com/QYEM7/TotiChatpro/actions/runs/38087626025). The FCM SDK, registration/rotation/logout handling, server-only delivery sender and physical push tests are **NOT implemented/verified**. Firebase remains Spark; Analytics disabled.
- Official Cloudflare Pages `https://totichatpro.pages.dev` is online as a landing page and explicitly blocks downloads. Its existence does NOT demonstrate working Android sign-in or audio.
- Supabase has **no persistent staging branches** (read-only branch listing empty). 24 RLS-enabled/no-policy notices include intentional private/revoked tables; they require privilege inspection, not indiscriminate public SELECT policies. Live performance advisor reports five unindexed foreign keys, pending GitHub repair migrations.
- The GitHub release gate remains **63% estimated engineering, 15% real beta**, `release_allowed=false`.

## Source preflight added (NO APK)
`node scripts/check-beta-integrations.mjs --strict-source` and `node --test tests/beta-integrations.test.cjs` check source contracts and preserve the explicit distinction between source preparation and real hosted/hardware success. They do NOT run an Android build, create accounts, touch databases, send FCM, access API secrets or modify deployed Edge functions.

## Prioritized next acceptance gates
1. T49/T03: real offsite backup and isolated restore **including Storage bytes**, then validate 10 migration candidates on independent staging without modifying production.
2. T13: two **real** Google accounts; verify PKCE + native deep link `com.totichat.beta://auth/callback`, profile persistence, sign-out, token refresh and cross-account denial. No fake accounts in production.
3. T19–T21: reconcile/deploy protected LiveKit Edge token issuance only after free verified rate limiting and revocation design; two authorized Android devices verify two-way mic, 15 seats, mute/moderation, Wi-Fi/mobile handover and reconnect.
4. Firebase: pinned Capacitor FCM plugin + lockfile, Android notification permission, secure authenticated device token storage/revocation and server-only sender; verify real foreground/background push, denial of another user's token, and logout/token rotation. No service account key in GitHub/app.
5. T46–T50: 40/50 independent live checks, all nine signed reviewable recovery/security/hardware proofs, real beta and engineering each at least 80%, and **separate explicit Owner approval** BEFORE APK/AAB.

## Invariants
No design changes: 15 seat room, VIP/gift visuals, navigation and approved behavior untouched. No Supabase SQL mutations, deploys or paid service activation. No APK built. Green source CI does NOT unlock release.
