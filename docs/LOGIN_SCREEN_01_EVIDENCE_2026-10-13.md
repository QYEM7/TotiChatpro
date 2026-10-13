# Login Screen 01 — Progress and evidence (2026-10-13)

## Current decision
**Screen-by-screen workflow: APPROVED by owner.**
**Login screen itself: NOT APPROVED.**
**READY TO ADVANCE TO HOME: NO.**

## Delivered on isolated design branch
- `design/reference-fusion-20261013/login/index.html` — Google-only new TotiChat login visual.
- `design/reference-fusion-20261013/login/login.css` — light luxury responsive shell, mobile and wide split screen, focus indicators, reduced motion.
- `design/reference-fusion-20261013/login/login.js` — existing `TotiPhase2Auth` adapter integration: Google provider, approved-host guard, offline/error states, verified session, logout, controlled same-origin handoff.
- `tests/reference-fusion-login.test.mjs` — visual source and isolated adapter-behaviour tests.
- `.github/workflows/reference-fusion-login-qa.yml` — design-only CI on branch; no APK and no deployment.

## Verified at source/test level
GitHub Actions run: https://github.com/QYEM7/TotiChatpro/actions/runs/38448769044
- Status: completed, conclusion: **success**
- Automated tests: **10 pass / 0 fail**
- Tests cover the presence of a single Google sign-in, mobile/accessibility contract markers, no fake account logic, host allowlist check, offline behavior, provider disabled behavior, authenticated session guard, expired/rejected server validation, and logout adapter calls.
- These are source assertions and mocked adapter behavior checks, **not a real Google login nor an actual visual screenshot/browser/device pass**.

## Remaining required before a Login-screen readiness claim
1. Publish the isolated review login to an **approved HTTPS preview** (there is no confirmed public preview URL from this branch yet).
2. Configure and verify exact Supabase Staging OAuth redirect allowlist for the chosen **review callback** without touching production or broadening allowlists unnecessarily.
3. Test with a real Google account: redirect, PKCE, returned auth code exchange, session resume, real profile, logout, expiry, and hostile/replayed callback.
4. Browser screenshot tests at 360/390/430px; compare screenshot against owner-accepted multi-screen visual board. Ensure original falcon artwork is visually appropriate. Test keyboard, tap, RTL/localization and slow/offline network.
5. Obtain owner **visual approval** separately; fix any rejection before progressing.
6. Native Android OAuth deep-link on physical device still not verified. No APK/AAB builds are authorized here.

## Explicit non-changes
- No Supabase write operations.
- No changes to main, develop/phase-2, live preview app, original UI, finance, rooms, audio SDK, or users.
- No mock/seeded accounts or success events.
- No app release or claim of 100%.

## Next screen
**HOME: BLOCKED** until Screen 01 owner approval plus its mandatory tests, consistent with the workflow agreement.
