# TotiChat — Staging handoff readiness report (2026-10-12)

## Scope and artifact
Repository: QYEM7/TotiChatpro
Feature source branch: feature/in-app-admin-center-20261012
Production: NOT modified. `main` and approved UI reference unchanged.
Isolated Supabase staging project: rziaedugbdwefbefcxjt.
Latest independently inspected Vercel build: `1df5698a40bcdb02a4b574b3d0b91243703b4565`, Vercel state READY.
Isolated manual test URL: https://totichat-real-staging-test-20261012-awk9re5yo-xd-481e.vercel.app/
The Vercel preview project's SSO requirement is disabled; access from external mobile browsers is still untested.

## IMPORTANT: How to interpret percent
**Estimated readiness to START controlled manual testing: 78%.**
This is a planning score, not a measured pass rate, business promise, production readiness indicator or code coverage number.
The assessment uses the following weighted evidence-and-gap rubric:

| Component | Weight | Manual-testing readiness | Weighted points | Evidence |
|---|---:|---:|---:|---|
| Real login/account entry | 10 | 70% | 7.0 | Live Staging sign-in flow; reset/deep-link/OAuth unverified |
| Real user UI/UX navigation | 20 | 80% | 16.0 | Real-only Home, Account, empty-state guards; not all 41 views manually checked |
| Persisted backend/rooms/messages | 20 | 90% | 18.0 | Staging SQL/RPCs, earlier isolated tests, current foundation CI; 2-account E2E unverified |
| Unified administrative center | 15 | 85% | 12.75 | Actual RPCs for roles/support/VIP/medals/rooms; real Owner/partner/DB interactive checks outstanding |
| Honest feed/events/banners | 10 | 90% | 9.0 | No fabricated rooms/people/gift activity in live mode, banners require existing real Storage object |
| Repeatable Staging CI and web preview | 15 | 90% | 13.5 | Real-only preview build passes, Vercel READY, not phone E2E |
| Live 2-device audio | 10 | 20% | 2.0 | Two Edge Functions ACTIVE; dedicated LiveKit secrets/service and actual audio are unverified |
| **Total** | **100** | **78.25% ≈ 78%** | **78.25** | **Conditional/manual** |

This metric does NOT mean the full product is 78% ready for paying end users; commercial launch readiness is lower, and no credible final percent can be certified without E2E and signed business requirements.

## New implementation in current feature branch
- Unified TotiChat Admin Center in My/Profile, one role-gated entry.
- Server-authorized Owner/main partner directories, owner staff grants, customer-support inbox, support replies and ticket status, scoped DB host agency authorization.
- VIP and medal Owner mutation via existing audited RPC, confirmed input and request-key dedupe.
- Room-scoped administration ban/unban via `phase6_admin_room_action`, reason required, protected actors not targetable.
- Banner edit form with real authenticated WebP upload to `totichat-admin-banners`, Storage RLS, audited create/update/publish/archive/delete with no fake records. Requires real Owner signed-in test.
- In live mode, fake agency staff/balances/orders prototype and 15-tier VIP illustrative gallery are disabled (the actual backend allows 10 VIP levels).
- Fake room cards, fake counts, artificial marketing hero, empty ad strips and unverified gift ticker are removed/hidden in real mode.
- Real notifications/social navigation; unimplemented search/categories are visibly disabled, not fictional.
- Better focus trap and logout account-state cleanup, no second admin login or redirect.

## Verified Staging data (snapshot)
3 profiles, 1 room; zero home ads, zero verified worldwide gift announcements, zero agency registrations, zero privileged staff grants, zero support staff, zero support tickets, zero VIP grants and zero medal entitlements. Zero rows are legitimate and not sample content.

## Green automated checks already observed
- In-app Admin Center authorization/JS tests
- Real-only preview config and no fake data build test
- Phase 2 isolated foundation QA
- T36 host-month read-only browser QA
- T42 support browser QA
- Royal frontend browser QA (latest exact-SHA status should be checked before signoff)

Readiness from CI is limited to what suites test. It does not prove browser OAuth, final visual approval, RLS across all roles, camera/mic permissions, or voice. No test money or invented users were inserted.

## Required manual acceptance scenarios
1. Login on the actual preview using two legitimate Staging accounts and test real email/password, sign-out, account swap. Record only status/error, never credentials.
2. Normal account cannot see Admin Center or access admin RPCs. Owner sees exactly one entry in My/Profile, not in Home or room.
3. Test existing room discovery/join/leave; create/edit room, 15 seats, invite, chat, and seat conflict on two accounts.
4. Verify blank ad/activity in zero-data states. Submit a genuine banner image as authorized Owner, publish it to Staging, verify it appears once, then archive it and verify disappearance.
5. Owner explicitly delegates a dedicated existing, email-verified staff test account; test CS/DB and Super Admin restrictions. Main-partner designation is separate; never assume generic Super Admin has that authority.
6. Create one real support ticket from a test account; staff views/replies/status; verify account isolation and audit.
7. Test one VIP/medal grant and revocation to an approved testing account (Staging only), ensuring both sides reconcile. No fabricated paid balance.
8. Owner/moderator bans and unbans in an actual room, verify server refusal for protected accounts.
9. Background/resume, Android network changes, image upload compression, form validation, keyboard focus, room minimization without loss of seat/audio.
10. Require LiveKit project-specific configuration and simultaneous two-physical-phone audio before marking any voice task passed.
11. Verify Google/GitHub redirect allowlists, password reset and Supabase Auth anti-leaked-password setting separately; the old redirect incident is NOT claimed fixed.
12. Do not execute real-money settlement/coin issuance or monthly diamond reset until business rates and conservation tests approved.

## Blockers — DO NOT mark 100%
- No confirmed dedicated Staging LiveKit credentials nor physical 2-phone voice test.
- No successful hosted Owner/normal user/CS/DB/multi-role browser E2E.
- OAuth callback allowlist/password reset and native deep links not confirmed for this exact preview origin.
- Genuine gift/agent cash settlement, charge amounts, agency commissions, host payroll and month-end diamond reconciliation not end-to-end validated. Close/reset remains disabled.
- Some of 41 screen routes and 27 auxiliary interactions remain UX-only or have locked unavailable features; native APK not built for this scope.
- Auth leaked-password protection warning remains: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- 51 intentional RLS-without-direct-policy INFO findings on private tables require contextual review, not wholesale policy relaxation: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- Browser preview launch HTTP from independent unauthenticated phones could not be established via connector alone; user-owned physical manual check is necessary.

## Acceptance decision
**CONDITIONAL GO for controlled web-based manual tests on Staging; NO-GO for treating these tests as completed or delivering a fully verified app.**
Keep GitHub PR #28 as DRAFT. Do not merge into main, change production, create fake records, pay agents, or publish a real-user release.
