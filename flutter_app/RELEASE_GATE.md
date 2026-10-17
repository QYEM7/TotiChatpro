# TotiChat — launch gate (Staging only)

Updated: 2026-10-17 (Asia/Baghdad)

## Scope and restrictions

- Canonical Flutter branch: `rebuild/flutter-v1`.
- Supabase Staging: `rziaedugbdwefbefcxjt`.
- **Never** change `main`, production data, or the stable LiveKit SDK for launch QA.
- **Do not build or distribute APK/AAB without explicit Owner approval.**
- Google-only authentication; admin-assigned visible IDs.
- FCM push delivery is deferred; **in-app notifications remain enabled**.
- Host monthly settlement is performed manually by authorized administrators.
- Real data only; features not fully functioning must be disabled or plainly labelled.

## P0 release gates

| Gate | What must be demonstrated | Present state |
| --- | --- | --- |
| Flutter static/build source checks | `flutter analyze lib test` and `flutter test` on exact commit | Automated by GitHub Actions; check latest run |
| OAuth on Android | Two real Google accounts can sign in, sign out and return via `com.totichat.next://auth/callback` | **Not yet verified on physical Android** |
| LiveKit 2-phone voice | Simultaneous join, mic on/off, seat change, minimize/restore, leave, loss/recovery of network without echo or ghost mic | **Not yet verified on two physical phones** |
| Gift debit | Real Staging test accounts; server-confirmed price, receipt, ledger, recipient diamonds, insufficient funds and same-id retry | Client contracts tested; **full Staging transaction flow not yet verified** |
| Store purchases | Valid currency and price, one debit, ownership granted, same-id retry, insufficient funds | Client contracts tested; **full Staging transaction flow not yet verified** |
| Charging agent | Request, documented decision, real receipt, journal and permission checks | Client/backend paths exist; **end-to-end role test not yet verified** |
| Room features | Real room image, welcome, private invite, 15 seats, DM, gifts, exit/minimize and report flows | Implemented paths; **real-device acceptance outstanding** |
| Owner/staff security | Owner, agent, support and ordinary user can access only server-authorized operations | Server checks exist; **multi-role acceptance outstanding** |
| Production + distribution | Backups, rollback, privacy/moderation policy and Google Play billing compliance before production | **Not approved and not started** |

## Improvements completed in the latest launch hardening pass

- Gift and store operations reject imprecise prices and verify the exact
  server-returned receipt before showing success.
- Voice session cancels stale token/connection work after leave or a newer join.
- Room seat change requests cannot be stacked by rapid tapping; any pending
  voice token is cancelled before changing seats.
- Seat RPC acknowledgments must exactly match the requested index (1–15),
  or `null` for releasing a seat.
- There is still **no substitute for multi-device audio and finance testing**.

## Next working session (in order)

1. Check latest `TotiChat Flutter V1 QA` results on this branch and fix failures.
2. Audit edge cases in room exit/minimize, OAuth callback, and reconnect states.
3. Prepare a concrete two-phone acceptance script, using Staging-only test
   accounts. Do not build APK until separately approved.
4. Validate critical gifts, store and agent operations against real Staging
   accounts with ledger evidence and idempotency. Never invent success data.
5. Resolve any failed gate before considering an internal testing build.

The presence of a screen or a green GitHub Actions run is **not** evidence of
a production-ready feature. Maintain separate development and launch-readiness
statuses until the physical-device and transaction gates pass.
