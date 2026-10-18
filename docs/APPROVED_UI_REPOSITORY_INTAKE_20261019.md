# TotiChat Project 01 — Approved UI Repository Intake
Date: 2026-10-19

## Source and isolation
- New user-designated approved UI repository: https://github.com/mrbalmain11-star/-
- Source repository is public, with default branch `main`; our linked GitHub connector has READ access only (cannot push).
- Backend-only repository: https://github.com/QYEM7/TotiChatpro/tree/rebuild/flutter-v1
- Backend staging only: `rziaedugbdwefbefcxjt`. Do not modify production or `main`. Do not build APK/AAB until authorized.
- Historic UI/UX and all prior brand assets are deprecated; do not use them in the new client.
- Previous full repository preserved at `backup/pre-backend-only-20261019`. This backup is for safe recovery of *backend* material only, not UI approval.

## Technical intake — confirmed from source
The new repository contains two implementations:
1. Primary, much more complete design reference: `src/` — React 19, TypeScript, Vite, Tailwind CSS. Rich UI screen/modal inventory; `src/components/VoiceRoomModal.tsx` explicitly renders **15 seats in 3x5 layout**.
2. Separate native Android scaffold: `android/` — Kotlin with Jetpack Compose and an in-memory `TotiRepository`; presently contains **8-seat mock rooms**. This is NOT parity with the primary UI.

The approved mobile app implementation target remains Flutter/Dart: port UI semantics, layouts and assets from the user-designated repository into Flutter widgets while preserving the visual source. Do not substitute older Flutter screens, older web previews, or Kotlin demo screens.

## Primary React visual inventory
- Root and shell: `src/App.tsx`, `src/index.css`, `src/context/AppContext.tsx`
- Login: `src/components/AuthScreen.tsx`
- Main navigation: `src/components/Header.tsx`, `BottomNav.tsx`
- Home: `src/views/HomeView.tsx`, `BannerSlider.tsx`, `CategoryCards.tsx`, `RoomCard.tsx`, `RoyalRoomsView.tsx`, `DiscoverRoomsView.tsx`
- Voice room: `src/components/VoiceRoomModal.tsx`
- Gifts: `GiftStoreModal.tsx`, `GiftAnimationOverlay.tsx`
- Store/economy: `VipModal.tsx`, `StorageModal.tsx`, `RechargeModal.tsx`, `LevelsModal.tsx`
- Social: `src/views/MessagesView.tsx`, `DirectChatModal.tsx`, `InternalProfileModal.tsx`
- Agencies: `AgencyModal.tsx`, `AgencyProfileCard.tsx`
- Profile and admin-related UI entry review: `src/views/ProfileView.tsx`, `SettingsModal.tsx`, `ReportModal.tsx`
- Visual assets: `src/assets/images/`, `public/`.

## Important backend blockers
The React prototype does **not** yet use the preserved Supabase staging backend:
- `src/mockData.ts` defines the initial profiles, rooms, conversations, gifts and agencies.
- `src/context/AppContext.tsx` stores session/rooms in browser localStorage and mutates wallet, gift/wealth/charm data locally.
- `AuthScreen.tsx` marks the session logged in after a timeout; its Google button is not genuine Google OAuth. Phone OTP is also simulated.
- `GiftStoreModal.tsx` calls an in-memory `sendGift`; wallet settlement must be server-authoritative and idempotent, not client-side.
- `android/.../TotiRepository.kt` uses in-memory StateFlow demo rooms and local recharge/gift calculations. Do not deploy this as a real money/service client.
- Some UI placeholders, including a hardcoded room trophy total, must not appear as genuine server values in a live app.
- Backend voice service and policies must be connected through existing staging LiveKit token flow, without replacing stable audio services.

## Contract and implementation order
1. Preserve a visual baseline for ALL screens, bottom sheets, animations and VIP assets in the approved source. Generate a screen-by-screen Flutter visual comparison; no aesthetic improvisation.
2. Build Flutter presentation/state/data separation; allow zero mock data in LIVE mode. Display clean empty states if no real data exists.
3. Implement REAL Google-only OAuth through Supabase Staging; session persistence must derive from backend auth, not localStorage boolean.
4. Bind profiles, real rooms, 15 seats, room metadata, social and chats to staged SQL schema, RLS and realtime contracts.
5. Integrate the EXISTING voice token function, mute/unmute, role-based mic permissions and synchronized music; do not replace the audio core without separate approval.
6. Route gifts, balance, rewards, VIP, CP, agencies and recharge through backend RPC/functions. All financial debits/credits must be transactional and idempotent; no negative balances.
7. Keep Admin Center inside the app and accessible only from Profile with server-enforced permissions.
8. Test with real staging accounts and two physical devices for voice; do not release APK until owner approves.

## Existing backend contract sources
- SQL migrations: `supabase/migrations/`
- Edge Functions: `supabase/functions/phase2-voice-token/` and `phase2-voice-moderate/`
- SQL tests and verification: `supabase/tests/`, selected backend scripts and tests.

## Change boundary
This document and the status record below only register the new UI repository as approved source material. No UI code has been imported, ported, or integrated. The remote databases and external historical deployments are unchanged; stopping old sites still requires access to their hosting platforms.
