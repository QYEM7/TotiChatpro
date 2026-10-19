# TotiChat — Staging Android beta: installation and two-phone acceptance

## Build provenance and hard limits
Build workflow: `.github/workflows/totichat-staging-apk.yml`; branch **`rebuild/flutter-v1` only**, produces the installable **debug** `TotiChat-Staging-Beta.apk` as a GitHub Actions artifact with `SHA256SUMS.txt`. No Google Play upload, production schema migration or `main` branch changes.

Package ID **`com.totichat.beta`**, Android launcher label **TotiChat Beta**; no conflict with a separately installed production application. Uses fixed Supabase **Staging** URL `https://rziaedugbdwefbefcxjt.supabase.co` and its **public publishable** key only. Google callback `com.totichat.beta://auth/callback`.

**Debug APK**: signed by the CI runner's ephemeral Android debug certificate. It is *only* for manual testing. A later CI run may produce a different debug key; if updates fail, uninstall the previous beta package (doing so erases this beta's local state). Do not distribute as a production release.

## Installation (Android, no computer required)
1. Open the successful [GitHub Actions APK workflow](https://github.com/QYEM7/TotiChatpro/actions/workflows/totichat-staging-apk.yml) on your phone, select the successful run on `rebuild/flutter-v1`, then download artifact **`TotiChat-Staging-Beta-Android-APK`**. GitHub may require a signed-in account.
2. Open the downloaded ZIP with Android Files, extract `TotiChat-Staging-Beta.apk`, and tap it. If prompted, allow installation from **that trusted files/browser app**; keep the device's general protections enabled. Do not install APKs offered by unrelated third parties.
3. Look for a distinct **TotiChat Beta** icon. No permission to microphone is required until the user actively taps the mic button. An OAuth login will need Staging Redirect URL allowlisting and Google configuration to match `com.totichat.beta://auth/callback`.

## Acceptance checklist: record PASS/FAIL, never simulate success
- [ ] Login with Google completes and returns from browser to **TotiChat Beta**; logout and login session restoration work.
- [ ] Account A creates a room with real image + welcome message; Account B can see/join the correct room.
- [ ] Exactly 15 fixed seats; account A/B can claim/release the seat and see the other's correct state.
- [ ] Text chat appears across both devices; DM opens from an occupied seat and works without any voice messages.
- [ ] Voice: A and B hear each other, permissions requested only when mic is enabled, mute/unmute works, no echo or microphone crash, background behavior is correct.
- [ ] Minimizing room leaves it connected while navigating app (until owner chooses to exit).
- [ ] Wallet amounts come from actual server; zero/insufficient balance does not allow a fake gift.
- [ ] If authorized to safely test with real Staging funds, send one low-value gift and check the ledger, balances, receipt, replays and recipient; do not mint or charge coins without explicit approval.
- [ ] Global gift strip appears **only** for real eligible ≥7000-unit-price gift events. Missing banners/events stay absent.
- [ ] Room owner moderation works, but regular members cannot mute/kick others.
- [ ] Owner/admin-specific entry appears only under **Profile** for properly authorized test accounts (admin roles must be separately configured).
- [ ] Compare live screenshots to the latest approved UI source. Visual parity is not yet signed off.

## Known pre-flight unknowns
- Supabase Staging provider/redirect allowlist for mobile Google callback cannot currently be confirmed by DB read-only inspection. Do not claim device OAuth passed before a real login.
- LiveKit Staging credentials and two-device voice functionality have not been tested.
- Server financial idempotency exists, and persisted client retry identifiers passed unit tests, but **real financial QA is not done**.
- A source-validated APK still does **not** mean 90% release readiness.
