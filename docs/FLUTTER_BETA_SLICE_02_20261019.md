# TotiChat — Flutter Beta Slice 02 (2026-10-19)

## Scope
New, owner-approved Flutter/Dart client on `rebuild/flutter-v1`, with ONLY `mrbalmain11-star/-` (`main`) as the visual reference. Retired UI and prototype mock operations remain prohibited.

## Implemented source in this slice
- `flutter_app/lib/src/data/room_repository.dart`: room seat take/release via `phase2_room_take_seat`, room messages via `phase2_room_send_message`, and row-scoped message stream from `room_messages`.
- `flutter_app/lib/src/screens/room_screen.dart`: 15 numbered seats, server-confirmed seat tapping, occupant handling, chat composer and live messages, member refresh every 10 seconds, and exit/owner-close confirmation.
- `flutter_app/lib/src/core/staging_config.dart`: ONLY fixed Staging URL and a Staging **publishable** (public) API key; no service-role/secret token. An explicitly different URL fails closed.
- `flutter_app/scripts/prepare_android.sh`: script to generate native Android host and register OAuth callback `com.totichat.beta://auth/callback` plus explicit INTERNET/RECORD_AUDIO/MODIFY_AUDIO_SETTINGS permissions, without running `flutter build`.
- `.github/workflows/flutter-beta-checks.yml`: GitHub-hosted Flutter SDK, dependency resolution, static analysis, Flutter tests, Android source preparation, temporary source artifact upload. Explicit NO APK/AAB gate. Cancel superseded runs.
- Test fixtures for DTO parsing, account ID and server-backed message model, and Staging guard.

## Staging read-only checks
- Active Staging database project `rziaedugbdwefbefcxjt`.
- `phase2_room_take_seat`, `phase2_room_send_message`, `phase2_room_create` and `phase2_room_customize` exist, with EXECUTE for `authenticated`.
- `room_messages` has RLS and SELECT for `authenticated` and is part of `supabase_realtime` publication.
- Staging `phase2-voice-token` and `phase2-voice-moderate` Edge Functions are ACTIVE with `verify_jwt=true`.

These checks prove presence and grants, **NOT** real logged-in user behavior, audio readiness, LiveKit secrets, or a Flutter device run.

## Verified GitHub CI evidence
- [Run 39181633594](https://github.com/QYEM7/TotiChatpro/actions/runs/39181633594): **success**.
- Flutter SDK installation and `flutter pub get`: passed.
- `flutter analyze lib test`: passed without analyzer findings.
- `flutter test`: passed.
- `bash scripts/prepare_android.sh`: generated Android source and verified OAuth deep-link manifest; passed.
- `flutter-android-host-source` artifact saved (source only).
- No APK/AAB output produced; explicit guard passed.

## Gates still NOT verified
- Native Android deep-link roundtrip through Google consent.
- The passed CI establishes analyzer/unit-test/native-host-source status only; it is not proof of real Android runtime behavior.
- Actual sign-in on real Android devices and secure restored session.
- Two-account room/seat/message end-to-end QA, including dynamic RLS behavior.
- LiveKit token response, actual two-device microphone/voice audio, mute/permission and reconnection.
- Room-create form and genuine owner WebP upload, GIF/VIP/CP, wallet and idempotent gifts.
- Visual comparison with approved source and low-bandwidth loading behavior.

## Protect
Production database and GitHub `main` untouched. No APK, AAB, public preview deployment, schema migration, seeded fake data, wallet minting or paid service initiated.
