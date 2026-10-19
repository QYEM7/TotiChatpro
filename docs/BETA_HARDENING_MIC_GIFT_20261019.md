# TotiChat Project 01 — Room microphone and global gift feed hardening

Date: 2026-10-19  
Branch: `rebuild/flutter-v1`  
Environment: **Supabase Staging only** (`rziaedugbdwefbefcxjt`)

## Source changes

1. **Re-evaluate microphone authority on each room-member refresh.**
   `RoomScreen._reload()` now uses `_loadMembers()` instead of bypassing it with a raw repository call. The 10-second refresh and user-initiated refresh therefore inspect the current server-reported member list. If the local mic is on but the current user no longer owns an unmuted seat, the client disconnects local LiveKit transport and does not advertise an active mic.
2. **Isolate and test the client-side eligibility predicate.**
   `RoomMicrophonePolicy.mayPublish` requires a current user ID, an occupied seat, and `isMuted=false`. Five source tests cover legitimate occupant, muted member, revoked seat, different user, and lost session or membership.
3. **Apply the global gift threshold before limiting results.**
   `GlobalGiftFeed.watch()` now applies a Supabase stream `.gte('unit_price', 7000)` before `.order(...).limit(10)`. Retains the secondary client check. Low-price recent gifts can no longer crowd qualifying settled announcements out of the initial latest-ten query.
4. **Make debug APK creation manual.**
   `.github/workflows/flutter-beta-apk-staging.yml` now triggers only via `workflow_dispatch`, not every Flutter source push. `flutter-beta-checks.yml` remains automatic on changes to `flutter_app/**`. Earlier runs that were already triggered before this change are not retroactively cancelled by the workflow edit.

## Trace

- Microphone policy: `664958ecbe543376569dcaae20a71e88dc850df4`
- Room refresh wiring: `685140b58cd9b30ed42ac6d2cf2d0cd4c0e39c16`
- Five unit tests: `2fe466d9ba4f6cceca7bfee42209b9db763b0198`
- Manual-only APK workflow: `a43c66baf3ad6c088ff7c88bd5be8616a7ed95b7`
- Gift threshold query fix: `003242e3467b62debac4f458d43d3b7495e02a84`
- Source check for gift fix: https://github.com/QYEM7/TotiChatpro/actions/runs/39315053498 — **SUCCESS**: Flutter analyze, Dart/Flutter tests, Android OAuth host preparation and no-APK guard all passed.

## Still unverified

- Two-device microphone revocation and room audio tests. A client-side 10-second polling safeguard is **not equivalent** to server-side LiveKit SFU publish-permission revocation. Investigate the existing server token/moderation contract before certifying moderator enforcement.
- Real Google OAuth return to Android, two-account room/seat/chat/DM flows, and financial concurrency, rollback, and ledger reconciliation on Staging.
- Approved design screenshot parity and final owner acceptance.

No production or `main` writes, no Staging migrations or seed transactions, no release deployment, and no claim of 90% release readiness were made during this patch.
