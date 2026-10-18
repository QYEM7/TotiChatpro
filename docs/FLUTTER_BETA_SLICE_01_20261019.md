# TotiChat Beta Slice 01 — 2026-10-19

## New client code (committed)
- `flutter_app/` created on `rebuild/flutter-v1`; no legacy UI, Web, Capacitor or Kotlin prototype imported.
- Flutter/Dart: Google-only OAuth, Staging-locked Supabase initialization, verified-session RPC gate, real rooms/banners, room join/leave RPCs, 15 server-defined seat slots with member name/avatar, and real public-ID lookup.
- Visual cues follow approved `mrbalmain11-star/-` React source, particularly AuthScreen, Header, HomeView, RoomCard and VoiceRoomModal. This is an initial structural port and **not** signed-off screen parity.
- No fake users, room listeners, banner ranks, wallet balances or gifts in live code.
- Explicit waiting/error/empty states in the client. All Arabic UI copy separated into `assets/i18n/ar.json`.

## Direct Staging read-only verification (2026-10-19)
Project `rziaedugbdwefbefcxjt` was reported `ACTIVE_HEALTHY`.
Verified as **present**:
- public tables: `rooms`, `room_members`, `profiles`, `home_banners`, `account_special_ids`;
- columns: `rooms.cover_path`, `rooms.image_revision`;
- RPCs: `phase4_verified_session`, `phase2_room_join`, `phase2_room_leave`, `phase2_room_members_visual`, `phase5_special_id_status`;
- authenticated EXECUTE on those five RPCs; SELECT grants on `rooms` and `home_banners`;
- RLS enabled on `rooms` and `home_banners`.

These are **contract/existence checks**, NOT an authenticated, two-account, APK, voice or visual acceptance test. No Staging writes or migrations were executed.

## Blockers for slice 01 acceptance
- Flutter/Dart SDK is unavailable in the current execution environment. No `flutter analyze`, `flutter test`, or actual Android host generation was executed.
- Android manifest still needs native deep-link registration and verification of the Staging redirect allowlist, before testing OAuth. No Android APK may be built without owner approval.
- No real account sign-in, session restoration, room join/leave or two-device QA has occurred in the newly written Flutter client.
- `flutter_app/pubspec.lock` cannot be generated/pinned until `flutter pub get` is run in a Flutter environment; generated native project files are also pending.
- The approved design source is large: banners, animations, overlays, gifts and detailed room presentation are not yet matched pixel-for-pixel.
- New room creation requires owner-uploaded WebP covers and a welcome-message RPC; not in this slice.
- LiveKit voice transport, seat claim, realtime chat, DM, gifts and wallet operations remain unconnected.

## Next delivery gate
Use a Flutter-capable test environment to generate native files, install dependencies, run analyzer and source tests. Verify the OAuth deep link and one real account on Staging once the owner authorizes an Android test build. Then test two accounts joining and leaving, before adding LiveKit audio. Do not declare G1/G2 complete based on static checks.
