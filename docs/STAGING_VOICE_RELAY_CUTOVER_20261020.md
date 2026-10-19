# TotiChat Project 01 — Staging voice-moderation privilege cutover

Date: 2026-10-20. Branch: `rebuild/flutter-v1`.

## Evidence

- The existing public moderation RPC and private `phase3.room_moderation_action` were callable by `authenticated` in Staging on the read-only inspection.
- The Flutter client now uses `phase2-voice-moderate` for `mute`, `release_seat` and `kick`, but an authenticated caller with room moderator privileges could bypass that client and change the DB directly without an SFU disconnect.
- Source fix prepared: [privileged RPC candidate](../supabase/patches/voice_moderation_relay_acl_candidate.sql) + [matching Edge implementation](../supabase/functions/phase2-voice-moderate/index.ts).
- [Security contract CI 39325212067](https://github.com/QYEM7/TotiChatpro/actions/runs/39325212067) passed. This is static validation, NOT a deployed database integration or device test.

## Proposed design

1. Keep `public.phase2_room_moderate` available for non-voice-impacting role actions and `allow_mic`, but reject `mute`, `kick`, `ban` and `release_seat` with `VOICE_RELAY_REQUIRED`.
2. Revoke direct `authenticated`/public access to the sensitive `phase3.room_moderation_action`. Change the public guarded wrapper to `SECURITY DEFINER`, retaining the same `phase3.actor()` session checks and room role enforcement.
3. Add a restricted `public.phase2_room_moderate_voice_relay` callable only by the service role. The Staging Edge function validates the user token with `auth.getUser` and then `phase4_verified_session`, requiring the authenticated user to match token `sub`; the SQL function then rechecks actor/session/MFA and moderator authority.
4. Only after the database action succeeds, the Edge function removes the participant through LiveKit. `revokeTokenTs` explicitly revokes stale tokens for already-offline participants, preventing a false 'participant does not exist' error in LiveKit Cloud. Failure to confirm the LiveKit operation must NEVER return success.

## Deployment requirements — NOT EXECUTED

This is a **coordinated security-sensitive Staging change**. The repository candidate is deliberately kept under `supabase/patches/` rather than an automatically applied migration because no migration CLI or staged integration suite was run during this work.

- Generate an official migration using `supabase migration new` in an authorized development workspace, then copy and review the candidate SQL. Do not apply the candidate blindly.
- Confirm the `SUPABASE_SERVICE_ROLE_KEY` Edge-only secret is configured (do not print its value, bundle it into Flutter, or persist it in the repository).
- Arrange a maintenance gate for room moderation: deploying either Edge or SQL alone temporarily fails closed for voice-impacting actions. Prepare reversion steps and identify any other callers first.
- Staging: apply the approved migration and deploy the matching Edge revision together; never touch production or `main`.
- Check `has_function_privilege('authenticated', ...)` reports **false** for `phase3.room_moderation_action` and voice-relay RPC, while `service_role` can call the relay. Check public RPC correctly denies voice-impacting actions.
- Run two-account device tests: active voice mute, kick, seat release, grant allow_mic, non-authorized denial, stale-token rejoin denial, offline participant revocation and same-id retries. Verify DB ledger/audit and SFU independently.
- If anything fails, gate moderation and revert **both** halves together; do not restore a DB-only success path as a permanent solution.

## Release gates

- Source-level authorization design and static security contracts: **PASS**.
- SQL syntax validated in a disposable database: **NOT VERIFIED**.
- Supabase Staging migration applied: **NO**.
- New Edge function deployed: **NO**.
- Runtime SFU enforcement with two phones: **NOT VERIFIED**.
- 90% beta readiness / release permission: **NOT VERIFIED**.

No production mutation, Staging data mutation, APK build, signing or store deployment was performed in this batch.
