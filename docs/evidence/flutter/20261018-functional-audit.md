# Functional development batch — 2026-10-18

Scope: QYEM7/TotiChatpro / rebuild/flutter-v1; Supabase Staging
rziaedugbdwefbefcxjt. No main/production write, deployment or APK/AAB build.

## Design discovery

- Repository Markdown/JSON did not identify a Figma design URL.
- Figma account connection works, but available tools require an existing file
  key and do not enumerate/search the user's design files by title.
- Library inventory from October 16–18 includes Flutter review images/bundles
  and extracted web/Android UI references. The read UI inventory lists React
  source files; it is not proof of Flutter design approval.
- Prior-context search found rejection of the former Reborn client and requests
  to review the newer Flutter screens, but no explicit approval of those screens.
- Latest generated login reference: new_login_flutter(1).png, October 18.
  Generation date is not approval. No old design was promoted to approved.
- Required owner decision: identify the approved design with one exact Figma
  link or existing reference filename. Visual approval remains unresolved.

## Implemented behavior

1. DM send now validates the live Staging receipt contract: sent=true,
   positive safe integer message id, boolean replayed. Incomplete receipts
   throw before the caller clears its pending request or draft.
2. Realtime gift events now reject malformed/noninteger totals without a cast
   exception, enforce >=7000 coins, reject events older than exactly 30 seconds,
   and reject timestamps over five seconds in the future. Five seconds allows
   bounded client/server clock skew. No visual layout changed.

## Backend checks (read-only)

Extracted 56 literal RPC names from Flutter source and checked pg_proc grants:
56 present and executable by authenticated; 0 executable by anon; 0 failures.
This checks endpoint existence and grants, not role-specific authorization or
end-to-end success. Computed/dynamic RPC names are outside this extraction.

Read phase3.phase2_dm_send definition directly from Staging: both fresh and
replayed success paths return id, sent=true, replayed boolean. Fresh responses
do not include created_at, so that field is intentionally not required.
Verified gift_global_announcements is in supabase_realtime publication.

## Test evidence

- Prior baseline 479b4dc: GitHub QA success, run 39157511598.
- Packaging regression rerun locally: 6 passed, 0 failed.
- New Flutter regression file: message_and_gift_receipts_test.dart (4 tests,
  including invalid receipt matrices and exact timestamp boundaries).
- Code change: fd30e21300f5892c7f7e5c3dba346c1fe58e0544.
- Full Flutter QA: https://github.com/QYEM7/TotiChatpro/actions/runs/39157905820
  SUCCESS: static analysis, Flutter source/widget tests, packaging regression,
  Staging configuration and no-APK checks all passed. No local Flutter SDK is available.
- git diff --check passed locally.

No screen is declared visually complete. Device audio, live financial flows,
new-client OAuth and approved-design visual comparison remain separate gates.
