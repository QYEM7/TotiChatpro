# TotiChat — APPROVED UI/UX BASELINE (Phase 1)

**Approval date:** 2026-10-10
**Repository:** `QYEM7/TotiChatpro`
**Baseline commit:** `e19707abbca40f62b4494c2d95c1187dd7c27b08`
**Frozen snapshot branch:** `release/uiux-v1-approved`
**Production preview branch:** `main`
**Phase 2 integration branch:** `develop/phase-2`

## Official status

The user approved the exact UI/UX of the deployed TotiChat preview after the final changes.
This is the **approved design reference** for further development, not a claim that the
backend or Android APK is complete. Preserve all functional interactions and their
visual layout unless the user explicitly approves a change.

## Non-negotiable visual invariants

1. **Home:** Keep the existing top logo, header buttons, hero advertising carousel,
   category choices, VIP promo, featured room cards, nearby-room cards, and the
   approved five-action bottom navigation (including the real falcon logo).
   The **duplicate 'الإعلانات الرسمية' card below room listings is NOT present**.
   The active top banner/ads service must remain operational.
2. **Voice room:** Preserve the current purple/gold room appearance, 15 microphone
   seat positions, occupied/empty/locked states, VIP level decorations, event ticker,
   gifts, chat, music, room admin/game options, and bottom action buttons.
   Do **not** restore the room-only 'هنا يجتمع الصوت الجميل' ribbon.
   Do **not** restore the large enclosing rectangle/panel around all 15 seats.
   Microphone avatar rings, level badges, and the seat's own affordances stay.
3. **Profile / Me:** Preserve approved premium purple-and-gold statistics tiles,
   labels/numbers, VIP/agency/profile sections, shortcut buttons, and the five-tab
   bottom navigation, including the falcon image.
4. **Other UI:** No unrequested restyling, hidden/removed controls, icons, banners,
   visual effects or seat decorations.
5. **Behavior:** No data loss, backend mock substitution, currency resets, broken
   navigation, seat ownership, mic, voice, gifts, wallets, or permission changes.

## Safe phase-2 engineering workflow

- Never modify the **`release/uiux-v1-approved`** branch.
- Do phase-2 work on `develop/phase-2` or a short-lived feature branch based on it.
- Keep `main` pointing at the last approved/published version until integration has
  been reviewed, tested, and explicitly approved.
- All changes should be reviewable as pull requests. Test the *exact Git SHA* that
  will be merged, not just a floating preview URL.
- Require successful existing GitHub Action checks (live-banner integration, mobile
  browser QA and Pages deploy), plus a fresh visual review for changes impacting UI.
- Add screenshot / visual regression checks against the approved baseline before
  phase-2 UI changes are merged; current browser screenshots alone are not a
  pixel-perfect regression guarantee.
- Prefer isolated CSS/JS additions for approved changes; preserve the approved
  asset files. Do not rewrite the UI foundation without explicit approval.
- Configure GitHub branch protection / rulesets for `main` and
  `release/uiux-v1-approved`: block direct pushes, block force-push/deletion,
  require PR reviews and status checks. **These protections must be enabled
  separately in repository settings; the existence of a branch does not enable them.**

## Rollback

If phase-2 integration causes regressions, compare/restore from the exact baseline
commit or `release/uiux-v1-approved`. Never erase user data to fix a layout issue.

> This file documents the approved contract; it does not by itself enforce
> branch protection or guarantee error-free releases.
