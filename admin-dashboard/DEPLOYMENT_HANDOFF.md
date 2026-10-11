# TotiChat Admin Dashboard — Staging website handoff

**NOT DEPLOYED.** Existing Vercel project totichat-admin returned HTTP 403 (team-scope authorization denied). No website URL is claimed active.

## Confirmed Owner
The existing, email-confirmed and already-bound Supabase Staging Owner account is xxjjh20@gmail.com. No duplicate account was created or granted, and production/main were not touched.

## Deployment source
- GitHub QYEM7/TotiChatpro, branch develop/phase-2, static root admin-dashboard/.
- Supabase Staging rziaedugbdwefbefcxjt only; no app version or APK was built.
- Keep the exact falcon and app logo already in admin-dashboard/assets.
- Root Directory on Vercel: admin-dashboard; Framework: Other/static; no build step needed.

## Real connected sections
- Protected email/password and GitHub PKCE sign-in; role verified by phase3_admin_session plus a separate support operator permission check.
- Owner KPI readout using actual database summary, not fake users or balances.
- Light, responsive RTL dashboard with independent assets and secure Vercel response headers.
- WebP-only image banner upload and authenticated CRUD, 500KB maximum, scheduling, sorting, archival and unreferenced image cleanup.
- Users/rooms directory read-only (Owner and designated main partner), with bounded search.
- Host/recharge agencies, applications and reviewed commission edits; exceptional host transfers require documented investigations.
- Finance reconciliation and discrepancy details remain read-only; host diamond payroll/monthly reset not implemented.
- VIP/medal grants and revocations only by Owner and audited; host salary and rate decisions are not invented.
- Support inbox/thread/reply/status and Owner-only support staff grants.
- Staff roster and Owner-only role grants, separate main-partner designation; audit log.
- Reports with date/status filters and formula-safe CSV export.

## Outstanding release work
- Vercel Team access must be restored/reconnected. Existing Vercel project ID prj_HtogS54y4Q7jgO8QJzvsgvifCeZN belongs to team_tPaeGjO94NhupTQ8o4ZFBjOs.
- Recheck existing domain and site before replacing anything. Do not guess a vercel.app URL.
- After the official URL is verified, allowlist it in Supabase Staging Auth Redirect URLs to enable GitHub login.
- Run Owner sign-in, banner upload, staff/agency/support mutations with dedicated authorized test accounts and reversible scenarios.
- Add still-missing global user moderation, room write actions, full catalog editors, voice/FCM integration and validated host payroll when their policies and infrastructure exist.
- Enable Supabase Auth leaked-password protection (currently disabled) via approved Auth configuration.

Never put service_role keys, passwords, or private session tokens in browser source or chat.
Do not merge into main or connect the dashboard to production until explicitly authorized.
