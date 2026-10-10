# TotiChat Firebase Android connection — 2026-10-11

## What the owner provided
- Firebase project: `totichatpro` (same existing Google Cloud project).
- Firebase Android application package: `com.totichat.beta`.
- Received Google Services client config, validated it against the current `capacitor.config.ts`.
- Firebase Spark no-cost tier was shown in the Owner's console screenshots. No billing upgrade authorized.

## What is actually implemented
- `firebase/google-services.json`: official **client-side configuration**. This is NOT an Admin SDK service-account credential. The Firebase Android API key is a public app identifier, not a privileged server key; it still needs API/application restrictions as appropriate.
- `scripts/configure-firebase-android.mjs`: after Capacitor generates the Android shell, it checks the exact project/app package and required Firebase keys, copies config to `android/app/google-services.json`, and ensures Google Services Gradle integration with version `4.5.0`. Fail-closed for mismatches or unexpected native Gradle layout. Idempotent. **Does not build an APK**.
- `tests/firebase-android-config.test.mjs`: tests against a temporary isolated fake Android shell, mismatch failures, idempotence, and no production or APK side effects.
- `.github/workflows/phase2-foundation.yml`: runs the Firebase setup tests in regular source CI with no Android build.
- `.github/workflows/phase2-android-beta.yml`: config is installed ONLY after the unmodified T48 release readiness gate passes and the Owner separately approves any APK work. No builds happened in this task.

## Verified
- [Phase 2 foundation workflow passing](https://github.com/QYEM7/TotiChatpro/actions/runs/38087626025).
- The uploaded file matches the current Capacitor Android package and expected Firebase project.

## What has NOT been implemented, and remains pending
- Actual **FCM push messaging**: add the Capacitor Push Notifications plugin/Android Firebase Messaging SDK and permission request flow, user-device-token registration/rotation and backend push sender; then verify delivery and logout revocation on hardware. Keep all credentials/server sender roles out of the client.
- Actual **Crashlytics**: install compatible SDK and Gradle plugin in the native app, configure consent and verify a real Android crash report. Firebase Google Analytics was disabled by Owner; leave it off.
- Real APK builds and phone tests remain Owner-gated. The Android generated shell is NOT checked into this repository.
- Independently verify API key's Android signing certificate/package and minimal enabled API restrictions before public release. Keep all LiveKit server secrets and Firebase Admin service-account private keys out of app and repo.
- Keep Supabase sole authority for users/wallets/agents. Firebase is ONLY for notifications/mobile diagnostics, not a second user or financial database.
- No extra paid Firebase/Cloud Storage/Blaze features activated.

## Project readiness
**Official baseline remains 63% engineering, 15% genuine Beta** until independent hosted/hardware and rollback evidence is verified; `release_allowed=false`. This preparatory Firebase configuration does not independently justify raising the overall scores.
