# TotiChat — Backend Only (Project 01)

This branch intentionally contains **only server-side resources and backend validation materials**. All previous Flutter, Web, Capacitor, preview UI, themes, fonts, visual assets, layout templates, and frontend deployment workflows have been excluded.

## Retained
- Supabase SQL migrations, functions, tests, reference catalogs in `supabase/`.
- Backend-related scripts, tests and technical reference docs.
- Staging Supabase project ID: `rziaedugbdwefbefcxjt`.

## Not included
- `flutter_app/`, `app/`, `assets/`, `site/`, `reference/`, `e2e/`, root web entry, Capacitor config, frontend NPM packaging, legacy UI CI/deploy workflows.

## Rules
- Do **not** deploy or run schema migrations automatically. The existing remote Supabase Staging and production databases are unchanged by this repository commit.
- Do not build an APK/AAB.
- The new approved interface will arrive from a separate user-supplied repository. Only that source may determine the UI/UX and visual identity.
- Never infer that legacy deployments are disabled: web hosts must be separately deactivated or protected, and historical Git branches still exist.
- This branch was constructed from `rebuild/flutter-v1` commit `4bafebd67b598c0fc4eb3558fa0e5bf5e9d8bdda`. Recovery branch: `backup/pre-backend-only-20261019`.
- Backend scripts are retained as reference; their dependencies and runtime behavior must be checked before execution.
