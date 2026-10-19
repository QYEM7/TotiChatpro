# TotiChat Beta — Reliability fixes (2026-10-19)

This batch continues the **new approved Flutter/Dart** client on `rebuild/flutter-v1` only. It does not make a production deployment or an APK.

## 1. Active-room logout safety
- A user leaving the app while inside a room must not revoke the Supabase session first, because room closure requires that session.
- Added `SessionExit.run()` with a fail-closed sequence: **server-confirmed room closure → sign out**.
- The room's LiveKit transport is disconnected before calling `phase2_room_leave`. Owner departure closes their owned room in the existing server contract.
- An active/owned room now requires confirmation before a logout that would close it.
- If room cleanup is refused or network fails, the app keeps the session instead of falsely displaying successful logout.
- Four new unit tests cover ordering, rejected closure, thrown closure, and logout outside rooms.

## 2. Recent chat visibility
- `room_messages` stream now requests **newest 50 rows** (`id DESC`), instead of oldest 50; otherwise new messages would vanish after the room exceeded 50 historical messages.
- The room's reversed `ListView` now uses newest-first row indexing, so the latest text appears at the bottom.
- `phase2_dm_thread` SQL was inspected read-only: its result is already `ORDER BY id DESC`. The Flutter DM view was corrected to use the same newest-first indexing.

## 3. Financial duplicate prevention
- A gift retry uses the same RPC idempotency UUID when `roomId`, recipient, gift ID and quantity are unchanged, even after changing selection back.
- The server remains authoritative over gift price, stock/access rules, wallets and settlement. No fake balance or client-side wallet changes were introduced.
- **Limitation:** retry identity is currently held only while the same gift sheet remains open. An interrupted/reopened sheet still needs transaction recovery for robust unattended financial retries; it is not certified end-to-end.

## Verification boundaries
- Exact server implementations for `phase2_room_leave`, mute, DM thread, and moderation were read from Supabase **Staging** without altering data.
- New GitHub Actions run must validate this batch's source changes; the previously passing run `39188427349` covers the earlier state, not necessarily this batch.
- Device tests remain absent: Google sign-in/deep link, two-phone LiveKit audio, gift/wallet concurrency, multi-account room/chat/moderation and exact visual parity.

**Release readiness 90% remains unverified.** No APK/AAB, remote migrations, staging data writes, production modifications or `main` changes.
