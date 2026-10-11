# TotiChat — Owner Decision: Development Only, No Builds or Launch

**Effective:** 2026-10-11. **Scope:** `QYEM7/TotiChatpro`, branch `develop/phase-2`, dedicated Supabase Staging only.

## Approved operating mode

The Owner cancelled the previous **23 prelaunch acceptance gates as prerequisites to continued development**. Work on missing frontend and backend features, authorized isolated Staging SQL migrations, real UI/API bindings and disposable QA can continue without waiting for release sign-off.

**No application version may be built or launched under this authorization.** That includes no APK/AAB, no new distributable browser Web Preview, no automated Cloudflare publishing, no Android package assembly, no hosted deployment, no merge to `main`, no write to production and no generated new customer release. This is a **development-only** mandate, not release permission.

Automated source tests, syntax checks, isolated Postgres/Auth integration, SQL rollback safety tests, security audits and static browser source inspections are allowed. They do not distribute or activate an application version. Existing approved master visual identity, falcon, VIP frame artwork and 15 room microphone seats remain unchanged.

## Machine-enforced configuration

- `docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json`: `work_mode=development_only`, `development_allowed=true`, all historical `gates[].required=false`, `launch_conditions_active=false`, `release_allowed=false`, `web_build_allowed=false`, `apk_aab_build_allowed=false`, `deployment_allowed=false`.
- `scripts/check-development-only-mode.mjs` + `tests/development-only-mode.test.mjs` ensure the Owner policy cannot be accidentally replaced by a CI/build job.
- `comprehensive-staging-qa.yml`: all unit/security tests continue; stages invoking `npm run build`, distributable preview verification and web artifact upload are explicitly skipped.
- `live-preview-staging.yml`: source-check and Cloudflare preview publishing jobs are skipped. Both web builds and deployment are paused even if cloud credentials exist.
- `phase2-android-beta.yml`: complete APK job skipped, even upon manual dispatch.
- `royal-preview-qa.yml`: source/runtime browser checks remain, but version-build-dependent steps are skipped.
- `free-landing-preview.yml`: static landing build/upload paused.

## What still cannot be bypassed

Transaction integrity, permissions, account verification, Auth/session/RLS checks, protected owner/main-partner role separation, wallet/ledger conservation, crypto security, approved lucky-gift probability rules and host agency salary/diamond conservation remain mandatory **feature safety requirements**. Cancelling launch conditions does **not** authorize imaginary payouts, invented payroll/odds, an unsupported connection, or claiming a missing service is functioning.

The 23 historical QA observations remain in the archive as a backlog, not blocking continued coding. No release readiness percentage or Owner launch approval is implied. Re-enabling packaging, hosted deployment or production writes requires a separate explicit Owner request.
