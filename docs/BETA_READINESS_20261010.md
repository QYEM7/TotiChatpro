# TotiChat Beta Readiness Audit — 2026-10-10

## Verified sources
Legacy reference database: 30 experimental accounts, Google identities in all 30 cases. Its React/Capacitor code used Google OAuth + PKCE and Android deep links. Legacy data is not imported.

New independent backend: zero new accounts, profiles, rooms or wallets. Three official banners exist. Email/password account API, room directory/chat/seat booking and read-only zero-balance wallets are wired but not yet verified on two real Android devices.

## Login correction
- New RTL mobile-first Login, official falcon logo, no bottom navigation or demo banners.
- 50/50 split form/art on desktop; single form column on Android.
- Live email/password and signup endpoints. Show/hide password, password recovery, remember me, status/loading.
- Social login buttons must report provider availability; unconfigured providers stay disabled, not simulated.
- OAuth return link prepared for Android, requires registered callback and enabled social providers.

## Critical release blockers
1. A custom SMTP sender is needed for ordinary tester signups and email recovery. Supabase default service only serves approved organization email addresses with restrictive rate limits.
2. New Supabase Google/Apple/Facebook OAuth configuration and callback allow list are not verified.
3. Server-based group voice is absent. A TURN/SFU provider and server-generated participant tokens must be configured and tested.
4. Gift wallet mutations, coin agent top-up, VIP/CP, store, music sync, games, agencies/payroll and Owner dashboard are not fully integrated.
5. No end-to-end real-account, two-physical-device, live audio or 30-day soak test has passed.
6. Eight authenticated SECURITY DEFINER room functions need adversarial access tests. CI green is not a security audit.

## Month-long test gates once ready
Days 1–3: signup/email/recovery/OAuth and second phone.
Days 4–10: public/private rooms, 15 seats, real voice across Wi-Fi/4G, reconnect.
Days 11–17: wallet/ledger/gifts and permission fraud tests.
Days 18–23: VIP/CP, music/games, agents and host agency payroll.
Days 24–28: performance, accessibility, background/foreground, memory and OS compatibility.
Days 29–30: regressions, database backups, rollback and Owner acceptance.

## Decision
Do not label the debug APK a complete 30-day voice-chat beta before the gates pass. Do not merge the development branch into approved main without owner acceptance. Never add demo members, fake balances or fake audio to real user journeys.
