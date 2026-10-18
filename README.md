# TotiChat — Project 01 (Backend preserved + new Flutter beta client)

This is the active `rebuild/flutter-v1` development branch.

## Status
- Supabase server SQL/functions/tests retained under `supabase/`.
- A **new** Flutter/Dart beta scaffold was added under `flutter_app/` on 2026-10-19, based only on the user's approved external visual source: https://github.com/mrbalmain11-star/- (main).
- The previous Web, Capacitor, Flutter, Kotlin-demo and historical UI assets remain deprecated and are **not** the visual authority.
- Current client code implements a preliminary real-auth / real-room vertical slice, **not a working signed-off Android beta**.
- Evidence and limitations: [Slice 01 status](docs/FLUTTER_BETA_SLICE_01_20261019.md), [scope and gates](docs/BETA_FIRST_EXECUTION_PLAN_20261019.md), [Flutter setup](flutter_app/README.md).

## Safety boundaries
- Supabase Staging only: `rziaedugbdwefbefcxjt`; no remote migrations or production writes.
- Never point the Flutter client at production; initialization fails closed for any URL other than Staging.
- Never expose a Supabase service-role/secret key to a client.
- Do **not** build an APK/AAB or deploy to stores without owner's explicit approval.
- Previous full-repository recovery branch: `backup/pre-backend-only-20261019`.
- Previous external preview sites are not automatically disabled by this Git change; disable/protect them separately when access is available.
- No simulated user, wallet, gift, advertisement or presence state is permitted in LIVE mode.

## Pending
Flutter SDK/analyzer/tests, platform host files and OAuth deep links, real-account/device QA, 15-seat interactions and voice, realtime chat, wallet/gifts, admin controls and exact design parity.
