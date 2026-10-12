# TotiChat — In-App Unified Administration Center
Status: APPROVED NAVIGATION AND INFORMATION ARCHITECTURE, IMPLEMENTATION NOT YET CLAIMED
Date: 2026-10-12
Repository: QYEM7/TotiChatpro
Source basis: develop/phase-2 @ 8e56d9535d352221f5ad434be6d4289cd33b2415
Destination: new mobile-first, single administration center inside the existing TotiChat app.

## Immutable user decisions
1. Every account, including staff, enters the ordinary TotiChat experience after normal sign-in.
2. Only an authorized account sees a premium "مركز الإدارة" entry inside "ملفي" (My/Profile). There is NO admin entry on Home, Room, or the main bottom navigation.
3. One consistent admin UI for all eligible personnel. Its screens, data, and actions adapt to server-verified effective permissions; a role label alone is never an authorization.
4. Administration remains part of the same app session, not an external standalone Vercel dashboard and not a second login. Sensitive actions may require re-authentication. Do not accidentally log out or change account when exiting Admin Center.
5. The visual identity is luxurious, mobile-first, RTL, accessible, and harmonized with approved TotiChat branding. Preserve the existing falcon logo, Home, 15-seat Room, Profile VIP/CP/medals, banners, navigation, artwork and effects; do not reset or replace the approved baseline.
6. Scope is the existing implementation, NOT a rebuild from scratch. Keep production, main, and release/uiux-v1-approved unchanged while working. Do not build an APK or claim a release merely from a mock.
7. All financial values, room/user identities, roles, agency state, and audit entries are real server-backed data only. Empty, loading, permission-denied, and unavailable states must tell the truth.

## Entry and lifecycle
My/Profile -> (if effective admin access) Admin Center card -> Admin Overview -> permitted Section -> Detail/Action -> return to same Section -> Overview -> "العودة إلى TotiChat" -> My/Profile.
Do not display entry for ordinary User, Host Agent or Charging Agent solely for being agents. Agents retain their operational tools inside the ordinary app, not the employee administration center.
For an administrative account that is speaking/listening in a live voice room, switching to admin views must not remount or terminate its LiveKit transport or discard mic/seat membership; preserve or explicitly explain actual foreground limitations, and test on Android.

## Navigation hierarchy (screen inventory)
Codes indicate planned SCREEN CONTRACTS, NOT assertions that live endpoints exist.

A. Overview / 5 screens
A01 Dashboard KPI overview; A02 personalized quick actions; A03 pending-work summary; A04 recent authorized actions; A05 admin account/authority details.

B. Approval queue / 4
B01 all permitted pending work; B02 request detail + evidence; B03 approve/reject/escalate with mandatory reason; B04 approval history and conflict handling.

C. Users / 6
C01 paginated user directory and search; C02 real user detail + public profile; C03 roles, status, membership summary (read scope); C04 user report history; C05 permitted user moderation actions; C06 account restriction history and appeal. Backend moderation writes are NOT yet complete in source.

D. Voice rooms / 5
D01 room list, active/inactive; D02 room detail, owner, members and 15 seat status; D03 room reports; D04 permitted mute/kick/ban actions (subject to approved moderation permissions); D05 room moderation history. Do not conflate room-owner controls with global admin rights.

E. Safety and moderation / 5
E01 report inbox; E02 evidence and case detail; E03 reason-coded action and review; E04 appeals and escalations; E05 moderator action history. No unapproved global ban capability.

F. Staff and effective permissions / 7
F01 staff roster; F02 staff detail; F03 create/assign role to an EXISTING verified user; F04 permission category toggles plus scope; F05 disable/revoke grants; F06 immutable approval/audit trail; F07 primary-partner designation (separate explicit privileged action; NEVER inferred merely from Super Admin role).

G. Host agency management — OWNER and EXPLICIT MAIN PARTNER ONLY / 8
G01 host agency directory; G02 agency profile and membership; G03 host assignments and roster; G04 targets and performance; G05 host/agency monthly figures; G06 contract/commission policies; G07 closure/suspension and historical details; G08 reviewed transfer/exception workflows. Ordinary and additional Super Admins DO NOT receive this module by default.

H. Host agency opening — narrowly scoped DB workflow / 4
H01 approved opening queue; H02 verify pre-approved application and required fields; H03 one-time open/activate agency; H04 daily opening report/history. DB employees do not manage, edit, close or settle host agencies after creation, and NEVER open recharge agencies. DB must not get Module G comprehensive access.

I. Charging agents / 6
I01 verified charging-agent directory; I02 account detail/limits; I03 authorize creation/activation if specifically approved; I04 credit, sale and customer ledger visibility; I05 reviewed adjustments/settlement as separately authorized; I06 agent transaction reports. Charging agents use normal in-app agent tools, not employee Admin Center.

J. Treasury, wallets and recharge / 7
J01 treasury overview; J02 financial operations feed; J03 wallet ledger detail; J04 fund/credit recharge agent through permitted authoritative RPC; J05 transfer, reversal and reconciliation review; J06 mismatch/financial integrity investigations; J07 protected financial audit. No manual direct-balance edits, silent deletion or invented values.

K. Host earnings and monthly closing / 8
K01 diamonds by host/agency/month; K02 goals and target progress; K03 draft monthly preflight; K04 pending host salary liabilities; K05 pending agency commission liabilities; K06 double-checked settlement approval; K07 close-month immutable statement; K08 monthly reset/30% conversion with receipts and disputes.
IMPORTANT: current source has read-only preflight and immutable accrual foundation, NOT paid salary, actual approved rates or a safe live month-close/reset. K04-K08 must remain explicitly unavailable until business rates, conservation accounting, authorized approval and tested idempotent transaction chains are delivered. Do not reset rights owed or Coins.

L. VIP, levels and privileges / 5
L01 real VIP status finder; L02 owner-granted VIP1-VIP10 eligibility and expiry; L03 user XP/level review; L04 VIP perks/frame/identity config subject to documented business rules; L05 VIP changes history. Existing source owner-only grant/revoke; do not give elevated grants to staff by merely rendering the control.

M. Medals, badges and effects / 5
M01 medal registry; M02 grant/revoke by authorized Owner; M03 ownership history; M04 frame/badge asset registry and entitlement review; M05 effects consistency. Preserve already-approved visible styling and earned medals.

N. Gifts, store, lucky gifts / 7
N01 gift category catalog; N02 gifts and verified prices; N03 store/CP catalog; N04 item create/edit workflow with field-specific safe validation; N05 gift transaction audit; N06 lucky gift rules and multiplier/probability approval; N07 promotional and catalog change history. Source global catalog mutations may be incomplete/disabled. Lucky Gifts must remain fail-closed until actual approved payout rules exist.

O. CP / 4
O01 relationship types; O02 relationship search and status; O03 authorized report/dispute cases; O04 CP catalog entitlements. Never expose other users' private relationships beyond approved scope.

P. Banners and announcements / 6
P01 banner queue submitted via Customer Service; P02 banner creation, compressed image upload and preview; P03 Owner/Admin review/approval as authorized; P04 publication schedule, order and expiration; P05 archive/history; P06 announcement templates and notifications. Approved in-app banners are view-only, 3–72h manual term for user requests; no tap redirect on those banners.

Q. Customer Support / 6
Q01 authorized ticket inbox; Q02 ticket detail/thread; Q03 authenticated reply; Q04 status/assignment and escalation; Q05 request types (agency, banner, general); Q06 support staff roster (Owner-only delegation per current implementation). Customer Service's baseline is support/tickets, reports and banner submission; not arbitrary wallet mutation, bans or agency-wide authority.

R. Reports & exports / 6
R01 KPI reports; R02 users and rooms; R03 support/moderation; R04 gifts and VIP; R05 agency, charging and monthly statements; R06 bounded period filters and CSV/PDF exports. Restrict data at query level as well as render level, and protect against spreadsheet formula injection.

S. Admin notifications / 4
S01 personal unread queue; S02 actionable pending items; S03 delivery preferences for admin notifications; S04 notifications history/read state. Do not mix private admin case contents with ordinary user push previews.

T. Audit and security / 7
T01 audit search by actor, target, action and time; T02 before/after details; T03 protected privileged-action reviews; T04 session and role-revocation behavior; T05 anomaly/finance issue reports; T06 restricted export and retention; T07 security settings and sensitive action re-auth.
Audit is append-only, server-side, and never directly editable from a client.

U. Operations, events, games and special IDs / 5
U01 configured event listings; U02 game enablement/content oversight (not speculative odds or payment); U03 room-wide notices/events; U04 Owner special ID rules and assignments subject to authenticated RPC; U05 publication/activity audit. Do not claim the full admin workflows already exist.

V. Administration settings / 5
V01 feature status (real/disabled/limited); V02 content policies; V03 moderation rules; V04 administrative UI language and accessibility; V05 legal/terms/support links. Production system switches require explicit server permissions, not direct browser config editing.

W. Admin help / 3
W01 quick operator guide by role; W02 escalation guide; W03 troubleshooting with status and signed-in identity redaction.

### Shared modal/action contracts
S01 global search/filter/sort; S02 detail sheet; S03 create/edit form; S04 operation confirmation; S05 mandatory action reason; S06 evidence attachment preview; S07 approve/reject/escalate; S08 permission scope preview; S09 second approval prompt; S10 financial before/after summary; S11 conflict/retry handling; S12 duplicate-request idempotency feedback; S13 error details; S14 access denied; S15 empty state; S16 loading and refresh; S17 success/failure acknowledgement; S18 CSV/PDF export options; S19 audit history; S20 session expired; S21 re-auth challenge; S22 unsaved changes warning; S23 image crop/preview; S24 pagination; S25 offline/reconnect; S26 account switch privacy; S27 live-room audio continuation status; S28 transactional pending state; S29 notification detail; S30 agency/month selection.

## Authorization invariant matrix (high-level)
- Owner: top administration authority, account immutable to all non-owner actors; Owner cannot be created by any role-assign form. Signed-in Owner must not be silently replaced.
- Primary designated partner (Super Admin): separately explicit designated identity; comprehensive Host Agency Management along with Owner. Never allowed to promote itself to Owner, remove/change Owner, or self-grant unlimited privileges. Other delegated authority governed by server contract.
- Additional Super Admin: only individually granted administrative sections and actions; NOT comprehensive Host Agency Management by title.
- Admin: explicitly granted admin permissions; never automatically financial or Owner-only.
- Customer Service: support/ticket access, report submissions, banner submissions; not finances/bans.
- Moderator: only specific moderation permissions; any global action requires server permission.
- DB Employee: narrowly authorized OPEN/ACTIVATE host agency from approved flow and produce daily report; no comprehensive host-agency management; no recharge-agency opening.
- Charging Agent / Host Agent / Host / User: respective operational screens in standard TotiChat, not employee Admin Center from their business label alone.
- Resolve section navigation from an effective permission list fetched from server, not solely from claims stored in localStorage, email, route, rank name, or hidden UI controls.
- Check each read and mutation inside RPC/RLS/server. A user who guesses a route or calls the API directly must not bypass rights.
- Security-relevant async responses must be discarded after logout, session change, revoked grant or account swap.

## Existing source audit (reviewed 2026-10-12)
- The repo already contains admin-dashboard/{index.html,app.js,management.js,styles.css,management.css} as an independent Staging-only web panel with about 14 top-level navigation modules, including real server-connected directory, banner, support, agency, role, VIP, medal and finance-read interfaces.
- app/phase3-admin-ui.js already supplies restricted catalog administration in the consumer app; avoid duplicate and divergent permission models.
- Staging contains existing migrations/RPCs for agency handling, support, admin directory, VIP, medal, finance integrity and monthly preflight.
- admin-dashboard/README.md and DEPLOYMENT_HANDOFF.md expressly say the independent official Vercel admin site is NOT verified deployed; the Vercel project returned 403 due to team permissions. This in-app proposal removes dependency on separate official admin URL for normal usage, but it DOES NOT repair password recovery/OAuth deep links automatically.
- docs/UI_BASELINE_PHASE1_APPROVED.md freezes UI baseline. Never modify release/uiux-v1-approved or main for this work.
- The present review is READ-ONLY to existing code and database. This design document is the sole proposed addition on an isolated documentation branch.

## Merge-safe execution phases
1. Document and verify screen-to-RPC/permission mapping against current Staging and source, marking implemented/read-only/missing for every action. Test current UI baseline.
2. Implement a reusable in-app admin shell in isolated JS/CSS, mounted only from My/Profile by effective rights. Same already-authenticated app session. No external OAuth redirect or iframe.
3. Port actual existing admin/dashboard components to in-app shell progressively (overview, users/rooms read-only, support, banners, roles, VIP/medals, agencies). Reuse backend RPCs; don't create parallel source of truth.
4. Implement missing server permissions / write workflows only after policy approval and isolated Staging tests; keep pending actions unavailable rather than faking success.
5. Add comprehensive role matrix tests (Owner, primary partner, additional Super Admin, Admin, CS, Moderator, DB, Agents/Host/User), direct API denials, stale session, finance idempotency, route/back behavior and real-device voice continuation.
6. Run snapshots on Home, Profile and 15-seat Room against approved baseline, mobile RTL accessibility, physical-phone signed-in multi-account checks, and staging recovery rehearsal.
7. Retire standalone admin as a primary route only after in-app parity and successful auth/permission checks. Keep source for rollback until proven safe; never merge main/deploy production without explicit authorization.

## Acceptance definition
Every real visible button must be wired to authorized server action or truthfully disabled with reason; every query paginated and scoped; no fake stats; no duplicate ledger writes; full audit for sensitive operations; leaving admin returns to My/Profile without logout or breaking room audio; no unapproved changes to approved TotiChat visuals; QA evidence recorded per role and per module.
