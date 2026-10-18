# Development baseline — 2026-10-18

## Verified identity

- Repository: QYEM7/TotiChatpro.
- Active rebuild: rebuild/flutter-v1, flutter_app/.
- Audited source commit: df5de73169877d48b0e08b1b27869bace3b41813.
- main observed at e19707abbca40f62b4494c2d95c1187dd7c27b08; not modified.
- develop/phase-2 observed at fd28a3d453802c356ddadacdae4deff6efc74bd5; not the active Flutter source.
- Preview branches are not authoritative development sources.

## Finding and implemented correction

Root README still described the old prototype as approved. Root npm build invoked
scripts/build-reborn-web.mjs, which packaged app/ using Capacitor-compatible web
output instead of flutter_app/. This is a confirmed path to the wrong client;
it is not proof of how the previously rejected APK was produced.

Added active-client.json, corrected README, and blocked the legacy packager before
any output deletion, copy, or bundler execution. Unknown or malformed client
manifests fail closed. Historical branches without a manifest retain compatibility.
The regression suite is now part of Flutter QA.

## Evidence

- Existing Flutter analysis, source/widget tests and Staging/no-APK checks passed:
  https://github.com/QYEM7/TotiChatpro/actions/runs/39114681016
  This result belongs to df5de731, not later changes.
- New local regression: node --test tests/active-client-packaging.test.mjs:
  6 passed, 0 failed. Includes invoking the real legacy packager and verifying
  rejection before the bundler loads. git diff --check passed.
- Supabase list_projects verified rziaedugbdwefbefcxjt is TotiChat Staging,
  ACTIVE_HEALTHY. Read-only pg_class/pg_namespace query returned 50 public tables,
  50 with RLS enabled. Policy correctness and live transactional behavior are
  NOT established by this count. No database writes performed.
- Figma whoami succeeded. No Figma design URL found in repository Markdown/JSON;
  visual parity remains unverified pending identification of the intended file.
- Flutter SDK unavailable locally. No claim of a fresh local Flutter test run.

## Remaining acceptance

New-client visual approval, real Google login, two-device audio, and financial
end-to-end behavior require independent evidence. Existing green CI does not
establish those results. No APK/AAB was built, no deployment was triggered, and
production and main were not changed.
