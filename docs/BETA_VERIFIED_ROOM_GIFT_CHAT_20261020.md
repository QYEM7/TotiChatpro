> **STAGING DEPLOYMENT UPDATE — 2026-10-20:** This document was originally a pre-deployment plan. The relevant changes have now been applied to Staging and verified at the database/schema/permissions level. Real two-device and financial runtime acceptance are still outstanding. See [actual staging cutover report](BETA_STAGING_CUTOVER_20261020.md). The historical preflight discussion below is retained for audit.

# TotiChat Project 01 — Verified room gift chat

Date: 2026-10-20. Branch: `rebuild/flutter-v1`.

## Why this work is required

The existing `phase3_send_gift` transaction has a financial operations record, a gift event, an immutable sender coin debit and a recipient diamond credit. The existing global announcement trigger correctly filters *large gifts*, but neither it nor the room message table produced an authoritative room-chat event for ordinary completed gifts.

Do **not** insert a gift-like chat message from Flutter after a request returns: the response may have been lost, the debit may already be committed, and client-generated messages cannot prove settlement or deduplicate concurrent replays.

## Prepared source changes

- Candidate SQL: [verified_room_gift_chat_candidate.sql](../supabase/patches/verified_room_gift_chat_candidate.sql). **Not deployed**.
- Adds `room_messages.event_kind` defaulting to `chat` and a gift transaction FK; this is additive to existing messages and the `phase2_room_send_message` text RPC.
- A deferred `gift_events` constraint trigger inserts a room chat notice only when the associated completed operation, sender debit and recipient credit all exist with exact values.
- A unique indexed `gift_event_id` prevents a second chat notice for the same financial transaction.
- Normal authenticated users retain read access, but the schema grants no ability to directly insert messages or invoke the trigger.
- Flutter `RoomTextMessage` interprets only the server's exact `event_kind='gift'` as a highlighted gift notice and handles older rows without the column as normal chat.
- No sample banners, mock gifts, admin activity or financial mutations are included.

## Validation

- [Isolated PostgreSQL 17 settlement/chat tests](https://github.com/QYEM7/TotiChatpro/actions/runs/39333385132): **PASS**. Includes a completed gift with ledger inserted *after* the gift event but before COMMIT, no-ledger/one-sided-ledger/failed-operation denial, idempotent replay, chat defaults, and insert/trigger execution grants.
- [Flutter analyzer and widget tests](https://github.com/QYEM7/TotiChatpro/actions/runs/39333350045): **PASS**, including model tests for verified gift message kinds, Android host OAuth source check, and no-APK guard.
- Both tests use fixture data only and never write to Staging or production.

## Still required to ship

1. Review the additive SQL against the live Staging schema, run migration safety/checks and approve deployment. Actual Staging `room_messages` does **not** yet have the `event_kind` column; until SQL is deployed, this version still displays ordinary chat normally but does not create verified gift notices.
2. After authorized Staging deployment, test two signed-in room members: one real gift must produce exactly one immutable ledger pair, one gift event, one verified room message, and (when unit gift price >=7000) the configured global banner.
3. Simulate a lost RPC response and retry with the original UUID. Verify zero duplicate ledger entries and exactly one room message.
4. Reconcile separate seat-level gift counters from the same financial source; they are **not** implemented in this change.
5. Perform device acceptance of room realtime ordering and visual parity. This source test is **not** 90% release readiness.

Environment: Staging only. `main`, production, existing LiveKit services and financial balances have not been changed.
