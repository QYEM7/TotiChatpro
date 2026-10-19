# TotiChat Flutter Beta — Gift retry durability and financial confirmation

Date: 2026-10-19. Branch: `rebuild/flutter-v1`.

## Scope delivered
- Created `lib/src/data/pending_gift_requests.dart` with a dedicated pending-operation repository backed by `SharedPreferencesAsync` pinned to `shared_preferences 2.5.5`. Only account ID + room ID + recipient ID + gift ID + quantity and a *publicly non-secret random request UUID* are stored. No session, secret key or wallet balance is persisted.
- The **same exact financial payload** recovers its original request UUID when the user closes/reopens the gift sheet, the app restarts, or a network acknowledgement is lost. UUID is persisted *before* calling the financial RPC; persistence errors prevent any outgoing debit attempt.
- After server-confirmed settlement, the pending key is removed, allowing a new intentional send with the same details. If key cleanup fails, retries stay on the older server-idempotent operation rather than charging twice.
- Gift sheet now requires an explicit confirmation displaying the actual recipient name, chosen quantity and total estimated coins. The server remains authoritative for actual unit price, membership, debit, ledger and idempotency.
- Added `test/pending_gift_requests_test.dart` (persistent recovery, confirmed/new request, account/recipient/gift/quantity separation, fail-closed persistence and invalid input).

## Verified evidence
- [GitHub Actions run 39248681696](https://github.com/QYEM7/TotiChatpro/actions/runs/39248681696): all source tests and Flutter analyzer passed for the persistent request UUID feature.
- [GitHub Actions run 39248954242](https://github.com/QYEM7/TotiChatpro/actions/runs/39248954242): **SUCCESS** for the final gift confirmation/recipient checks, Flutter analyze, tests, Android host source preparation and no-APK guard.
- Staging function `phase3.send_gift_checked` (read-only inspected) performs actor-scoped request-id reuse, checks payload conflicts and expected price, then calls ledgered `phase3.send_gift` whose successful response contains `id`, `status=completed` and `amount`.
- No financial request was sent, no wallet was changed and no seed gift event was introduced in Staging.

## Important release blockers (not hidden by a green source CI)
- Actual multi-account concurrent gift retries, a lost-acknowledgement test, and authoritative ledger audit on Staging remain **NOT VERIFIED**.
- Android device Google OAuth, room membership, two-phone LiveKit, and visual parity remain **NOT VERIFIED**.
- A read-only Staging query returned 0 rows in `phase3.admin_access`. The in-app admin center is permission-gated, but there is no configured authorization row to test real administrative access. No role was granted automatically.
- 90% release readiness **NOT VERIFIED**. No APK/AAB, no production/main mutation and no Staging data/DDL writes.

## Reproduction
On GitHub: open latest run and inspect `flutter analyze lib test`, `flutter test`, and Android host preparation steps. Android host artifact is source-only.
