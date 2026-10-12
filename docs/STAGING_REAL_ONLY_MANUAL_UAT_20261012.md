# TotiChat — Real-Only Staging Manual Acceptance Guide
Date: 2026-10-12
GitHub source: QYEM7/TotiChatpro, feature/in-app-admin-center-20261012
Staging Backend: rziaedugbdwefbefcxjt (DO NOT USE production)
Preview verified by Vercel metadata at 5fcc86abd816924e31433c91b602f93ed5098b32:
https://totichat-real-staging-test-20261012-rghl7qidu-xd-481e.vercel.app/
Build command: npm run build && node scripts/build-registered-staging-preview.mjs
Vercel readiness READY is NOT a substituted physical-device authenticated E2E pass. Manual browser access should still be verified from external mobile networks.

## Permanent safety boundaries
- `main`, `develop/phase-2`, `release/uiux-v1-approved` and production Supabase must remain unmodified until explicit approval.
- This is an isolated REAL Staging browser preview; no static fake room cards, no fake followers, no simulated gift ticker, no placeholder ad spaces, no fake financial summary. Empty real tables legitimately yield empty views.
- Do not seed fake public activity, invented salary liabilities, test cash or diamonds to make a screen appear populated.
- Do not make actual money transfers or pay salaries; month-end close/diamond reset is not implemented.
- A verified Owner can intentionally test audited administrative actions using existing authorized staging identities; review IDs and account scope before each write.
- Follow a new authenticated session through My/Profile -> مركز الإدارة. Never use the old standalone-admin redirect.
- Record bugs with screen, exact time, feature branch SHA, role, request/response status **without access tokens/passwords** or personal conversation content.

## Evidence from real Staging (inspection on 2026-10-12)
- Profiles: 3; rooms: 1; home_banners: 0; gift_global_announcements: 0;
  agency_registrations: 0; admin_access: 0; support_staff: 0;
  support_tickets: 0; vip_entitlements: 0; medal_entitlements: 0.
- These are observed counts, not demonstration data. Some UAT scenarios cannot be proven while these tables are empty and staff roles are not delegated.

## P0 mobile UAT pass/fail cases
1. Access preview in a phone browser; inspect TLS, mobile viewport, right-to-left labels, live-mode entry and real Staging origin. Never see the visual-only sample choice.
2. Sign in with existing Staging Owner; confirm real profile identity / real user ID; no placeholder user or artificial counters.
3. Real normal User sees no administrative entry inside My/Profile and no admin privileges via direct API.
4. Owner sees precisely ONE مركز الإدارة card in My/Profile, and none on Home/Room/main bottom bar; open / exit without another login or a Vercel redirect.
5. Inside Admin Center verify Owner read-only users/rooms/staff/agencies/transfers/audit; values and row counts come from authenticated RPCs. No fake KPI number when source unavailable.
6. Check no banner empty container on Home when verified published banners = 0; no fake feed strip when global verified gift events = 0.
7. The one existing room may appear if visible to that authenticated user under RLS; private rooms must not appear to outsiders.
8. Real social and notification buttons open live backend-bound screens; unsupported filters and room search are visibly disabled.
9. Owner VIP status query returns actual tier 0 for a user without entitlement; no requirement to enter a mutation reason for a read-only lookup.
10. Owner-only VIP and medal grants/revocations must validate input, request a reason, confirm intent, call audited RPC and never fake success. Use specifically authorized Staging accounts and reverse reversible test grants.
11. Customer-support employee (after Owner explicitly delegates to existing verified account) sees only permitted support queue and can open/reply/status real tickets; normal users cannot open staff inbox.
12. Owner staff role assignment to an existing verified account, support grant/revoke and explicit main-partner designation are gated by PostgreSQL and cannot promote Owner or infer partner by Super Admin label.
13. DB employee (only after explicit Owner grant) can open only an approved host-agency registration; cannot open recharge agencies, manage full host-agency portfolio or edit treasury.
14. Gift catalog/reports/agency month preflight use server data, no fake balances; no salary payout, closed-month reset or automatic diamond debit.
15. Sign out or change account while an Admin Center screen is open: all private views and permissions vanish; returning under an ordinary user must not show the previous role.
16. Test network loss/loading/empty/error states and retry; never fall back to sample cards or return successful write confirmation on a timeout.
17. Validate navigation with phone back controls and no unwanted logouts, focus trapping, accessibility and overflow.
18. Open a real voice room and test admin overlay while audio is active **only when LiveKit Staging is configured**; don't mark audio continuity passed until verified on two physical devices.
19. Android native login/deep links, Github/Google OAuth browser callbacks, password recovery, microphone permissions, network handover and FCM require separate on-device verification. This web preview cannot prove them.

## Known explicit NO-GO / not silently accepted
- Full agency target and host salaries/commissions/month close/diamond reset await approved business parameters and conservation/idempotency validation.
- Full global moderation, advanced room enforcement, complete banner upload/editor, all 41 UI routes/27 dialogs, native Android and end-to-end voice remain outside verified scope; no readiness percentage is implied by CI green.
- Supabase Auth redirect/reset-password reliability remains a separate defect. The single in-app administration entry avoids a second admin login but does not itself fix OAuth/deep link/password flows.
- Real two-account hosted E2E with dedicated staff roles, live gift transaction and room audio still required.
- Keep draft PR #28 unmerged pending role/money/voice QA.
