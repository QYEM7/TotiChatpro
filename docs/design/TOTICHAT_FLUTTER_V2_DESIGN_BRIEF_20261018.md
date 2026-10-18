# TotiChat — Flutter V2 visual source of truth (DRAFT, owner review required)

Date: 2026-10-18. Repository: QYEM7/TotiChatpro. Target branch: `rebuild/flutter-v1`. Client: `flutter_app/`.

## Owner's binding decision

Create a NEW Figma Design file and NEW Flutter visual identity. Historical Figma/React/Reborn screens remain archive-only. **Do not claim any existing screen is visually approved.**

The official source of truth will become the new Figma file and node IDs after the owner reviews them. Figma file link: **PENDING — user must select one of the two editable Figma team destinations (Code Master or cherry)**.

No `main` or production changes. Only staging `rziaedugbdwefbefcxjt`. No APK/AAB or release deployment without explicit permission. No invented banners, users, seat occupants, gifts, wealth, balances or transactions in live previews.

## New light luxury direction (PROPOSED, not yet approved)

Design principles: warm porcelain white, clean navy typography, restrained blue/teal signature accents, small champagne-metallic detail where justified; bright and breathable rather than dark/heavy. Preserve original falcon asset `flutter_app/assets/totichat_falcon.jpg`; user-facing name **TotiChat**. Use proper scalable vector iconography for ordinary icons rather than embedded image assets. Decorative room elements stay prominent and legible.

Candidate tokens to visualize in Figma — do NOT treat as approved until visual signoff:
- Surface 0 / canvas: `#F8FAFD`; raised surface: `#FFFFFF`; subtle inset: `#EFF4FA`.
- Primary ink: `#19273F`; secondary text: `#65748B`; subtle outline: `#DFE7F1`.
- Rich accent blue: `#456FBA`; elegant teal: `#268A93`; ceremonial gold: `#C6A66B`.
- Error only: `#B54759`; success only: `#28785C`.
- Spatial rhythm: 4/8/12/16/24/32 px; standard radius 12/16/24 px; action touch target >= 44x44 logical px.
- Text roles: display/title/body/caption; explicit Arabic RTL metrics, line heights and truncation; proposed Cairo/Inter, subject to available licensed font assets and actual Flutter rendering.
- No whole-screen opaque black layer; bottom sheets preserve visible blurred room context.

## First screen — audio room (393×852 Figma primary target)

1. Top safe area + luxury room bar: room name (real server text), room owner identity only when available, connected count (actual state), music/invite and **single two-action leave/minimize control** (transparent blurred overlay; no separate close X).
2. Atmospheric light backdrop and premium room header: welcome copy only when provided by server. No invented activity or fake participants.
3. Precisely **15 microphone seats**, three non-scrolling rows of five; responsive 360, 393 and 430 logical-pixel portrait widths. Empty seats show neutral numbered placeholders (1–15); occupied seats show server avatar/name. VIP frame, badge, CP, gifts, mic status appear only when genuinely active. Do not remove decorative frames to make layout simpler.
4. Gift announcements only for real eligible events >= 7000 coins, and hide when none exist. Keep room visible behind transparent/blur gift sheet. Quantities remain **1 / 7 / 17 / 77 / 777**, user selection does not debit, explicit Send requires confirmed receipt with idempotency.
5. Fixed microphone, call and gift actions reachable by thumb without covering the 15-seat grid; local mic/music audio controls preserve existing LiveKit behavior.
6. Chat content is the scrollable region; message composer remains usable with keyboard open; no vertical seat scroll. DM action from an occupied seat opens real DM; no DM voice messages.
7. Narrow/large text, keyboard, connection retry, no-member, long room name, room moderation and permission denied states must not overlap, clip or hide actions.
8. Room image/owner decorations, VIP levels 1–10, equipped frame/badge, CP and received-gift counter are to be represented as real conditional states; use design annotations for conditions instead of fake live events.

## Figma file architecture and component inventory

- Cover / acceptance status (UNAPPROVED until owner explicitly signs off).
- Foundations: palette, type scale, spacing, elevation, radius, iconography, visual effects, responsive/RTL rules.
- Components: avatar and VIP frame, CP badge, gift counter, 15-seat group, room top bar, glass controls, chat bubble, chat composer, action row, realtime gift strip, transparent bottom sheet.
- Room: 393×852 primary composition; 360×800 narrow and 430×932 wide; state variants (empty/real user/restricted/keyboard/gift sheet).
- Exportable handoff mapping each Figma node to Flutter widget and asset. Never use a Figma screenshot as an in-app substitute.

## Implement and verify, without overstating completion

- First implement the approved Figma screen in Flutter by reusing `room_screen.dart`, `room_seat_visual.dart`, `gift_sheet.dart`, `real_gift_ticker.dart`, `toti_theme.dart` and existing server contracts.
- Generate a screenshot from **real Flutter rendering** (widget visual review/golden process, isolated fixture state clearly labeled empty). A test fixture may return no data but may not fabricate live users, gifts, banners or balances.
- Compare Flutter screenshot with **the same Figma node** at matching geometry, display both screenshots for owner review. Evaluate header, seat geometry, typography, blur, color, decorative frames, fixed footer and overflow at 360/393/430 width.
- Run `flutter analyze lib test --no-fatal-infos`, `flutter test`, and appropriate GitHub Actions. Source assertions alone do not prove pixel fidelity.
- Approval gate: owner says **APPROVED** for Figma frame AND real Flutter screenshot; no bulk-screen restyling before then.
- Independent backend work and tests can continue on Staging; preserve all real-data, financial receipt, authorization and voice protections.

## Explicitly excluded from approval

Old `main` UI, Reborn/Capacitor app, legacy `APPROVED_PREVIEW.md`, old Figma files, historical PNG concepts and generic images are **not** the new UI source of truth.

## Progress log

- 2026-10-18: owner authorized fresh identity, Figma new file, Flutter and read-only/automated checks; this design brief added to development branch. **Visual work pending new Figma file creation and owner review**.
