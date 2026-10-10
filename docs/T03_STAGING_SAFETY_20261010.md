# T03 — Isolated staging and secrets protection (2026-10-10)

GitHub QYEM7/TotiChatpro; production Supabase sqedsnyvjblvbjbizcay.

## Read-only audit
- Supabase production was healthy with 32 recorded migrations.
- Branch inventory had zero isolated Supabase branches.
- The tracked .env.example is a template; it does not prove OAuth/SMTP/LiveKit/TURN secrets are configured.
- app/config.js contains the intended PUBLIC Supabase publishable key and production URL. Do not treat a public publishable key as an exposed service-role secret.
- Real E2E sends real gifts/transfers and must not use production or mock balance.

## Changes
- Ignore every dotenv file except .env.example.
- Build staging runtime with: npm run build:staging
- Build script modifies ONLY dist/app/config.js using STAGING_SUPABASE_URL and STAGING_SUPABASE_PUBLISHABLE_KEY from ignored local configuration.
- Reject the production Supabase URL, non-HTTPS arbitrary domains and private/service_role keys.
- Global Playwright setup fetches the ACTUALLY SERVED app/config.js and compares it to the requested staging endpoint, rejecting production or mismatched deployments before any financial operation.
- Playwright local web server serves dist; source app and approved UI are unchanged.
- CI runs tests/t03-staging-safety.test.mjs.

## Operating procedure (requires separate Supabase staging first)
1. Approve any new Supabase branching/project compute charges, then provision a separate database/Auth/Storage instance. Never copy production data to the test project.
2. Verify all 32 canonical migrations on that instance, ideally by a fresh installation/replay.
3. Add STAGING_SUPABASE_URL, STAGING_SUPABASE_PUBLISHABLE_KEY, two confirmed staging test users, credentials, a staging TEST_ROOM_ID and optional TOTP secrets to ignored .env.local or protected CI secrets. Never commit them.
4. Run npm ci, then npm run test:real-e2e:staging. No fake balances are created; fund only by an authorized staged issuance.
5. Check auth, RLS and E2E logs without exposing private secrets. Delete ephemeral resources when no longer needed.

## Blockers and caveats
- A Supabase hosted branch is a BILLABLE resource. Documentation: https://supabase.com/docs/guides/platform/manage-your-usage/branching. Published Micro compute reference starts near USD 0.01344/hour plus possible usage, and branches are not covered by Spend Cap; exact costs depend on the organization.
- No hosted staging branch, real test accounts, signed-in E2E transactions or verified DB restore have been created by this change.
- This is not a full PostgreSQL backup. Do not run production db reset/push while configuring staging.
