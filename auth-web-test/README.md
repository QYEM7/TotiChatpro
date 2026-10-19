# TotiChat — independent browser Google OAuth test

Status (2026-10-19): **source implemented; not deployed and not user-login tested**.

This standalone browser diagnostic tests the *new Flutter beta's Staging authentication contract* without creating an APK or reusing historical web clients.

## Scope
- Supabase project: `rziaedugbdwefbefcxjt` (Staging only)
- Provider: Google using real Supabase OAuth + PKCE
- No mock login, fake user, service-role key, frontend admin writes or production environment
- Browser session lives in `sessionStorage` for this tab, no local persistent app session
- `getUser()` proves the issued user token against Supabase Auth
- `phase4_verified_session` is separately called and the returned UUID must equal the authenticated user's UUID; only then is the complete result PASS
- No phone/device LiveKit test, Android deep-link test or release claim
- Not a replacement UI or approved TotiChat frontend

## Files
- `index.html` — accessible Arabic sign-in diagnostics
- `auth-test.js` — real Supabase PKCE and backend session verification
- `styles.css` — simple independent test appearance
- `vercel.json` — security headers and noindex for static hosting

## Prerequisites for usable public test URL
1. Deploy the contents of this directory to a new isolated HTTPS static site, ideally Vercel preview in the authorized team (NOT production), or a new independent Cloudflare Pages site. Never replace a live/legacy deployment.
2. Add the **exact resulting HTTPS page URL** to Supabase **Staging** > Authentication > URL Configuration > Redirect URLs. Do not use wide domain wildcards; leave the existing authorized redirects and Site URL untouched.
3. Open that exact page URL in a browser and click Google. It uses `redirectTo = location.origin + location.pathname`, which must match the allowlist entry. The Google provider must be enabled on the Staging project. The Google Cloud authorized redirect URI typically points to `https://rziaedugbdwefbefcxjt.supabase.co/auth/v1/callback`, not the test page itself.
4. After Google redirects back, look for **both** 'Google OAuth: real session' and 'Backend: matched identity' checks. If either fails, record the displayed diagnostic code only; do not paste tokens, complete redirect URLs containing `code`, or personal account details.
5. Use Log Out to clear the browser session in this tab.

## Deployment permissions blocker observed
On 2026-10-19, Vercel read tools could inspect projects under team `team_tPaeGjO94NhupTQ8o4ZFBjOs` (scope `xd-481e`), but both creating a new project and a preview deployment failed with **403 forbidden: not authorized for this scope**. A Vercel CLI fallback was not installed/authenticated in the execution environment. No Vercel deployment was created.

The owner must authorize/reconnect the Vercel connector for this exact team scope before an in-chat Vercel deployment can succeed. This is an account-side permission step that cannot be repaired by modifying Flutter or Supabase SQL.

## Verification so far
10/10 **static presence/configuration** checks passed for Staging URL, PKCE, Google provider, server RPC, tab-scoped storage, real/not-mock flows, logout, HTML references, noindex/CSP and no service-role credential. These checks do **not** prove CDN loading, deployed functionality, Redirect URLs or the real Google sign-in flow.

## Safety
- The public key is designed for browser use. Do not insert a secret, service-role key, LiveKit credential or OAuth client secret here.
- A public test page is not itself a security boundary; rely on Supabase provider policy, session verification, RLS, and least privilege.
- No changes to `main`, production, old previews or already-deployed voice functions are needed for this page.
