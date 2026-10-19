# TotiChat — Gift retry concurrency beta hardening

Date: 2026-10-20. Branch: `rebuild/flutter-v1`.

## Confirmed source risk and fix

The previously implemented `PendingGiftRequests.acquire` stored a durable operation UUID before sending `phase3_send_gift`. Although retries after a process restart reused the stored UUID, two concurrent instances of the GiftSheet could both observe a missing key and write different UUIDs for the **same still-unconfirmed gift request**.

The new `PendingGiftRequests` implementation uses a shared in-process, payload-keyed `Future` to serialize acquisition across instances. Any second request for the identical account/room/recipient/gift/quantity waits for the first durable read-or-write and receives its operation UUID. It releases the local lock after both success and failure; a failed persistence attempt still aborts before financial RPC.

Added Flutter tests assert:
- Two concurrent sheets share the same persisted request ID; only one disk read and one write occur.
- If disk persistence fails concurrently, both acquisitions fail without sending; the lock releases and a later retry can obtain a new persisted ID.
- Previous cross-sheet reopening and post-restart retention tests remain in place.

## Read-only Staging facts (2026-10-20)

- `public.gift_announcement_settings`: `enabled=true`, `min_gift_price=7000`.
- `public.gift_global_announcements`: zero actual announcements; the global strip must remain hidden.
- `public.gift_events`: zero settled gifts; no genuine debit/credit E2E evidence yet.
- `authenticated` role has EXECUTE on `public.phase3_send_gift(uuid,uuid,text,integer,uuid,bigint)`.
- Two existing room memberships and three wallet records were observed (counts only).

## Limits / release blockers

This is **in-process** concurrency protection, not a cross-device mutex. The backend must remain authoritative for actor-scoped idempotency, ledger conservation, no-negative-balance and retry deduplication.

Required release test: real signed-in Staging accounts on two phones; gift catalog and wallet verified; send confirmed-price quantity 1 and multiple quantities; ensure exactly one debit for retry with same UUID, one recipient credit, no negative wallet, and a global banner only for real settled gifts priced >=7000. Exercise server response loss, offline retry, restart and simultaneous tap/race scenarios. No synthetic Staging gifts, charges, banners or wallet mutations were produced during this review.

## Source tests

- Flutter CI run for latest fix: https://github.com/QYEM7/TotiChatpro/actions/runs/39332611573
- Outcome: **SUCCESS**. Flutter analyze, all Flutter unit/widget tests (including new concurrent request tests), Android host OAuth source check and no-APK guard all passed.
