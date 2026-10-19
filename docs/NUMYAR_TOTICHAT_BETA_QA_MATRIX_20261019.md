# NUMYAR — TotiChat Beta Acceptance Test Matrix
Date: 2026-10-19
Source of truth: `rebuild/flutter-v1` / `flutter_app/` / Supabase Staging `rziaedugbdwefbefcxjt`
Status: **PLANNED — NO real-device tests executed by this document**

## Ground rules
- Do not test with production environment or real money.
- Use two authorized distinct Staging accounts and two physical Android phones; record device model, Android version, app build SHA, and test date.
- Do not invent screenshot/test evidence. Prefer anonymized screenshots and logs; never include passwords, access tokens, service keys, users' private chat content or full personal identifiers.
- Mark PASS only when observed on devices with evidence. Code presence and CI success are not a PASS.
- Stop tests if the app unexpectedly targets anything except Staging.
- Never seed fake LIVE balances, users, announcements, or gift records.
- Explicit approval and safe staging setup are required before any destructive or financial test.

## Test run template
- Date/time (Baghdad):
- Tester:
- Build commit SHA:
- APK source / signed artifact (if explicitly authorized):
- Supabase project ref: `rziaedugbdwefbefcxjt`
- Android phone A (model/version):
- Android phone B (model/version):
- Test accounts: A and B (use redacted internal references):
- Screen recording links (private):
- Test result: PASS / FAIL / BLOCKED / NOT RUN
- Defect links and reproduction steps:

## Acceptance cases

| ID | Gate | Test steps | Required PASS observation | Status |
| --- | --- | --- | --- | --- |
| QA-01 | G0 | Verify CI against exact build SHA; inspect manifest callback, only Staging URL, asset license/source and non-mock UI | Source checks pass, Android build configuration correct, no LIVE mock paths | CI only; device NOT RUN |
| QA-02 | G1 | Android A: Google login, leave/return, close/relaunch, logout, login again | Genuine OAuth callback, correct persistent session, no fake login or stale auth | NOT RUN |
| QA-03 | G1 | Inspect normal user public ID and attempt unauthorized ID assignment from client | ID absent unless owner-admin assigned; unauthorized assignment denied | NOT RUN |
| QA-04 | G2 | Account A create room with title, welcome, actual WebP cover; B discover and join | Same room state and uploaded image on both phones; no phantom listing | NOT RUN |
| QA-05 | G2 | A/B claim/release two of 15 numbered seats; observe membership across clients | Server-consistent seat occupancy, no duplicate seat ownership, all 15 fixed and in layout | NOT RUN |
| QA-06 | G2 | Minimize room, navigate Home, restore; leave room | Room restored, correct state continuity, no orphan membership | NOT RUN |
| QA-07 | G3 | A connects as listener; B speaks from a claimed seat; swap roles | Actual audio transmit/receive, correct device routing, no silence/echo/crash | NOT RUN |
| QA-08 | G3 | Mute/unmute, disconnect/rejoin, revoke voice permission while previously granted | Publish denied after server moderation, including stale-session scenarios | NOT RUN |
| QA-09 | G4 | Send room texts from A and B, then text DM A→B and reply B→A | Correct ordering/delivery, recipient-only privacy, no DM voice feature | NOT RUN |
| QA-10 | G4 | Attempt to retrieve private DM or room content from unauthorized account | Server denies unauthorized read/write without relying on hiding UI alone | NOT RUN |
| QA-11 | G5 | With approved controlled Staging funds, send gift quantity 1 and repeat exact idempotency request | One authoritative settlement only; sender debit/recipient receipt/ledger reconcile | NOT RUN |
| QA-12 | G5 | Send insufficient-funds request, double-tap send, test 7/17/77/777 quantities | No negative balance, no double settlement; UI and room notice reflect true events | NOT RUN |
| QA-13 | G5 | Send genuine >=7000 unit-price gift, inspect another room feed; then check empty no-event state | Global strip reflects only eligible settled events; empty remains hidden | NOT RUN |
| QA-14 | G6 | Compare login, Home, room, 15 seats, gift bottom sheet, DM, Profile and Admin UI with approved design | Screens match accepted reference; no legacy UI or decorative omission | NOT RUN |
| QA-15 | G6 | Owner/admin and ordinary users open Profile/Admin Center; attempt privileged requests | Admin card only for authorized roles; every privileged action checked server-side | NOT RUN |

## Required supporting evidence
- **G0:** GitHub Actions run URL, exact commit, Flutter analyzer and tests, Staging contract/RLS evidence; visual review remains open.
- **G1:** Android OAuth redirect/session logs with tokens redacted.
- **G2:** Two-phone time-correlated video of room/seat actions plus sanitized server state.
- **G3:** Two-phone voice recording/demo and rejection evidence for muted/revoked microphone.
- **G4:** Authorized/unauthorized text delivery matrix with privacy-safe log excerpts.
- **G5:** Sanitized Staging transaction IDs, idempotency keys, before/after accounting and failure outcomes (no key or financial secret exposure).
- **G6:** Approved reference vs exact Flutter screenshots, defects cleared, owner sign-off.

## Known blockers and ordering
1. Verify Android test build configuration is Staging-only; use existing owner authorization only within its exact scope.
2. Check Staging LiveKit credentials/URL through secure server metadata, not by printing secrets. Active functions do not prove usable voice.
3. Ensure moderator enforcement also removes stale SFU microphone publishing authority.
4. Run QA-02 through QA-10 on two devices before performing controlled gift/wallet tests.
5. Complete all G0–G6 evidence before declaring release readiness.

Related:
- [Command Center](NUMYAR_COMMAND_CENTER_20261019.md)
- [Detailed readiness evidence](BETA_RELEASE_READINESS_EVIDENCE_20261019.md)
