# TotiChat — Project 01 (Backend preserved + new Flutter beta client)

This is the active `rebuild/flutter-v1` development branch.

## Status
- Supabase server SQL/functions/tests retained under `supabase/`.
- A **new** Flutter/Dart beta scaffold was added under `flutter_app/` on 2026-10-19, based only on the user's approved external visual source: https://github.com/mrbalmain11-star/- (main).
- The previous Web, Capacitor, Flutter, Kotlin-demo and historical UI assets remain deprecated and are **not** the visual authority.
- Current Flutter source includes Google OAuth, backend-verified sessions, room directory, 15-seat RPCs, authenticated realtime room text and a new **LiveKit Flutter voice transport** bound to the existing staging token authority. All are **source-level implementations, NOT a working signed-off Android beta**.
- Evidence and limitations: [Slice 01 status](docs/FLUTTER_BETA_SLICE_01_20261019.md), [scope and gates](docs/BETA_FIRST_EXECUTION_PLAN_20261019.md), [Flutter setup](flutter_app/README.md).

## Safety boundaries
- Supabase Staging only: `rziaedugbdwefbefcxjt`; no remote migrations or production writes.
- Never point the Flutter client at production; initialization fails closed for any URL other than Staging.
- Never expose a Supabase service-role/secret key to a client.
- Do **not** build an APK/AAB or deploy to stores without owner's explicit approval.
- Previous full-repository recovery branch: `backup/pre-backend-only-20261019`.
- Previous external preview sites are not automatically disabled by this Git change; disable/protect them separately when access is available.
- No simulated user, wallet, gift, advertisement or presence state is permitted in LIVE mode.

## Current proof and pending gates
- Flutter SDK, dependencies, static analysis, unit tests and **generated Android host source** passed on [CI run 39181891672](https://github.com/QYEM7/TotiChatpro/actions/runs/39181891672). No APK/AAB was built.
- See [Beta Slice 03 voice report](docs/FLUTTER_BETA_SLICE_03_VOICE_20261019.md).
- Still required: real Google login/deep link on Android; two-account rooms/seats/chat; two-phone LiveKit audio/reconnect/mute; configure and verify Staging LiveKit secrets; room creation and genuine image upload; gift/wallet/admin; exact visual comparison and release approval.
