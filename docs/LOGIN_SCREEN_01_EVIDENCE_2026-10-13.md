## Session and sign-out verification — final code checks (2026-10-13)

**Owner user report:** real Google OAuth login on the isolated review domain returned to the same page with `You're signed in`. This is accepted as user-observed Google sign-in success, not as proof of logout or session longevity.

**Bug found and repaired:** `auth.readProfile()` broadcasts `totichat-phase2-auth`. The Login UI previously called `readProfile()` for every broadcast and re-entered validation, producing repeated `/auth/v1/user` and `/rest/v1/profiles` requests. The isolated Login controller now deduplicates ongoing validation for the same user and fetches the profile only if missing. Visual CSS remains unchanged.

**Code CI:** https://github.com/QYEM7/TotiChatpro/actions/runs/38455731946 — 11 pass / 0 fail, including an explicit guard against recursive profile events.

**Real Chromium browser QA:** https://github.com/QYEM7/TotiChatpro/actions/runs/38455816128 — **10 pass / 0 fail**. Four actual hosted viewport tests and six isolated-browser synthetic auth session tests:
- reopen/reload same-tab signed-in session after server-stub verification;
- sign out clears local session and stays signed out after refresh;
- expired access token renews using refresh token;
- revoked/401 access token cannot display authenticated state;
- invalid/401 refresh token forces re-authentication;
- mismatch between account and token does not show cached identity as authenticated.

**Network-level public checks:** https://github.com/QYEM7/TotiChatpro/actions/runs/38452591382 — 7 pass / 0 fail on the actual staging/public HTTPS endpoints. No user credentials obtained or saved.

**Latest independent visual-preview deployment:** Vercel `dpl_9YQHs7QwtqXHRtUPXJeVrL1CBteh`, READY, public alias `https://totichat-login-review-20261013.vercel.app/`. Only this isolated review project was redeployed; the current full app, database schema/data, main branch and live voice core were not changed.

**Still not yet accepted:** real user's same-tab page refresh and real Sign out + post-logout refresh on their phone; server-side logout success cannot be attested merely because the adapter clears the browser session (it catches remote logout failures). Do not mark READY_TO_ADVANCE until user confirms manual behavior and the required access controls are checked. Closing a browser tab may discard a session held in sessionStorage; the current approved Login has no separate Remember Me control.

**Readiness:** `OWNER_APPROVED_VISUAL`; `GOOGLE_OAUTH_USER_REPORTED_SUCCESS`; `BROWSER_10/10`; `REAL_LOGOUT_PENDING`; `ANDROID_NATIVE_UNVERIFIED`; `READY_TO_ADVANCE=false`.

---

# Login Screen 01 — Progress and evidence (2026-10-13)

## Owner decision — 2026-10-13 update
- **Visual design: APPROVED BY OWNER.** Freeze the existing look, colors, overall login layout and primary Google sign-in button. No general visual redesign.
- **Technical release/readiness: NOT APPROVED; READY_TO_ADVANCE=false.**
- Fixed isolated login host allowlist to include the verified review domain. Legacy live app hostname no longer used for the standalone review sign-in.
- The standalone login page now loads a **commit-pinned** public auth adapter and config for that static deployment; the CSS was not redesigned.
- Cross-domain app handoff hidden after sign-in: the separate review site's browser session does not automatically transfer into `totichat-live-preview.pages.dev`. Do not present that as a successful same-session navigation.
- Independent Vercel review deployment confirmed **READY** and stable public alias is `https://totichat-login-review-20261013.vercel.app/`, separately from existing live app.
- Real read-only network checks: **7 PASS / 0 FAIL**, GitHub Actions run https://github.com/QYEM7/TotiChatpro/actions/runs/38452591382. Checked HTTP 200 home, Google-only deployed controller, CSS, pinned auth script CDN, Google enabled on Supabase Staging, /auth/v1/user rejects anonymous requests with HTTP 401, and the Google authorize endpoint returns HTTP 302 to Google. **A redirect to Google does not prove end-to-end callback or session establishment.**
- Latest source-level mocked adapter tests: **10 PASS / 0 FAIL**, https://github.com/QYEM7/TotiChatpro/actions/runs/38452942856. Older intermediate CI failures were test fixture/path mistakes and have been repaired; do not cite them as the current gate.
- Supabase Staging SQL read-only aggregate: 3 `auth.users`, 3 `profiles`, 3 users with Google identity, 0 existing accounts without profiles. This is historical state validation, **not a fresh Google sign-in test**.
- Chromium mobile 360/390/430px and desktop screenshot tests added at `tests/reference-fusion-login-browser.spec.mjs`. Status must be read from the latest successful browser QA run; don't report passed until runner completes.
- OAuth redirect URL intended by current web adapter: `https://totichat-login-review-20261013.vercel.app/?mode=live`. It must be explicitly allowlisted in **Supabase Staging Auth > URL Configuration > Redirect URLs**. No tool here currently provides a supported Auth config mutation, so this allowlist was not altered or verified directly.
- **BLOCKING** real Google login acceptance: an authorized user must perform the consent/login flow in a browser, let PKCE callback complete, verify actual session/profile, refresh, and test logout. This cannot be truthfully simulated with anonymous endpoint checks alone.
- **BLOCKING** Android native acceptance: no APK build authorized; native deep link and resume unverified.
- Existing main/develop code, finance, staging schema/data and real audio SDK untouched.

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
