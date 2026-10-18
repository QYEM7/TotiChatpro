# TotiChat Flutter rebuild — Design identity / Voice room review (2026-10-18)

## Scope and approval
- Development repository: `QYEM7/TotiChatpro`, branch `rebuild/flutter-v1`, client `flutter_app/`.
- New **separate** Figma file created in the owner-selected **Code Master** team:
  https://www.figma.com/design/SOd2UObArmsne0dVVJjrl6
- Editable nodes: voice room `2:31`, empty gift bottom sheet `2:32`, identity/design-system board `2:33`.
- Figma includes new light color and spacing variables, a reusable empty-seat component `2:23`, and a primary-button component `2:295`.
- Design status: **owner visual review pending**, not approved or production ready.
- Existing Figma files remain archive-only. The logo graphic in the new Figma file is a *symbolic editable exploration*, not a verified replacement for the actual FalconMark image asset used in Flutter.

## Implemented in the real Flutter source
- Added `lib/features/room/room_identity_header.dart`. The real live `RoomScreen` uses it for room title and optional welcome text from the server, without fake activity.
- Removed the duplicate inline welcome-message section in `room_screen.dart`.
- Existing LiveKit connection, 15-seat actions, server-backed seat visuals, gifts, DM and room-exit logic were not rewritten.
- Added a real Flutter-rendered **isolated visual review** with 15 empty seats. It is not an authenticated room session, device voice test, live gifts, or claim of end-to-end correctness.
- Linked the new file URL in `active-client.json` with `owner_visual_review_pending`.

## Automated evidence
- Flutter static analysis, widget/source tests, packaging guard, staging and no-APK checks: **SUCCESS**
  https://github.com/QYEM7/TotiChatpro/actions/runs/39160106262
- Genuine Flutter screenshot capture (review artifacts with empty room, login, empty Home, empty gift sheet): **SUCCESS**
  https://github.com/QYEM7/TotiChatpro/actions/runs/39160098043
- Artifact: `totichat-new-flutter-visual-review-dfc6d74f1b19e120d8d54b9976702b02484d1e47`; contains `new_room_empty_flutter.png`. Artifacts have limited retention.
- Capturing an isolated visual-only review does not establish pixel-perfect parity with the whole live room.

## Findings and remaining acceptance gates
1. Figma visual language uses Arabic sample copy, while Flutter review uses explicit English review-only copy. Localization is not yet reconciled.
2. Figma falcon symbol is illustrative; Flutter screenshot retains current app asset, which has not been approved as the new brand mark in this review.
3. Real room has backend-dependent conditions, banners and frame rendering absent from the empty-state screenshot by design.
4. Full Figma↔Flutter visual parity, responsive edge cases, real Google OAuth, simultaneous voice on two Android phones, permissions and economy transaction correctness remain unverified.
5. Supabase Staging was read-only checked and is `ACTIVE_HEALTHY`. Security advisor returned information-level `rls_enabled_no_policy` notices in internal phase schemas; those notices require a scoped review and are not alone proof of an exploit or unintended access.

## Safety boundary
No `main` or production database edits. No APK/AAB build or production deployment. No simulated user accounts, banners, wallet credits or gift events were inserted.
