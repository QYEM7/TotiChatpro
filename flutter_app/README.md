# TotiChat Flutter Beta — implementation slice 01

**Status: source code only, NOT ready for APK or device acceptance.**

This is the NEW Dart/Flutter client. It does not import the retired visual UI or any mocked wallet, user, room, gifts, or follower data. Its reference for the first screens is the **owner-approved** [mrbalmain11-star/-](https://github.com/mrbalmain11-star/-) `main` branch. Supabase server contracts come from this repository's `supabase/migrations/`, and schema existence was read-verified on Staging on 2026-10-19.

## Implemented in this slice
- Staging-only environment guard (wrong project URL fails closed).
- Google-only Supabase OAuth initiation with `com.totichat.beta://auth/callback`; no simulated authentication.
- Session restore through Supabase Flutter plus `phase4_verified_session` RPC before entering Home.
- Public-room list, real published banners, room join RPC, membership/15 occupied-seat display, and room exit RPC.
- Profile name and `phase5_special_id_status` RPC; unassigned IDs are never fabricated.
- Real RLS errors result in an error/empty-state, never mock content.

## Not yet implemented
Android Flutter host files, deep-link intent filter, local Flutter compilation, OAuth callback test, room creation/upload, seat claim/mute, LiveKit voice, realtime updates, text chat/DM, gifts, wallet, moderation, VIP, CP and admin functions. Only the basic login/Home/room structure references approved visuals; screenshot parity **has not** been verified.

Images for the login and room background temporarily reference **the exact approved public repository**. In a subsequent asset-porting step, bundle those images in the app to avoid a network dependency. No deprecated design imagery is used.

## Setup in a Flutter development environment
1. Install a current stable Flutter SDK with Dart 3.8+, then generate missing Android host files without overwriting Dart source:

   ```sh
   cd flutter_app
   flutter create --platforms=android --org=com.totichat --project-name=totichat .
   flutter pub get
   flutter analyze
   flutter test
   ```

2. The generated `android/app/src/main/AndroidManifest.xml` still requires this OAuth intent filter **inside the MainActivity activity** before any real device test:

   ```xml
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="com.totichat.beta"
           android:host="auth"
           android:pathPrefix="/callback" />
   </intent-filter>
   ```

3. Confirm **only** `com.totichat.beta://auth/callback` is allowlisted as an additional Redirect URL in **Supabase Staging**. Do not change production Site URL; keep the existing Google provider configuration.
4. Supply a **Staging publishable** client key in the local environment via `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` and `--dart-define=SUPABASE_URL=https://rziaedugbdwefbefcxjt.supabase.co`. Never use the service_role/secret key. Do not commit environment keys.
5. This branch must **not** build an APK/AAB, deploy, run database migrations, or access production without a new explicit owner authorization. The commands above are for source analysis/tests only.

## Verification boundary
Schema existence read-only checks are not equivalent to authenticated integration QA. G1 real Google mobile callback, G2 multi-account room tests and G3 two-phone audio remain blocked/unverified; do not label the beta finished.
