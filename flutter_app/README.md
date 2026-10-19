# TotiChat Flutter — Beta-first client

**Status:** Dart analyzer, unit tests and Android **source** generation passed in [GitHub Actions run 39181633594](https://github.com/QYEM7/TotiChatpro/actions/runs/39181633594) on 2026-10-19. **No APK/AAB or real device test has been performed.**

## What is genuinely connected in source
- Google-only Supabase OAuth; authenticated session verified through `phase4_verified_session` RPC.
- Live public rooms, real published banners, room membership and 15-seat visuals (no fake listeners).
- Seat reservation/release through the protected `phase2_room_take_seat` RPC.
- Room text messages through `phase2_room_send_message` and member-scoped realtime stream.
- Real account display name and an owner-assigned public ID status (no random visible ID).
- Safe errors/empty states; never display mock room, chat, banner, coin, gift or wallet data.

Only the **new approved visual repo** `mrbalmain11-star/-` (`main`) is used as a presentation reference. Screen-by-screen visual parity is **not signed off**.

## Generate Android host source without building an APK
A current stable Flutter SDK with Dart 3.9+ is required.

```sh
cd flutter_app
flutter pub get
flutter analyze lib test
flutter test
bash scripts/prepare_android.sh
```

The final command generates `android/` native files and injects the dedicated Staging OAuth return intent filter plus required Internet/microphone permissions. It is **not** a build command and does **not** test a phone.

A zipped Android host **source-only** artifact is available from the successful GitHub Actions run above, subject to its artifact retention period. Do not confuse that artifact with an installable Android application.

## Staging configuration
The client is restricted to `https://rziaedugbdwefbefcxjt.supabase.co`. The project supplies an intentionally **public publishable** key (not `service_role` or `sb_secret`) so no hidden configuration is needed for basic source initialization. A different `SUPABASE_URL` supplied at build-time fails closed; the publishable key can be overridden safely using `SUPABASE_PUBLISHABLE_KEY` at development time. Never expose a secret server key in client code.

The Google Auth provider and `com.totichat.beta://auth/callback` allowlisted Redirect URL must still be verified against the live Staging configuration, followed by actual consent and deep-link tests on a device.

## Not yet functional/verified
- Android real-account login/restore, RLS under two different accounts, joined-room/seat/message integration.
- Room creation including image upload + welcome form.
- Flutter LiveKit audio engine and real-device two-way voice/mute/reconnect.
- DM, gifting, wallet, admin actions, VIP/CP and visual parity with the approved source.
- Release/security gate acceptance and owner-authorized APK build.

**Rules:** no production DB or GitHub `main` changes, no direct client service-role access, no APK/AAB or production publication before explicit owner approval.
