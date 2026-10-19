> **STAGING DEPLOYMENT UPDATE — 2026-10-20:** This document was originally a pre-deployment plan. The relevant changes have now been applied to Staging and verified at the database/schema/permissions level. Real two-device and financial runtime acceptance are still outstanding. See [actual staging cutover report](BETA_STAGING_CUTOVER_20261020.md). The historical preflight discussion below is retained for audit.

# TotiChat Project 01 — Staging voice-moderation privilege cutover

Date: 2026-10-20. Branch: `rebuild/flutter-v1`.

## Evidence

- The existing public moderation RPC and private `phase3.room_moderation_action` were callable by `authenticated` in Staging on the read-only inspection.
- The Flutter client now uses `phase2-voice-moderate` for `mute`, `release_seat` and `kick`, but an authenticated caller with room moderator privileges could bypass that client and change the DB directly without an SFU disconnect.
- Source fix prepared: [privileged RPC candidate](../supabase/patches/voice_moderation_relay_acl_candidate.sql) + [matching Edge implementation](../supabase/functions/phase2-voice-moderate/index.ts).
- [Security contract CI 39325212067](https://github.com/QYEM7/TotiChatpro/actions/runs/39325212067) and [Deno type-check CI 39325376323](https://github.com/QYEM7/TotiChatpro/actions/runs/39325376323) passed. [Latest PostgreSQL 17 integration CI 39331576815](https://github.com/QYEM7/TotiChatpro/actions/runs/39331576815) passed, including role-grant checks and deny/allow paths against synthetic actors. No production or Staging database integration was attempted.

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
- SQL candidate compiled and actor/ACL test suite passed on disposable PostgreSQL 17 using synthetic users and function stubs: **PASS**. [CI run 39331576815](https://github.com/QYEM7/TotiChatpro/actions/runs/39331576815). This is not a full Supabase schema or physical-device test.
- Supabase Staging migration applied: **NO**.
- New Edge function deployed: **NO**.
- Runtime SFU enforcement with two phones: **NOT VERIFIED**.
- 90% beta readiness / release permission: **NOT VERIFIED**.

No production mutation, Staging data mutation, APK build, signing or store deployment was performed in this batch.


## Additional test details and remaining risks

- Added `supabase/tests/voice_relay_ephemeral_fixture.sql` and
  `supabase/tests/voice_relay_ephemeral_acceptance.sql`. The CI workflow
  starts a disposable PostgreSQL 17 service and executes fixture → candidate
  SQL → privilege/behavior assertions with `ON_ERROR_STOP=1`.
- Tests assert `authenticated` cannot call `phase3.room_moderation_action`
  or the new relay; an authenticated room owner still can call the benign
  `allow_mic` wrapper, but is denied `mute`, `kick`, `ban`, and
  `release_seat`; the trusted server can relay a voice-impacting action
  only for a verified user session with the right owner/moderator scope.
- The Edge relay now forwards only `role`, `sub`, `session_id`, `aal`
  to the privileged RPC, never full token payload or `user_metadata`.
- Real Staging `phase3.actor()` has stricter auth.users/MFA checks than the
  ephemeral fixture's session stub. Matching integration with the full
  real Staging schema and operational credentials remains unverified.
- To stage the coordinated cutover safely, verify server-side
  `SUPABASE_SERVICE_ROLE_KEY` presence without exposing it, test versioned
  rollback, then stage deployment in a controlled maintenance window.
- No Staging ACL change was executed: the previously observed direct
  authenticated `phase3.room_moderation_action` access remains a release
  blocker until an authorized and verified cutover is complete.
