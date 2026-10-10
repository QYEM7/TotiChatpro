# TotiChat Google Auth no-login preflight — 2026-10-11

Project: QYEM7/TotiChatpro, branch develop/phase-2, backend sqedsnyvjblvbjbizcay.

This change adds a read-only Google OAuth initiation network probe and deterministic offline unit tests. It requests public Auth settings, and (only when Google is enabled) sends a GET authorize request with S256 PKCE and the already established com.totichat.beta://auth/callback. Redirects are handled manually: the probe never follows Google, sends a password, exchanges a code, creates an account, prints redirect state or reveals private credentials.

A valid response must redirect to accounts.google.com and specify this Supabase instance as the Google provider callback. This is partial evidence that the OAuth chain STARTS; it is NOT proof that the Android scheme is allowlisted, that Google consent succeeds, that the PKCE verifier survives navigation or that actual user sessions work.

Commands: node --test tests/google-authorize-preflight.test.mjs; node scripts/inspect-google-authorize-preflight.mjs. Optional --strict fails on provider/redirect errors but must not be mistaken for mobile QA.

CI runs the unit tests in foundation and runs the real public probe in free-landing-preview WITHOUT making the CI fail for external configuration/network limitations; check the job logs to understand the result. Absolutely no APK/AAB, SQL writes, secret output, new services, paid resources, design or Owner role changes.

The launch gate remains release_allowed=false, 63% estimated engineering / 15% measured beta readiness, and all previous T48 conditions remain unchanged. The next tests after recovery/staging: two distinct real Google accounts, verified Android callback/deep link and token exchange, profile persistence, logout/refresh, and RLS separation.
