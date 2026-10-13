# TotiChat Login 01 — Final Security Review (Web Staging)
Date: 2026-10-13 | Branch: design/totichat-ui-20261013
Status: **OWNER-APPROVED VISUAL** / **USER-REPORTED AUTH+REFRESH+LOGOUT PASSED** / **HARDENED WEB PREVIEW QA PASSED** / **RETEST AFTER SECURITY FIX & NATIVE TESTS PENDING**

## Scope & evidence hierarchy
The owner directly reported these outcomes on an Android phone using the isolated review website:
1. Real Google OAuth brought the user back to the review page and displayed `You're signed in`.
2. Refreshing the page while authenticated preserved that state.
3. Clicking `Sign out` returned to the Google login.
4. Reloading after sign-out kept the user signed out.

These are **user-observed outcomes**, not server-side proof that every stolen/replayed access token was revoked. The owner completed these observations **before** the security-hardening deployment; the final hardened build requires a short final real-user regression check.

Protected scope: original `main` and `develop/phase-2`, the existing live full-app preview, production Supabase, financial data, and LiveKit/audio core were not modified. Only this isolated **Vercel review project** was redeployed.

## Security fixes delivered (in isolated review only)
- Vendor the browser-safe `app/phase2-auth.js` adapter into `design/reference-fusion-20261013/login/auth-adapter.js` and browser publishable configuration into `backend-config.js`. These are now served **from the preview's own origin**, not executed from a third-party CDN. No secret/service-role key was copied.
- Change review adapter `signOut()` to use `POST /auth/v1/logout?scope=local` so signing out **this** phone/browser does not revoke other devices. Local session is cleared immediately. A failed remote logout now **throws**, and Login shows an explicit warning instead of reporting that server revocation succeeded. The original shared app adapter remains unchanged and will need a separately reviewed equivalent before integration.
- Add Vercel-hosted **Content-Security-Policy**: same-origin scripts, restricted Supabase network connection, no object embedding, no framing, no base injection. Also `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and no camera/microphone/geolocation permissions on Login.
- Remove inline image-error JS handler in HTML; logo fallback is implemented in same-origin Login JS. Original colors/layout/CSS not redesigned.
- Preserve PKCE verifier + expiry handling, one-time verifier removal before exchange, HTTPS approved login host, authenticated identity check, account profile validation, no fabricated session success, and no service keys in frontend.
- Prior recursive profile refresh loop remains corrected: auth/profile event deduplication prevents repeated requests.

## Automated evidence (on hardened published domain)
- **11/11** source + unit tests: https://github.com/QYEM7/TotiChatpro/actions/runs/38456627901
- **12/12** live Chromium browser / synthetic session tests: https://github.com/QYEM7/TotiChatpro/actions/runs/38456557240
  Includes 360/390/430px and desktop render, same-tab session reload, remote `scope=local` signout + reload, invalid/expired tokens, identity mismatch, remote signout HTTP 503 honest failure state, CSP and same-origin scripts.
- **8/9** latest public HTTPS/Supabase checks: https://github.com/QYEM7/TotiChatpro/actions/runs/38456898811
  Includes deployed source, security headers, real Google provider availability, authenticated endpoint 401 without token, and Google authorize initiation.
- **Current automated verification: 31 PASS / 1 FAIL** across 11 source, 12 browser, and 9 network/provider checks. The failure is a real Supabase Staging configuration violation: Email provider remains enabled (`external.email=true`) while the TotiChat beta policy is Google-only. Source/browser/published page hardening still passes. Staging settings must be fixed and provider checks rerun. Not a penetration test or native app release.
- Current isolated Vercel preview deployment: `dpl_DUPjHDDmfFrxLGEZ5J4YHrPh4J1f`, status READY, Git commit `cc243ff45c9d368cefc348a51647b9d8c6149886`. Alias: https://totichat-login-review-20261013.vercel.app/ .

## Staging RLS and database read-only checks
- `public.profiles` RLS **enabled**.
- `SELECT` role authenticated requires `auth.uid() IS NOT NULL`. This permits members to read other members' **public profile columns**, appropriate to a social app; personal/private details should not be placed in that table or exposed through this endpoint.
- `UPDATE` policy restricts `id = auth.uid()` under both `USING` and `WITH CHECK`. We did not do any authenticated cross-user write/policy penetration test. Note: the current `information_schema.role_table_grants` result only listed authenticated `SELECT` on `public.profiles`, so the profile edit feature should verify its distinct server-side write path when that later screen is reached.
- Supabase Staging security advisors returned a `WARN` about HaveIBeenPwned password checking disabled, which is **not the immediate Google-only login method** (still relevant if password login is ever enabled), and informational lint about 55 tables with RLS/no direct policies, not evidence by itself of public exposure.
- Public /auth/v1/user without a bearer token returned HTTP 401; all tests used staging/read-only or synthetic accounts, no service-role token.
- There were 3 Auth users and 3 profiles at last count (prior read), but database-level aggregates do not identify which human's current OAuth flow created which session; no sensitive account data was extracted.

## Security limitations and next screen gate
1. **JWT reality:** Per Supabase docs, even after remote logout succeeds, previously issued JWT access tokens can remain cryptographically valid until `exp`. For strictly sensitive staff/treasury operations, server code should verify `session_id` is still active and enforce authorization independently; a front-end logout UI alone is insufficient.
2. **Remote logout not independently attested for owner's real token.** The 204 and 503 cases were exercised with intercepted synthetic sessions. No user refresh token was collected or logged; this is intentional.
3. **Hardened preview needs one short owner regression**: sign in if signed out, refresh → still signed in; Sign out → Google button; refresh → still signed out. This confirms the security patch has not changed the real flow.
4. **Native Android deep-link flow** is separate and untested (APK/AAB build not authorized).
5. As directed, **do not progress to Home until screen gate approved** after the hardened-build regression; no product-wide 100% readiness claim.

## Decision
**WEB LOGIN SCREEN: SECURITY-HARDENED, GOOGLE-ONLY BACKEND POLICY NOT ENFORCED, OWNER FINAL REGRESSION PENDING.**
Owner visual design remains frozen. No production changes made.

## Primary documentation
- Supabase signing out: https://supabase.com/docs/guides/auth/signout
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase auth and redirect URLs: https://supabase.com/docs/guides/auth/redirect-urls
- Supabase advisor informational lint: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
