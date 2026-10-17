# TotiChat Android internal beta — acceptance protocol

As of 2026-10-17 (Asia/Baghdad). Status: **PRIVATE STAGING ANDROID DEBUG BUILD APPROVED; wider distribution NOT approved**.

## Non-negotiable environment and scope
- Flutter branch: `rebuild/flutter-v1`. No modifications to `main` or production.
- Supabase Staging only: `rziaedugbdwefbefcxjt`.
- Google-only OAuth and server-assigned public user IDs.
- No fabricated rooms, gifts, balance, revenue, banners, agency members or successful transactions.
- Keep the current LiveKit SDK unchanged. FCM is deferred; in-app notifications remain active.
- Monthly host/agency payroll and settlements remain manual; evidence screens are read-only.
- **Owner approved ONE private Staging Android debug APK for two-phone testing on 2026-10-17.** This authorizes building and retaining it as a private GitHub Actions artifact only; no Play Store upload, public release, AAB, production connection or external distribution.
- Source tests and database inspections do not substitute for tests on physical Android devices.

## Required test equipment
- Two physical Android phones (A and B) with separate, real Google accounts.
- Separate data/Wi-Fi connectivity paths and permission to disable/re-enable networking.
- A controlled Staging test room. Avoid public/production accounts and transactions.
- An authorized Owner tester and a separate non-administrative tester.
- A timestamped test record with the exact commit SHA, phones' Android versions,
  any client errors, and relevant Staging record IDs (never passwords or tokens).

## P0 acceptance — record PASS, FAIL or NOT RUN for each
| ID | Scenario | Exact passing criterion | Status |
|---|---|---|---|
| AUTH-01 | Fresh Google login on A | Google OAuth returns to the Android app at `com.totichat.next://auth/callback`; a real authenticated profile is shown | NOT RUN |
| AUTH-02 | Separate login on B | Distinct real identity, correct account-specific profile; no crossed sessions | NOT RUN |
| AUTH-03 | Sign out / sign back in | Previous account's restricted data is not shown after sign-out | NOT RUN |
| ROOM-01 | Create public room | Title, cover and welcome are saved server-side and visible in the room | NOT RUN |
| ROOM-02 | Two-person join, 15 seats | Both devices see the same occupants; seats remain unique and within 1–15 | NOT RUN |
| ROOM-03 | Minimize and restore | Room remains joined, returns with the same session, without duplicate peer/audio | NOT RUN |
| ROOM-04 | Exit during slow/rejected join | Pending exit completes without phantom membership | NOT RUN |
| ROOM-05 | Private invite and DM | Server-authorized invitation works; DM goes to the correct user | NOT RUN |
| VOICE-01 | A speaks and B listens | Real audio heard, without echo or unintended duplicate tracks | NOT RUN |
| VOICE-02 | Mic on/off across both phones | Each mic indicator matches server-approved mute, listener actually stops hearing muted peer | NOT RUN |
| VOICE-03 | Seat change with mic active | Server mute is confirmed, new seat correct, no stale published mic | NOT RUN |
| VOICE-04 | Hangup / exit / re-enter repeatedly | No ghost microphone, stuck room, duplicate membership or unhandled error | NOT RUN |
| VOICE-05 | Network loss then reconnect | Reconnect or clear failure with manual retry; no unauthorized mic reactivation | NOT RUN |
| ECON-01 | Gift debit on Staging | Owner-approved test funds only; exact price, balance, ledger, recipient credit and single idempotent receipt agree | NOT RUN |
| ECON-02 | Gift retry / insufficient funds | Same request ID never double-debits; insufficient funds never produce a partial debit | NOT RUN |
| ECON-03 | Store purchase and retry | One debit, one ownership grant, verified receipt and repeat request is idempotent | NOT RUN |
| ECON-04 | Agent recharge | Authenticated agent flow matches receipt/ledger and permissions; ordinary user cannot impersonate agent | NOT RUN |
| ADMIN-01 | Owner versus staff permissions | Owner gets authorized functionality; regular and non-authorized staff cannot perform restricted actions | NOT RUN |
| DISPLAY-01 | Real banners / gift ticker | Nothing is shown without verified server events; announcements require at least 7000 coins | NOT RUN |

## Required execution sequence
1. Run `flutter analyze lib test --no-fatal-infos` and `flutter test` on the exact candidate SHA.
2. Review Staging/Auth URLs and Android deep-link registration.
3. Build the explicitly approved private Staging debug APK in GitHub Actions; only when that build succeeds, install it on both test phones and execute AUTH/ROOM/VOICE in order. No automatic claim of passing physical tests.
4. Only after explicit Staging test-funding authorization, exercise ECON cases; record
   journal evidence and never use production wallets or invent deposits.
5. Run ADMIN with separate authenticated accounts and check both hidden UI and server denials.
6. Triage every P0 failure, commit a fix to this branch, and rerun the failed cases plus core regressions.

## Decision record
- PASS requires **all P0 checks PASS**, no unresolved critical crashes/security/finance
  issues, successful automated CI on the exact tested SHA and explicit Owner approval.
- A green CI run does **not** advance a NOT RUN manual test to PASS.
- If physical devices or approved Staging test funds are unavailable, record BLOCKED rather
  than fabricating a passing result.
- Owner authorization to compile/distribute a private test APK is a separate decision from
  approval to publish on Google Play or connect production.

Tested commit: ______________________________
Tester / date: ______________________________
Open critical defects: ______________________
Beta test-build authorization: **GRANTED 2026-10-17 — private Staging debug APK only**
Go / no-go decision: **NO-GO until physical and finance gates pass**
