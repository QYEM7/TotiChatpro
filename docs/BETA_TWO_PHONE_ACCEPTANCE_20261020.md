> **APK BUILD VERIFIED — 2026-10-20:** GitHub Actions [run 39335237130](https://github.com/QYEM7/TotiChatpro/actions/runs/39335237130) finished **SUCCESS**, and published both direct-install test APKs. These files were downloaded, extracted and independently SHA-256 verified. **ARM64:** `TotiChat-Staging-Beta-arm64.apk`, 21,723,342 bytes, SHA256 `192900c183a32b79622573db7afd57201aa2ae91b9ea49d05832ccd064fe1f88`. **ARM32:** `TotiChat-Staging-Beta-arm32.apk`, 19,328,662 bytes, SHA256 `0454bf014b7a29ed01f36a3a56ee90b43f0e3ed15b912c69461b6b232d0c7fda`. Artifacts: ARM64 ID 12227035170, ARM32 ID 12225973370. Build source commit `7591904549efc35cd35b8aa355a6e3d1a078bfce`. **None of the physical-device acceptance tests below are yet completed.**

> **Install note:** Beta artifacts use disposable debug signing. A beta already installed under the same package ID but a different test signing certificate might need to be uninstalled before reinstalling. Do not uninstall during any unresolved financial request, because the app stores durable retry IDs locally. APK is for private QA only.

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
