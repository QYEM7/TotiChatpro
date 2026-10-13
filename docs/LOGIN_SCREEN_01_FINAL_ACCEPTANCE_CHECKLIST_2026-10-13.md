# TotiChat Login 01 — Final acceptance checklist
Updated: 2026-10-13 (Baghdad) | Isolated design/review branch: `design/totichat-ui-20261013`
**Decision: NOT READY TO ADVANCE.** Visual approval remains frozen. Do not build APK or modify production/main/develop.

## Current evidence
- User confirmed real Google sign-in and successful session refresh, sign out, and signed-out refresh on Android before security hardening.
- Hardened review preview is live: https://totichat-login-review-20261013.vercel.app/ .
- Source/unit CI: **11/11 passed** https://github.com/QYEM7/TotiChatpro/actions/runs/38456627901
- Hosted Chromium browser checks, including synthetic session/refresh/revocation: **12/12 passed** https://github.com/QYEM7/TotiChatpro/actions/runs/38456557240
- Latest staging public Auth, security headers, provider, and unauthenticated API recheck: **8/9 passed; 1 fail**. Re-run attempted on GitHub Actions attempt 2, 2026-10-13T20:35Z, https://github.com/QYEM7/TotiChatpro/actions/runs/38456898811
  - `external.google = true` — PASS.
  - `external.email = true` — FAIL Google-only backend policy. Email was still enabled in the auth service *after the user reported changing settings*. This can mean wrong switch, unsaved setting, wrong project, or a configuration propagation issue. Do not assume which.
  - `/auth/v1/user` without token HTTP 401 — PASS.
  - Google authorize endpoint HTTP 302 to Google — PASS, not OAuth callback E2E.
  - Hosted code+CSS+headers+CSP/logout behavior — PASS.
- Supabase Staging project **rziaedugbdwefbefcxjt**: `public.profiles` RLS enabled, owner-constrained UPDATE policy with check present; its authenticated SELECT policy intentionally permits all logged-in members to read public profile data.
- Security advisors: informational lint for RLS-enabled/no-direct-policy tables (55) and leaked password protection warning (relevant only if password provider is enabled later). See official Supabase docs.

## Blocker: shut off server-side Email authenticator
1. Open https://supabase.com/dashboard/project/rziaedugbdwefbefcxjt/auth/providers and ensure project ID matches `rziaedugbdwefbefcxjt`.
2. Open **Email provider** (not only Email Confirmations / Allow new users to sign up).
3. Turn off **Enable Email provider**, save and verify persisted state after page reload.
4. Leave **Google** enabled.
5. Re-run same read-only provider probe using `tests/reference-fusion-staging-auth-probe.mjs`. Expected: `external.google === true`, `external.email !== true`, no other provider enabled, nine of nine tests green.
**Do not adjust auth users, OAuth secrets, production settings or the application design** to bypass this blocker.

## Final one-screen manual acceptance tests (on hardened preview)
Use the same phone and browser tab and never send account tokens, authorization codes, or screenshots of sensitive browser storage.
1. Open https://totichat-login-review-20261013.vercel.app/ and tap **Continue with Google**. Finish Google consent only on the legitimate Google domain. Return to same site. **Pass:** `You're signed in` shows with the real authenticated account and no errors.
2. Refresh page once while signed in. **Pass:** `You're signed in` remains, with no OAuth loop or repeated sign-in request.
3. Tap **Sign out**. **Pass:** Google button appears, no `server could not confirm session revocation` warning. That warning is a **failure** even if local login UI is cleared.
4. Refresh page once after Sign out. **Pass:** Google button remains, and the verified account is not redisplayed.
5. Optional repeat Google sign-in into the **same account** and confirm no duplicate profile. **Pass:** same account identity, no repeated profile, no arbitrary new user-visible ID.
6. Check layout/buttons on Android mobile and, if possible, narrow browser width. **Pass:** approved light theme unchanged, no clipped elements, no unsupported Apple/phone/email sign-in or phantom balance.
7. Confirm logout behavior with networking intentionally disabled **only as an isolated test**, if desired: UI must show local signed-out state AND explicitly warn that server revocation was not confirmed. Never label such a case fully secure logout. For sensitive operations, JWT can remain valid until expiry even on server sign-out.

## Final gate
- Visual owner approval: **PASS**.
- Prior phone Google sign-in/session/logout: **PASS, but performed before latest security patch**.
- Source code automated checks: **PASS**.
- Browser session testing (mocked backends): **PASS**.
- Backend Google-only policy: **FAIL (Email still enabled at last read)**.
- Hardened-build *real* phone end-to-end rerun: **PENDING**.
- Native APK OAuth/deep-link: **NOT TESTED / no APK approved**.

**Advance to Home only when Email is confirmed disabled and the owner validates the hardened web build end-to-end. Native app acceptance is separately gated before APK release.**
