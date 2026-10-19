# TotiChat Flutter beta — Project 01

**Only the newly approved visual source**: [mrbalmain11-star/-](https://github.com/mrbalmain11-star/-) (main). Historic UI/Web/Kotlin demo sources are rejected. Flutter/Dart is the native client; production backend and GitHub `main` are untouched.

## Source-level beta functionality
- Google-only Supabase OAuth and verified-session RPC gate; mobile OAuth callback has not been tested.
- RLS-scoped Home, published banners (hidden when absent), public room directory.
- Real create-room form (room name, welcome text, owner WebP cover) with server RPC, verified upload and cleanup.
- Join/leave room, fixed 15 seats, seat claim/release, member refresh, room minimize/resume using an Offstage-preserved RoomScreen state. Room audio does not intentionally disconnect when minimized inside the app.
- Existing server-authorized LiveKit voice-token contract connected through Flutter LiveKit SDK; seat+mic authorization checked, local audio disconnected on exit/revoked seat/background transition.
- Room realtime messages, private DM overlay/inbox, wallet RLS read, real gift catalog and server-authoritative gift send (expected unit price and idempotency UUID).
- Real, settled global gift feed only for unit price >= 7000; empty if Staging contains none.
- Owner-only room moderation UI with backend-confirmed mute/release/kick.
- Profile-only server-gated read-only admin entry. Advanced admin actions are intentionally not exposed.
- UI text kept separately in `assets/i18n/ar.json`, no Arabic embedded in Dart business logic.

## Flutter source checks (no installable application)
GitHub Actions workflow [flutter-beta-checks.yml](../.github/workflows/flutter-beta-checks.yml) installs Flutter, runs `flutter pub get`, `flutter analyze lib test`, `flutter test`, generates Android source, validates OAuth callback and permission markers, archives Android **source only**, then asserts no APK/AAB was generated.

In a current stable Flutter environment:

```bash
cd flutter_app
flutter pub get
flutter analyze lib test
flutter test
bash scripts/prepare_android.sh
```

The script generates `android/` and registers `com.totichat.beta://auth/callback`, Internet/RECORD_AUDIO/MODIFY_AUDIO_SETTINGS permissions and minSdk 24. It does not build an APK.

The only allowed backend in this beta branch is Staging `rziaedugbdwefbefcxjt`. Client uses its public publishable key, **never** a service role/secret key. Client initialization fails closed if a different Supabase URL is supplied.

## Do not claim release readiness
Important missing device and acceptance gates: real Google login/deep link, multi-account join/seat/DM, two-phone audio, Staging LiveKit credentials and moderator SFU revocation, genuine gift/wallet concurrent tests, precise approved UI screenshot parity, minimum operational admin safety and user's explicit APK/release approval. Source compilation is NOT a measure of release readiness.

See [release readiness evidence](../docs/BETA_RELEASE_READINESS_EVIDENCE_20261019.md) for G0–G6 status. No APK/AAB and no staging writes in this ChatGPT execution.
