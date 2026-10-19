# TotiChat Project 01 — Voice moderation beta gate

Date: 2026-10-19  
Branch: `rebuild/flutter-v1`  
Environment: Supabase Staging (`rziaedugbdwefbefcxjt`)

## Confirmed existing defect

The Flutter room moderation repository previously invoked `public.phase2_room_moderate` directly for every room moderation action. That RPC changes database membership/mute state but **does not disconnect the existing LiveKit participant**. A successful DB result therefore was not sufficient evidence that a currently transmitting microphone had stopped.

The active Staging edge function `phase2-voice-moderate` checks the user JWT, calls the authenticated moderation RPC, and then invokes LiveKit `RoomServiceClient.removeParticipant`. Its success payload asserts `databaseCommitted=true` and `sfuDisconnected=true`. Its failure payload may say `databaseCommitted=true, sfuDisconnected=false, retryWithSameRequestId=true`. These contracts were inspected read-only.

## Fix committed

- `mute`, `release_seat` and `kick` now call `phase2-voice-moderate` rather than only the public RPC.
- Only a 200 result with exact room/target/action, `success`, `databaseCommitted` and `sfuDisconnected` is accepted.
- `allow_mic` remains a DB-only permission update. It cannot autonomously enable anyone's microphone; the user must opt in and acquire a fresh token.
- Failed attempts retain the same UUID within the room screen's repository instance, preventing a new database moderation operation for the same retry payload.
- The screen keeps one repository instance and rejects concurrent moderation attempts.
- Seven contract tests assert success, mismatched result, SFU disconnect failure, malformed result, and unmute permission checks.

## Critical unresolved SERVER authorization gap

A read-only Staging privilege query on 2026-10-19 showed:
- `authenticated`: EXECUTE on `public.phase2_room_moderate(uuid,uuid,text,uuid,text)` **true**
- `anon`: EXECUTE **false**

As a result, a technically capable authenticated moderator could still call the public RPC directly and bypass the LiveKit disconnection relay. The Flutter fix protects normal app flow **but does not close the server-side bypass**. Before release, redesign the moderation authority so voice-impacting actions cannot be committed through a public DB-only endpoint, while preserving actor authorization and idempotency in a backend-only path. Restricting the current RPC prematurely would also break the existing Edge Function, which calls it with the user's JWT. Do not revoke the grant blindly.

Also unverified: a participant absent from LiveKit may cause `removeParticipant` to return an error even when the DB moderation commit succeeds; test this and handle safely rather than falsely reporting full voice disconnection.

## Required device acceptance

1. Connect two Android phones with two distinct verified Staging accounts; confirm normal talk/listen, mute and rejoin.
2. From room owner: mute a participant **while their microphone is actively transmitting**. Verify the audio stops at the SFU and on the receiving phone, not only in the DB.
3. Retry moderation after a simulated lost HTTP acknowledgement with the same request UUID; inspect the single authoritative DB request plus SFU state.
4. Test kick and release seat while mic is live; verify reconnect receives only server-authorized permissions.
5. Test allow_mic: the owner cannot enable somebody else's mic, but the participant can voluntarily unmute after approval.
6. Test permission-denied moderation from a non-owner account and offline target, with truthful feedback.
7. Close the server API bypass before release. Repeat both honest-client and direct-RPC security tests after the fix.

No Staging schema/data mutation or Edge Function deployment was made in this work. No production branch or production app was changed; this is not device acceptance and not 90% release readiness.


## Verified source CI

- [Flutter beta source checks — run 39317157664](https://github.com/QYEM7/TotiChatpro/actions/runs/39317157664) **SUCCESS** on source commit `d515a8b734230523ab42dcc66b9ba8ccbf273f38`.
- Flutter analyzer, Flutter/Dart tests (including the seven new moderation response tests), generated Android OAuth host-source validation, and no-APK guard all passed.
- This is a source-level test, **not** evidence that an actual remote moderator mute/LiveKit SFU disconnect works on Android.
