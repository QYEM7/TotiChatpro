# TotiChat Phase 2 — Integration Progress Report
Date: 2026-10-10
Status: **FOUNDATION BETA — NOT A COMPLETE RELEASE**

## Source of truth

Approved UI/UX: `main` and `release/uiux-v1-approved` at
`e19707abbca40f62b4494c2d95c1187dd7c27b08`.
**Do not modify or merge into these without new visual approval.**

Phase 2: `develop/phase-2` at the tested commit
`39936f8f2f6706d7f27468946f7fa76adeb626de`.
Legacy code `jsjsnsnsnsn0-pixel/TotiChat` and its database remain untouched.

## Real backend in independent project

Supabase project: `sqedsnyvjblvbjbizcay`.

**Already applied without deleting old or new data:**

1. `phase2_identity_profiles`: Auth-linked real profile with RLS, signup trigger,
   narrow update grants, no public access to the table.
2. `phase2_signup_display_name`: sanitized signup display name.
3. `phase2_rooms_chat_seats`: room directory, one active membership per account,
   atomic 15-seat reservations, public-vs-private rooms, persistent room messages,
   scoped authenticated server-side RPCs, RLS and no direct client writes.

The 3 original real official banners are unaffected.
A real *signed-in* app now queries the independent backend for account data,
rooms, seats and text chat; guest preview remains non-mutating.
**No voice media is transmitted by seat reservation RPCs.**

## Implemented frontend integration

- Real password/email Auth REST signup/login/OTP/recovery/session refresh/logout.
  Tokens are not exposed in public Auth state; no secret or service_role key shipped.
- New signed-in profiles read and updated from real Supabase table.
- Home approved room gallery changes from demo data to real directory *after login*.
  Signed-in users can create/join/leave rooms and reserve/free any of 15 seats.
  Authenticated room chat writes to server and reads back.
- Existing purple/gold approved art, 15 seat visual grid, navigation and banners
  retained. Found and patched a legacy MutationObserver that incorrectly overwrote
  the real room name with the fake demo title.
- Approved HTML/images are copied byte-identically into Android's `dist` payload.

## Verified builds and checks

- Isolated foundation and mocked Auth contract tests:
  https://github.com/QYEM7/TotiChatpro/actions/runs/38002138725 — **SUCCESS**.
- Full mobile browser review + mock-authenticated account/room/seat/chat/profile journey:
  https://github.com/QYEM7/TotiChatpro/actions/runs/38002138648 — **SUCCESS**.
- Android **debug** APK compilation (not a production-signed APK or real-device QA):
  https://github.com/QYEM7/TotiChatpro/actions/runs/38001919828 — **SUCCESS**.
- APK is an Actions ZIP artifact named `totichat-phase2-debug-apk`, visible
  in the successful Android job; extraction required before installing.

Mock tests prove UI/API contracts and mobile-browser rendering; they do **not**
prove email delivery, voice between handsets, real funds or Android permissions.

## Unfinished — must NOT be described as completed

- Multi-user media audio/voice streaming needs a production TURN/SFU provider,
  mobile reconnect/permissions and 2+ physical device validation.
- Profile photo Storage upload and private account permissions review.
- Real-money-equivalent ledgers, treasury, agency/distribution contracts,
  gifting, inventory, VIP/CP, diamond/monthly settlement, owner/admin dashboard,
  games, real-time presence/notifications, musical streaming.
- Security review of 6 auth-scoped SECURITY DEFINER room RPCs
  (the Supabase Advisor flags such RPCs by design; check each grant and caller
  authorization before release).
- Rate-limiting and abuse protection, private room invitations, moderation, audit
  logs, migration/recovery plan and device interoperability.
- APK physical install/update testing, microphone/speaker/audio-foucs handling,
  Google Play policy checks, release signature, app icon/splash verification.
- Restrict `main` and frozen branch by GitHub ruleset/branch protection (currently
  unprotected at the GitHub API level).

## Rollout gates

The current integration stays on `develop/phase-2`. Do NOT deploy it over the
approved public Pages site or merge to `main` until signed-in journeys have been
tested with actual accounts, backend RLS adversarial cases, APK on Android device,
and the owner reviews the new live behavior.


## Continuation: private rooms, safer chat and audit

Completed on `develop/phase-2` and applied to the **independent** Supabase
project without deleting any data:

- Owners of **private rooms only** can generate a 24-byte randomly generated,
  SHA-256-hashed invitation token. It expires after 30 minutes, is single-use,
  and reissuing it invalidates the old one.
- A member must sign in and enter the complete `room UUID:secret` code to
  accept. Membership is inserted transactionally and the invitation marked
  redeemed under a row lock. An invalid token cannot reveal a private room.
- Private room RLS now allows only the owner, its joined members and no other
  authenticated account to load room details. Public rooms remain discoverable.
- Real chat now uses the server send RPC for both the Send button and the
  keyboard Enter key; the old guest-only preview message path is bypassed.
  Concurrent per-account send RPCs serialize so 1-second rate limiting cannot
  be bypassed by sending multiple requests at the same moment.
- Indexes added to previously unindexed foreign keys on invites and messages,
  based on the project's performance advisor.

Evidence:
- Phase 2 foundation + security contracts:
  https://github.com/QYEM7/TotiChatpro/actions/runs/38003585730 (**PASS**)
- Full mobile browser QA, including mocked **two-account private invitation
  redemption** and previous Auth/profile/chat/15-seat flows:
  https://github.com/QYEM7/TotiChatpro/actions/runs/38003585738 (**PASS**)
- Supabase schema inspection confirms RLS enabled, no anonymous RPC execution,
  and no anonymous or authenticated direct reading of invitation secrets.

Known limitations remain unchanged: no live voice media, no production-quality
multi-device Android verification, no wallet/gift/agency ledger completion.
Mocked E2E journeys validate client integration and route behavior, not actual
multi-person streaming or real account signup delivery.

## Risk note for security advisors

Supabase security advisor flags **8** authenticated `SECURITY DEFINER`
functions as warnings. This is currently intentional: the browser gets no
direct writes to protected room tables, and authenticated RPC functions make
the caller checks. Those functions still need adversarial live-account
penetration tests before production. The `phase2_room_invites` table has RLS
with no direct read policy **intentionally** (all access through RPC).

The public site and frozen UI remain on `main` unchanged. All work here is
isolated to `develop/phase-2`.
