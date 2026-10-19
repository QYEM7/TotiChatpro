# TotiChat Beta — Two real Android phones acceptance checklist

Source: `rebuild/flutter-v1`. Backend: Supabase Staging `rziaedugbdwefbefcxjt` only.
This is a **test plan, not a passed-test report**. Latest Staging cutover:
[report](BETA_STAGING_CUTOVER_20261020.md).

## Build provenance

Expected GitHub run for the new compact test APKs:
https://github.com/QYEM7/TotiChatpro/actions/runs/39335237130

Only install an APK whose GitHub workflow finished successfully. ARM64 is
preferred for current 64-bit Android devices; ARM32 exists for compatible
older devices. The APK is release-compiled but **DEBUG-signed**, never
production-signed. Do not distribute it as a store/public release.

Record for both phones: model, Android version, build SHA, GitHub artifact
checksum (SHA256), installed package ID `com.totichat.beta`.

## Critical tests

| Test | Device A and Device B action | Expected acceptance evidence |
|---|---|---|
| Google OAuth | Sign in with two real, separate Google accounts | Each correct user returns to TotiChat Beta, session restores, sign-out revokes local session |
| Room | A creates room with real image/name/welcome; B joins | Both observe one real room, same owner/members, 15 fixed seats and no vertical seat scroll |
| Seat | A and B occupy/release different seats | No double reservation, current avatar and name match server |
| Minimize | Minimize/restore active room | Room survives minimization, no audio crash or duplicate join |
| Voice | A speaks while B listens, then reverse; toggle mic | Two-way sound without echo/feedback; no phantom mic |
| Moderation | Owner mutes, releases seat, kicks B | DB membership/seat rights match LiveKit disconnection; stale token must not rejoin after moderation; non-owner actions denied |
| Room chat | Both exchange real text | No duplicate/out-of-order user messages; only participants see messages |
| DM | Open DM by tapping occupied seat | Real recipient receives text; no voice DM |
| Gift | A sends approved gift to B after verifying funds and quote | One debit, one credit, one financial operation/event, one server-generated room chat gift message, B's seat counter updates |
| Retry | Repeat same operation UUID after response loss in a controlled test | Same receipt, no additional debit/credit/chat event |
| Global strip | Check settled gift with unit price >=7000 | Strip only if a verified eligible gift really occurred; no fake banners/strip |
| Admin | Authorized profile opens Admin Center; unauthorized does not | No admin in bottom navigation; server permission gate holds |
| Recovery | Close/reopen app and reconnect | Google session, room and financial retry state are consistent |

## Handling failures

- Do **not** claim PASS from compilation or a local database fixture.
- For every failure record: device, build SHA, operation, UTC/Baghdad timestamp,
  expected vs actual, screenshot, and whether the backend committed.
- If SFU disconnect cannot be proven, report moderation as FAILED/UNVERIFIED,
  not as a success just because a DB flag changed.
- Do not issue artificial coins or fake payment/gift announcements to fabricate
  PASS. Use approved Staging test accounts and a controlled authorized charging
  flow for financial tests.
- No public release before G0–G6 are independently accepted on real devices.

## Outcome

As of creation of this checklist: **NOT RUN / NOT VERIFIED** for all physical
device tests. Record results only after they happen.
