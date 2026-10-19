# TotiChat Project 01 — Beta Slice 03: Flutter LiveKit transport (2026-10-19)

## New source implementation
- Flutter uses official `livekit_client` ^2.13.1; existing LiveKit/Supabase token service is unchanged.
- Flutter uses `permission_handler` ^13.0.2 to request Android microphone permission only when a user explicitly activates their mic.
- `lib/src/data/voice_bridge.dart` requests a short-lived authenticated token from the EXISTING `phase2-voice-token` Edge Function and validates WSS, token and matching room ID.
- Listening connection is separate from microphone publication. Enabling the mic requires `phase2_room_set_muted(false)` to pass room membership/seat/moderation checks, then obtains a FRESH server token with `canPublish=true`. Earlier listener-only tokens are discarded.
- Failed publication attempts disconnect locally and attempt to reset server mute; no fake audio or fake success state.
- Disabling mic disconnects and discards the publish-capable connection, then retries as a listener. Leaving room or releasing a seat disconnects local audio.
- `lib/src/screens/room_screen.dart` has explicit listen/connect, mic and disconnect actions, with clear errors and a note that real two-phone QA is still required.
- `scripts/prepare_android.sh` injects Internet, microphone/audio and Google OAuth return permissions/intent into generated Android host source.

## Server checks — read only
Supabase Staging `rziaedugbdwefbefcxjt`:
- `phase2-voice-token` and `phase2-voice-moderate` Edge Functions reported ACTIVE, JWT verification enabled.
- `public.phase2_room_set_muted(uuid,boolean)` and `public.phase2_voice_token_preflight(uuid)` exist and are granted to authenticated accounts.
- `room_members.moderation_muted` exists.
- This does **not** verify actual LiveKit environment secrets, an issued token from a real authenticated account, or a working SFU.

## CI evidence
[Flutter source test run 39181891672](https://github.com/QYEM7/TotiChatpro/actions/runs/39181891672): **SUCCESS**.
- Flutter SDK setup and `pub get`.
- Static analysis of Flutter code/tests including newly added LiveKit client.
- Flutter tests.
- Android host source generation and Google OAuth intent verification.
- Saved source-only Android artifact.
- Explicit safeguard found **zero APK/AAB**.

## Not yet claimed
- NO real Android device OAuth login test, live voice streaming test, 2-device speaking/listening/mute/reconnection test, or background audio QA.
- Server-side LiveKit revocation of stale publishing grants on moderation changes remains a release-safety gate.
- Need verify Staging-only LiveKit URL/key/secret are present and correctly configured before a real audio test; never reuse production secrets.
- Room creation, gift/wallet, complete profile/admin and exact UI parity remain in the beta backlog.

No production or GitHub `main` mutation; no remote SQL migration, Edge deployment, paid service, APK or AAB created.
