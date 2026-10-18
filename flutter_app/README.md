# TotiChat — Approved UI Flutter implementation

This is a **new Flutter/Dart client**, not the retired Flutter or web frontend.
Visual authority: https://github.com/mrbalmain11-star/- (the user's approved new UI source).
Development branch: `feature/approved-ui-flutter-v1`.
Backend authority: Supabase Staging `rziaedugbdwefbefcxjt` only.

## What is implemented
- Flutter runtime, theme foundation extracted from the approved React source.
- Google-only **real** Supabase OAuth with session-driven route guard. No fake login.
- Real public room directory and published banner catalog; missing real items stay hidden.
- Real room create/join/leave + 15-seat reservations (3x5) using existing RPC functions.
- Real room text messages via server RPC and fetch from RLS-protected table.
- Gift catalogue and atomic gift requests via `phase3_send_gift` (one server-side request id per send).
- Real own profile + wallet balance (or clear unavailable state).
- No placeholder room counts or fake VIP/wealth/charm totals.

## Not yet implemented / not tested end to end
- LiveKit microphone transport (the mic button is disabled, NOT faked), synchronized music.
- All subsidiary sheets, detailed VIP frames, agencies and admin workflows.
- Real direct message directory; profile displays a disabled admin entry pending role check.
- Complete 1:1 screenshot match against the React design on Android devices.
- Offline images: approved source visual assets are referenced over HTTPS from the new repository,
  NOT copied into the app package. This means their appearance depends on network access.
- Full CI pass and two-device room/voice acceptance have NOT been confirmed.

## Setup
1. Create missing Android tooling locally using `flutter create --platforms=android --project-name totichat --org com.totichat .`.
2. Run `flutter pub get`.
3. Obtain the **publishable key for the Staging project only**. Never provide a `service_role` or secret key.
4. Configure `com.totichat.next://login-callback/` as a permitted Supabase Authentication Redirect URL in Staging.
5. Start with:
   `flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=<staging-publishable-key>`

The app shows a configuration error instead of fake data if the key is missing.
The code is intentionally not configured to build or deploy APK/AAB.
The workflow runs only source analysis and tests, without packaging.

## Source and security boundaries
Do not use retired TotiChat UI assets, Flutter widgets, admin shortcuts or seed data.
Do not copy `src/mockData.ts` from the design source into this app.
Do not change `main`, production or the existing stable LiveKit services.
