# TotiChat approved UI implementation — phase 1

## Git references
- Approved design source: `mrbalmain11-star/-` on `main`.
- Existing backend-only branch: `rebuild/flutter-v1`.
- New Flutter implementation branch: `feature/approved-ui-flutter-v1`.
- Staging project: `rziaedugbdwefbefcxjt`.

## Confirmed prior to implementation
A read-only Staging SQL check verified the existing rooms, profiles, messages,
home_banners, room_members, gift_catalog and wallets columns and room RPC names.

## Completed in branch source
- New Flutter app foundation and color tokens derived from approved React.
- Google OAuth login route guard using Supabase sessions, no hardcoded authenticated state.
- Home and 3-way navigation with real room and banner queries.
- Fifteen-seat room UI with real server reservations and room text chat.
- Gift bottom sheet using server gift catalog and atomic RPC ledger.
- Profile and real wallet balance read, and sign-out.
- Flutter-only QA workflow with lint/test jobs and explicit no-APK guard.

## Known differences and blockers
- UX fidelity is **partial**. The original React code has 33 screen/modal components,
  and visual parity remains to be checked on actual devices.
- Images are HTTPS references to original approved assets, not yet bundled offline.
- Phone login has deliberately not been ported: owner-approved login policy is Google only.
- No LiveKit audio player/microphone integration has been claimed; mute remains disabled.
- DM, VIP frames/CP, agency dashboards, true rankings, admin permissions remain gated.
- No authenticated two-device staging acceptance yet.
- GitHub Actions status must be checked before considering this code verified.

## Safety
No production or database mutation, no APK/AAB build. Backend-only branch is intact.
