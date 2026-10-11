# TotiChat Admin Dashboard

An independent, premium, responsive RTL administration website. Source root: `admin-dashboard/` on `develop/phase-2`. Uses **Supabase Staging only**.

## Verified Staging Owner
`xxjjh20@gmail.com` is the existing email-confirmed Owner account, correctly bound in `phase3.system_authority`. We did not create or transfer ownership. Staff cannot promote themselves to Owner. Main partner is a separate explicit designation.

## Implemented source and server RPC connections
- Email/password and GitHub PKCE login, with database-checked admin and support authorization (GitHub OAuth redirect registration needed for real hosted sign-in).
- Premium light falcon branded sidebar, responsive navigation, search, accessible dialogs/forms.
- Actual owner KPI summary and real reports with date/status filters and CSV export; no fabricated balances.
- Static WebP image banner management with compressed <=512000-byte uploads, draft/publish/archive, schedule, order, approved internal destinations, and Storage API cleanup.
- Read-only user and room directory with server permissions and bounded pages.
- Host/recharge agencies with live lists, new-agency request decisions, explicitly entered commission, agency edits, and investigated exception handling for transfers.
- Host diamond accrual review and financial mismatch audit; no salary settlement or automated reset.
- Owner-only VIP grant/revoke and medal creation/grant/revoke via server audited procedures.
- Real customer support inbox, reply and status changes; Owner can appoint or revoke support workers.
- Real staff roster and read-only security audit; Owner-only staff role assignment, partner designation requires explicit action.
- Real gift catalog listing. Global catalog mutations need safe field-specific editor and remain disabled.

## Security
- Browser holds only a publishable Supabase key; NO service role; all admin mutations are verified again by database code.
- Source includes a restrictive Content Security Policy, noindex headers and clickjacking prevention.
- Administrative request responses are discarded after authenticated account changes.
- The existing consumer app, production database and `main` branch are not modified.
- No real transactions, user records, VIP or salaries were invented.

## Scope still needing engineering and approval
- Admin user bans/room enforcement writes, full safe product catalog editing, full dashboards for agents/host payroll, XP and business rules.
- Real authorized account E2E, real banner image upload, cross-device tests, verified security reviews and auth settings.
- Vercel is currently NOT accessible: existing project `totichat-admin` returned HTTP 403 for team scope, and cannot be published by this session.
- Once Vercel access is restored, use Root Directory `admin-dashboard`, Other/static, no build command; verify project domain, then allowlist that exact HTTPS URL in Supabase Auth.
- Staging security advisor still warns that leaked-password protection is disabled.

See `DEPLOYMENT_HANDOFF.md` for the exact official-site checklist and Vercel permission blocker.

## Local source preview
From repository root run a local static server such as `python3 -m http.server 8080` and visit `http://localhost:8080/admin-dashboard/`. Authentication requires an authorized Staging account and valid Auth redirect where applicable.
