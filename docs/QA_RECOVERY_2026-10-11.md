# TotiChat QA Recovery — 2026-10-11

## Scope
- Repository `QYEM7/TotiChatpro`
- Branch: `develop/phase-2`; **no production deployment, no production DB writes**.
- Verified source commit: `725ab0a285ecea38f76ddb7e9a2de953ebe630c0`.
- STAGING database `rziaedugbdwefbefcxjt` remains the test-only backend.
- Approved visual design and 15 microphone seats preserved.

## GitHub Actions evidence — PASS on exactly the same commit
1. [Phase 2 isolated foundation QA — PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38139562769)
2. [Royal frontend browser QA — PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38139562729)

These tests include source assertions, browser navigation/flows with controlled mock responses, native-web-root startup, responsive login layouts, catalogs, catalog administration, wallet UI, relationships, agencies, support tickets, WAV receipt playback, session logout and native-voice **failure-closed** behavior.

Separately, [real isolated web preview source build — PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38138700109). This source build uploaded an artifact. Its **Cloudflare publish-preview job was skipped**; no latest public deployment is evidenced here.

## Fixes this QA pass confirmed
- Removed incorrect vacant-seat "locked" appearance while preserving all 15 decorative seat frames.
- Revoked locally stale voice sessions if authenticated user loses room membership; microphone publication now stops after moderator mute / removal, or connection is torn down if stop fails.
- Stripped visual-review sample room members, text chat and fictitious gift donor/portraits from authenticated live room before confirmed real data.
- Changed gift ticker to use confirmed transaction's gift icon and data.
- Prevented duplicate support module loader/duplicate handlers.
- Updated obsolete browser tests to intercept **isolated Staging ONLY**, refusing the production database, using current `phase2_room_members_visual` and other real RPC route names.
- Validated hardened LiveKit token grants and 20 requests/min durable PostgreSQL limiter before token issuance; no bypass of auth/rate limits.
- Replaced stale test assumption of three mandatory public ads: **zero genuine official banners is valid** until an administrator publishes real content. All existing published banners are verified.
- Updated strict visual-master test to whitelist **exactly** externally loaded feature files while still checking original approved markup byte-for-byte.
- Fixed browser test click selectors to choose visible catalog/reports/agencies actions in account sheet, rather than hidden duplicates.

## Remaining external acceptance blockers — NOT PASSED
- LiveKit secrets/operational SFU must be configured for STAGING separately; `phase2-voice-token` being `ACTIVE` alone does **not** prove the voice session works between two physical phones.
- Physical Android phone microphone, speaker, mute, disconnect, background/minimization, gifts and network-switching tests with two authenticated, unrelated real accounts.
- Real-authorized wallet and gifts test with fully audited and approved Staging funds; **never seed fake production coins**.
- Full agency financial payroll month-close conservation and authorized reset; the currently implemented closed-month report is read-only, no salary or automatic diamond clearing.
- Backup and restore validation and isolated Staging/production change control.
- Supabase Auth leaked-password protection remains disabled (security advisor warning).
- Release/Google Play signed APK is **not authorized** until the release-readiness gates pass.
- Real Cloudflare/Vercel deployment on the agreed public preview URL is not confirmed. A source-build PASS does not equal a published preview.
- Previously approved design remains unchanged. Visual inventory is not evidence of every screen/backend feature being operational.

**Delivery gate:** development/QA source is now green at the cited commit, but user-facing production readiness is **NO-GO** pending the checks above.
