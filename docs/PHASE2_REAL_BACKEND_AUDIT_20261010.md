# TotiChat — Real Backend vs Visual Demo Audit (2026-10-10)

## Why the previous APK appeared frontend-only

The previous Android package opened the approved decorative home by default.
All six featured room cards, near-room cards, sample profile counts,
VIP5/LV45, demo gifts, shop displays and music player were deliberately
hard-coded frontend previews. The independent Supabase backend did contain
real Auth, profiles, room directory, exclusive mic-seat reservations, room
messages and one-use room invitations, **but these were used only by an
authenticated account**.

Direct Supabase audit of `sqedsnyvjblvbjbizcay` before implementation:
- `auth.users = 0` and `profiles = 0`
- `rooms = 0` and `room_messages = 0`
- `home_banners = 3` (real existing banner data)

No real account had been registered. The fake values the owner saw were
not imported financial or account data; they were baked into the visual
showcase. This is a real product defect because guest mode was not
distinguished from actual server-backed data.

## Actual changes applied on develop/phase-2

1. **Android (https://localhost WebView)** now goes to the actual Login /
   Signup UI on startup. It NEVER displays the six sample room cards
   as real room memberships. Users may deliberately opt into the approved
   frontend preview, which carries a persistent prominent disclaimer.
   GitHub Pages design preview is unchanged (unless `?mode=live` explicitly
   requests the new live experience).
2. On real login, Home shows the actual empty room directory (until users
   create real rooms); real profiles have their real name, bio and
   server-backed account UUID, not fixed demo ID 7273804. Demo
   followers and VIP levels are shown as unavailable instead of fake data.
3. Unsupported gift/CP/VIP/agency/shop/music and other financial UI paths
   are blocked in Android live mode with transparent "under development"
   feedback. They cannot pretend to credit or debit real money.
4. New clean-wallet schema `phase2_readonly_wallet_foundation` was applied
   ONLY to the independent TotiChatpro Supabase project:
   - `public.wallets` authentic per-user coins & diamonds, both zero
     on signup via protected Auth trigger.
   - `public.wallet_ledger` immutable-to-client operation history,
     idempotent `operation_id` field for later server transactions.
   - RLS: authenticated users can only READ their own wallet/journal;
     no anonymous reads, and no client write/coin creation privileges.
5. A real wallet screen fetches authoritative balance/journal with the
   signed-in JWT. A server error shows an error, never an invented balance.
   Top-up through agents is NOT implemented yet.

## Tests and guarantees

- Browser CI verifies unmodified approved guest design, a real-mode
  anonymous app starting on login, explicit guest demo selection, mock Auth
  flow, zero actual rooms, genuine-zero mock wallet, unavailable VIP/social
  counts and controls, and authenticated protected room/chat journeys.
- Database schema/permissions were independently queried: zero users,
  zero wallets/ledger initially, 3 banners preserved, wallet Auth trigger
  installed, anon cannot read wallets, authenticated cannot update balance,
  authenticated cannot insert ledger records.
- APK CI inspects the APK contents to confirm root WebView contains the
  actual app, assets, Auth adapter and real rooms; still requires real-device
  manual installation and backend live-account smoke checks.

## Still not implemented or proven

**Do not call this 100% complete Backend:** actual microphone audio
streaming (SFU/TURN/reconnect), gifts and atomic debits, Treasury Wallet
minting, top-up agents, agency/host wages, monthly diamond settlement,
CP/VIP/level entitlements, social messaging, music sync, voice games,
Owner Dashboard, release signing, production security/abuse tests.
Login/account creation is live Auth code but real email-delivery and
multi-device sign-up still need owner-side manual validation.

## Rules

- `main` and `release/uiux-v1-approved` stay untouched.
- All phase-2 work in `develop/phase-2`.
- No transfer of the old project test data. No fake coins represented as live.
- Never ship service_role, database password or minting capability in app.
