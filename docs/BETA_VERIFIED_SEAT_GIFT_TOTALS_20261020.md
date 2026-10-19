# TotiChat — 15-seat verified gift counters

Date: 2026-10-20. Branch: `rebuild/flutter-v1`. Environment policy: Staging only, no production or `main` writes.

## Goal and semantics

Show a small gift badge under each **currently occupied** room seat. This badge reports the **total coin value of financially settled gifts received by the current user in that room**, not the number of gifts, not wallet balance, and not a counter bound to seat number. A user changing seats carries their verified room gift total. Empty seats show no gift badge. There are still exactly **15 non-scrollable seats**.

## Implemented source

- [Candidate member-checked PostgreSQL RPC](../supabase/patches/room_seat_verified_gift_totals_candidate.sql) (**not deployed**): private `phase3.room_seat_verified_gift_totals` with `phase3.actor()` verified-session check, mandatory current `room_members` membership, and rows only for members occupying seats 1–15.
- Only counts `gift_events.amount` for matching `room_id` and `recipient_id` where `financial_operations` has `operation=gift,status=completed` **and both exact matching immutable sender coin debit and recipient diamond credit exist**. This is an aggregate, not an account-wide wallet disclosure.
- A public `phase2_room_seat_gift_totals` SECURITY INVOKER wrapper is executable by authenticated users, not anonymous. It delegates to the guarded private function. No direct table write or wallet view is granted.
- `RoomRepository.seatGiftTotals` validates row shapes and refuses negative, fractional, malformed, or duplicate returned totals. It never invents a fallback total.
- `RoomScreen` refreshes totals with existing 10-second member refresh and after an acknowledged local gift send. A seat badge is visible only when the server has returned an authoritative total for that occupant. A missing RPC or fetch error hides the counter rather than showing made-up numbers. No new scrollable seat grid.
- `flutter_app/test/room_models_test.dart` covers zero (only when genuinely returned by server), positive amounts, and malformed/negative totals.

## Verified CI

- [Flutter analyze/test/Android host source run #39333946888](https://github.com/QYEM7/TotiChatpro/actions/runs/39333946888): **SUCCESS**.
- [Disposable PostgreSQL 17 ACL/ledger tests #39334064037](https://github.com/QYEM7/TotiChatpro/actions/runs/39334064037): **SUCCESS**.
- SQL fixture covers complete two-sided ledger amounts, incomplete sender-only ledger, failed finance operation, other-room gifts, listener not seated, reassignment to a different occupant, valid member access, cross-room rejection, stale-session rejection and anonymous role denial.

Both CI suites are synthetic-source tests. Neither operated on Staging wallet rows, account data or production systems.

## Release gates still open

1. Candidate RPC has NOT been deployed to Supabase Staging; counters deliberately remain hidden until the server endpoint exists. Use a reviewed migration and a coordinated Staging-only release.
2. Confirm live two-user room visual badge updates and ordering: sender/receiver phone, gifts of approved quantities 1/7/17/77/777, room exit/rejoin, seat changes, and sign-out.
3. Device acceptance must demonstrate financial idempotency and zero-negative-wallet after real valid Staging gift operations; no such transactions were created here.
4. `phase2-voice-moderate` security fix and verified-room-gift-message patch also remain staged source candidates, not deployed. Do not claim release ready or 90% acceptance.
