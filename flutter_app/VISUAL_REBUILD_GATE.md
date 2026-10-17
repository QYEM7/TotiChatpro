# TotiChat — Flutter visual rebuild acceptance gate

Status: **REJECTED / NO NEW APK** (Owner review on 2026-10-17, Asia/Baghdad).

## Rejected artifact and root cause

- Rejected Android Debug APK workflow: https://github.com/QYEM7/TotiChatpro/actions/runs/39056387979
- Rejected source commit: `587bfe903d2eb5c1cafae15725e44be0ffb22909`.
- Built from the correct Flutter branch `rebuild/flutter-v1` and Staging, **not** from the old React/Reborn binary.
- But the rebuilt UI was a **generic, incomplete Flutter scaffold**, not the approved finished appearance. Passing `flutter analyze`, `flutter test` or Gradle does NOT certify design fidelity.
- The root Flutter room screen still hard-codes a dark `Color(0xFF29233E)` background and simple five-column seats; `toti_theme.dart` defines a generic Material3 seed palette; `home_screen.dart` uses stock `NavigationBar`; `login_screen.dart` is a provisional form.
- The older `APPROVED_PREVIEW.md` and original `index.html` in the repository describe a **different, older prototype**. They are not proof of owner approval for the new 2026-10-16 Flutter-from-scratch effort. Do not port a rejected old design just because it is labelled “approved” in an older document.
- The owner has rejected the delivered APK **100%**. Do not share, promote or install it as a valid beta candidate. Previously granted permission for this single internal test build is **not** approval to ship a second unfinished APK.

## Current Flutter design gaps — owner review required

| Area | Required visual/functionality criteria | Current evidence | Status |
|---|---|---|---|
| Overall visual identity | Coherent new light, premium TotiChat identity and original Falcon logo; no old Reborn design or generic Material defaults | Generic Material3 plum palette and basic card widgets | REBUILD REQUIRED |
| Android entry / Google sign-in | New, explicitly reviewed login screen and callback UX | `features/auth/login_screen.dart` initial scaffold | REBUILD REQUIRED |
| Home and Explore | Distinct, polished mobile layout, real banner space at the top, functional search and bottom navigation | `features/home/home_screen.dart` stock NavigationBar; server-read cards | REBUILD REQUIRED |
| Audio room | Full-room premium presentation, precisely 15 stable seats, avatar/name/VIP/frame/CP/gift counter, no vertical seat scrolling; two-option minimize/leave overlay; chat and gift bottom sheet; ornaments never silently removed | `features/room/room_screen.dart` has a basic dark scaffold and simple seats | REBUILD REQUIRED |
| Room images and creation | Required cover/name/welcome fields, rich room media without demo content | Functional form exists, detailed styling not approved | REVIEW REQUIRED |
| Gift / Lucky Gift | New visually accepted bottom sheet, real events only, confirmed send and quantity 1/7/17/77/777; strip only for gifts >=7000 coins | Backend-oriented base UI only | REBUILD REQUIRED |
| Profile, VIP and CP | Premium profile with earned-only medals, 10 VIP levels, active frame and badge, CP card/relationship when active | Functional/basic views, no owner visual acceptance | REBUILD REQUIRED |
| Wallet/store/agencies/admin | Complete consistent styling and all authorized screens; admin entry only inside My/Profile; role-dependent server permissions | Baseline screens exist; no final visual acceptance | REBUILD REQUIRED |
| Other screens and overlays | Full latest screen inventory, no screen or required decoration excluded without explicit owner decision | Completeness/parity matrix not yet signed off | AUDIT REQUIRED |

## Next acceptance process (mandatory)

1. Inventory **every** new Flutter route, modal and essential state against the user's latest requirements. Treat prior legacy mockup approval as superseded when it conflicts with the rebuild.
2. Implement the **new** Flutter UI while preserving only server contracts, Staging data, Google auth and the stable LiveKit SDK. Do not use fake banners, gift events, wealth/charm or balances.
3. Obtain side-by-side **screenshots or real running Flutter previews** of Login, Home, Audio Room, Gift Sheet, My/Profile and Admin Center, including secondary screens, VIP effects, seat ornaments and overlays.
4. Have the Owner **explicitly approve the visual design**, not merely the fact that unit tests pass. Track each screen and overlay with PASS/FAIL/NOT REVIEWED; screenshots from another technology stack are reference only.
5. Run Flutter QA, authenticated Staging checks, and two-phone physical audio/financial/permissions acceptance. No production/main modifications.
6. Re-enable the frozen APK workflow and authorize a **fresh** internal test build only when these gates are satisfied and the Owner permits that build.

Never claim "100% complete" based solely on source paths, generated diagrams, or green CI.

## Binding restrictions

- Branch: `rebuild/flutter-v1`; Staging: `rziaedugbdwefbefcxjt`; do not touch `main` or production.
- Flutter/Dart frontend; no old Reborn reuse. Keep stable LiveKit SDK.
- User-facing brand: TotiChat and Falcon. Do not show fabricated content.
- FCM deferred; in-app notifications retained. Manual host settlements.
- All screens and visual decoration require owner review.
- Android private beta APK: **ON HOLD following visual rejection**.
