# TotiChat urgent delivery-recovery QA — 2026-10-21

Scope: user-reported rejected UI after real Google sign-in in Android beta.
**Not a release sign-off or claim of completed application.**

## What the user observed
- The last ARM64 PreferencesFix APK installed and started successfully on a physical phone.
- Google sign-in opened, then a deprecated purple/pink UI with old-looking data appeared; a subsequent attempt returned to sign-in.
- Physical Google OAuth *return into the intended green Flutter package* is **unverified**.
- User expects the light-green Flutter experience, not the old dark/purple React prototype or previously published web UI.

## Code changes under review
Draft PR: https://github.com/QYEM7/TotiChatpro/pull/33
Base: `rebuild/flutter-v1`; **no main or production edits**.

- Added one light green `GreenTheme`, reused by `TotiChatApp` and `HomeScreen`.
- Replaced the deprecated dark/purple Flutter `LoginScreen` with Google-only green entry, retaining real Supabase Staging OAuth.
- Guarded `AuthGate` against duplicate initial-session events and unnecessary token refresh re-verification; retains server-side `phase4_verified_session` gate and identity match.
- Android test launcher label is `TotiChat Green Beta` so testers can distinguish it from old installed builds; Android package remains `com.totichat.beta`. Existing OAuth redirect remains `com.totichat.beta://auth/callback`, avoiding an unapproved Auth allowlist change.
- Added a green-login widget test and release-mode Android 14 two-cold-launch acceptance gates.

## Staging facts verified read-only
- The staging project `rziaedugbdwefbefcxjt` is `ACTIVE_HEALTHY`.
- The DB currently contains **0 public rooms**, **0 published home banners** and **3 user profiles**. No rows were modified, created, hidden or deleted to mask old data.
- `phase4_verified_session()` exists and returns `uuid`; its wrapper calls `phase3.verified_session()`. Real Google account login and post-login routing have **not** been exercised by CI.
- Legacy screens or old populated room data after an OAuth callback cannot be attributed to the current Staging `publicRooms()`/ `activeBanners()` calls without evidence. Inspect the installed package/deep-link handler and any browser PWA if it recurs.

## Required sign-off gates
- [ ] Flutter analyze and tests successful on PR head.
- [ ] Release/AOT Android 14 emulator: login visually green, no native exceptions, two cold starts.
- [ ] ARM64 APK artifact hashes verified and downloaded; **not production-signed**.
- [ ] Physical-device check: launcher displays `TotiChat Green Beta`, Google browser returns to that same app, green home visible; no old purple UI.
- [ ] Kill/relaunch app and confirm persisted Google session, same real account and no logout loop.
- [ ] Real room permissions and 15-seat/voice tests between two physical phones.
- [ ] Gifts and wallet ledger idempotency, Admin Center permissions, no fake data.
- [ ] User explicitly approves build for public distribution; no Play Store deployment.

## Safety
No claims of legal compliance or dispute resolution, no delivery percentage invented,
no mock banners, no production changes or financial table mutations.
Log test evidence and any external acceptance communication in writing.
