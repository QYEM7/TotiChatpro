# TotiChat — Zero-Budget Infrastructure Sprint 1: actual execution report
**Date:** 2026-10-10 | **Repo:** `QYEM7/TotiChatpro` | **Branch:** `develop/phase-2` | **Approved budget:** $0

> This report separates **source code implementation**, **read-only external-provider detection**, and **real deployed integration**. Passing GitHub CI is not proof that the voice chat beta is ready on two phones.

## Verified delivered work
1. **Static Cloudflare Pages landing source**: `site/index.html` (Arabic RTL and mobile, official original falcon logo, clearly NO current APK download), `site/privacy.html` (honest prelaunch *draft* privacy notice), `site/_headers` (CSP, clickjacking/referrer/content security headers). Not deployed.
2. **Build script**: `node scripts/build-free-landing.mjs` copies trusted logo/HTML/headers into `dist-free-site/` with zero Gradle, Java or npm dependencies and no APK.
3. **GitHub CI**: `.github/workflows/free-landing-preview.yml` performs static-build + tests + read-only public Google provider check and uploads a **site preview ZIP ONLY** (not an APK). [Successful CI run](https://github.com/QYEM7/TotiChatpro/actions/runs/38072658783), [artifact](https://github.com/QYEM7/TotiChatpro/actions/runs/38072658783/artifacts/11676754466) (first verified upload; latest run has its own same-name artifact).
4. **Free-vendor guardrail**: `docs/free-tier-service-policy.json` tracks actual vs pending providers, billing traps (R2, Firebase Storage/Blaze), unique Supabase source of truth, consent prerequisites and owner-zero-dollar ceiling. Tested.
5. **Real read-only Google provider status probe**: `node scripts/inspect-google-auth-readiness.mjs`, only checks public Supabase GoTrue provider settings. CI run observed `google: false`, `apple: false`, `facebook: false`, `android_callback_verified: false`. **Google-only beta is not operational; Google Cloud client plus Supabase provider/Android callback still must be configured and verified.**
6. **Read-only Supabase audit**: production project `sqedsnyvjblvbjbizcay` healthy, 32 applied migrations, no hosted branches, voice Edge function deployed. Repo contains 42 migrations, leaving 10 pending. Production advisor showed 5 unindexed FK lint INFO and 24 no-RLS-policy lint INFO; many no-policy internal tables are intentionally denied. Do not treat lints as proven exploitable vulnerabilities or blindly grant external access.

## Bounded 10-item infrastructure sprint snapshot
| Item | Status | Scope |
|---|---|---|
| Z01 | read_only_audited | Read-only Supabase production migration/branch/services audit |
| Z02 | code_tested_not_deployed | Cloudflare-ready static official website and privacy draft |
| Z03 | code_tested | Zero-billing service audit/selection machine policy |
| Z04 | code_tested_and_probe_run | Google Auth provider public live read-only readiness probe |
| Z05 | blocked_missing_cloudflare_account_connection | Public Cloudflare Pages deployment URL |
| Z06 | blocked_google_provider_disabled | Configure real Google OAuth and Android callback |
| Z07 | blocked_missing_livekit_credentials_and_device_proof | LiveKit real voice configuration and two physical Android tests |
| Z08 | blocked_missing_firebase_project_registration | Firebase Spark native FCM and Crashlytics |
| Z09 | blocked_missing_verified_external_restore_and_staging | Encrypted offsite production DB+Storage object restore and independent staging |
| Z10 | blocked_release_gate | Full mobile E2E, Owner release signoff and APK after gate |

**Preparatory sprint: 4/10 items completed in code/audit (40% preparatory work only).** This metric includes non-deployed source files; it MUST NOT be interpreted as user-facing availability. **Official app scores remain 63% engineering / 15% genuine beta readiness.** `docs/release-readiness.json` unchanged, zero tasks `verified_live`, `release_allowed=false`.

## What blocks the next safe steps?
- **Cloudflare Pages**: Owner or connected Cloudflare account must create the free Pages project and deploy `dist-free-site`. Build command `node scripts/build-free-landing.mjs`; publish directory `dist-free-site`. Only deploy the site after the Owner reviews the prelaunch privacy notice; no real APK link.
- **Google OAuth (required and currently OFF)**: Owner must create/configure Google Cloud OAuth client securely and enable provider in Supabase Dashboard; callback is `https://sqedsnyvjblvbjbizcay.supabase.co/auth/v1/callback` for Google and `com.totichat.beta://auth/callback` for Android app after approved redirect allowlisting. The existing app PKCE callback code exists but MUST be tested on two actual phones. Never paste Google Client Secret into repo/chat. Do not disable previously-working admin login until verified migration/mapping.
- **Voice**: Need LiveKit Build account/credentials and TURN verification, configure secrets in dashboard and physically test microphones/permission revocations/reconnect on two Android devices.
- **Firebase**: Need Spark project and Android app registration. Do NOT switch to Blaze or link billed Firebase Storage. Check consent/privacy and no sensitive analytics.
- **Staging/backup**: Production and object backups plus an external encrypted restore must be independently verified before updating ten production migrations. Supabase hosted branches can incur charges; no paid branch creation was authorized.
- **Finance**: Owner/agent ledger and manually approved immutable monthly host salary liabilities must still be proven hosted, secure and not zeroed before recording entitlement. Luck gifts also require fixed published probabilities, an audit trail and compliance review; existing VIP tiers must truly purchase and activate.

## Release protection
T48 remains DENY: **engineering >=80%, beta readiness >=80%, >=40/50 `verified_live` with evidence, all nine deployment/audio/backup/finance/security/mobile flags, named reviewer/date and explicit Owner APPROVED**. No APK/AAB built, no production data changed, and no paid account or card activated. Protected UI, 15 mic seats, VIP/gifts remains intact.

## Verification
- [Final static-site and Google readiness run](https://github.com/QYEM7/TotiChatpro/actions/runs/38072658783) — success.
- [Full foundation QA baseline for this sprint](https://github.com/QYEM7/TotiChatpro/actions/runs/38072639435) — success (source updates at that point).
- Code touched: static landing, offline site builder, free-vendor policy, public OAuth inspector, new tests and independent GH workflow. **No database or Android/source UI modifications.**

## Next authorized implementation
Do not start a new paid or complicated service. When connection is available, link Cloudflare Pages Free and stage static site. Finish Google provider setup and test login in isolated staging; then LiveKit real voice. Independently restore production DB+Storage backup before migrating production. Set up Firebase Spark only if existing notification/crash work is ready, and do not replace Supabase for identity/finances.
