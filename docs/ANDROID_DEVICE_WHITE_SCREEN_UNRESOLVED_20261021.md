# Android white screen incident — 2026-10-21

Status: **OPEN — physical-device startup failed**. Scope: TotiChat Flutter Beta on `rebuild/flutter-v1`; Supabase **Staging only**.

## Release fix acceptance evidence (2026-10-21)

- **Android 14 release/AOT emulator test PASS:** [Actions run 39614042988](https://github.com/QYEM7/TotiChatpro/actions/runs/39614042988), source commit `62f3b3d178781002312181007837e113b878f315` on draft PR [#32](https://github.com/QYEM7/TotiChatpro/pull/32), targeting `rebuild/flutter-v1` and **not main**.
- This job resolved `shared_preferences_android 2.4.28`, built actual release-mode Flutter, cold-launched twice, and confirmed the Google login screen visible in both UI dumps and screenshots. Logs contain **zero** `NoSuchMethodError`, `FATAL EXCEPTION` or `E/flutter` lines.
- **Only Staging QA:** artifact `TotiChat-Staging-Beta-PreferencesFix-ARM64` ID `12352386710`. Extracted APK: `TotiChat-Staging-Beta-PreferencesFix-ARM64.apk`; SHA-256 `f3d346e4d19daf15983cf02be2b23032d76a0af17ee337ee0df27f19d02882ca`; 34,650,839 bytes. ZIP structure, APK structure and native `libapp.so`, `libflutter.so`, `libdartjni.so` for ARM64 checked.
- **Status remains OPEN on physical device:** Prior ARM64 PluginFix2 failed on target phone; user has successfully run only the offline renderer diagnostic so far. The new full beta APK needs a fresh target-phone test. This success must not be presented as validated Google OAuth, voice or full beta acceptance.
- PR #32 remains **draft/unmerged**. No production or main branch updates. This test package is release-compiled but **debug-signed**.

## Physical device result and release crash isolation (2026-10-21)

- User shared an on-phone screenshot showing the distinct offline diagnostic's dark blue page and **"Flutter frame visible"** text. This confirms that the separately packaged ARM64 diagnostic can render a Flutter frame on the target device. Do not conflate it with the full beta, Google Auth or LiveKit.
- Android 14 x86_64 **release/AOT** emulator workflow [39608557363](https://github.com/QYEM7/TotiChatpro/actions/runs/39608557363) reached the beta bootstrap failure screen. Archived logcat for `com.totichat.beta` PID 2871 shows `PlatformException` caused by `java.lang.NoSuchMethodError` for `io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar.getAll(String, List, Continuation)`. Thus Flutter engine first frame works, but **release native prefs initialization breaks** in that environment. The artifact reports the full app failure and does not establish a target-device fix.
- The documented upstream regression is `shared_preferences_android 2.5.0`: Pigeon JNI interop and release R8 rewrite. `flutter_app/pubspec.yaml` now explicitly pins `shared_preferences_android: 2.4.28`, and release test workflow verifies that the resolved dependency version is 2.4.28. The Flutter SDK, LiveKit voice source, Supabase backend and `main` were not changed.
- A **new successful Release/AOT emulator cold-start check** plus a real ARM64 device login screen remain mandatory before closing the incident. Do not claim fixed on the user's phone until a fresh full beta is tested there.
- This report intentionally omits the personal screenshot and account/device identifiers from Git history.

## Follow-up evidence

- Android 14 **debug** emulator run [39606302117](https://github.com/QYEM7/TotiChatpro/actions/runs/39606302117) passed. This still does not verify the ARM64 release build on a physical phone.
- Offline ARM64 diagnostics workflow [39606373247](https://github.com/QYEM7/TotiChatpro/actions/runs/39606373247) passed, artifact ID `12348413731`. The extracted `TotiChat-Device-Test-ARM64.apk` is **54,078,542 bytes** and its SHA-256 is `aa0ad41a72b211acfbb400f843817cd5dc44b1daa6ea7d4b9137242994f0cd3f`. APK ZIP integrity and SHA256SUMS verification succeeded. Physical-device execution remains **untested**.
- Android 14 **release-mode** emulator run [39606302101](https://github.com/QYEM7/TotiChatpro/actions/runs/39606302101) compiled and installed the release APK, then failed because the runner split a multi-line `for` loop across shell invocations (`Syntax error: end of file unexpected (expecting "done")`). This is a **CI script failure, not evidence that the app crashed**. Commit `2207ff6196c4b51a4e7ba2951134ef33a10beae8` fixes that by invoking a standalone POSIX shell script. The corrected emulator runtime result must be verified in a subsequent run before making any success claim.
- The offline diagnostic APK still bundles third-party native libraries through the Flutter app's plugin registry. It isolates the **Dart UI from backend initialization**, but cannot conclusively isolate the engine from all plugin or platform crashes.

## Confirmed evidence

- The user reported that the initial ARM32/ARM64 builds showed a white screen or froze.
- The user separately confirmed the **PluginFix2 ARM64 release-compiled APK** also failed on the phone.
- GitHub Actions `39342356938` produced debug-signed release/AOT ARM32 and ARM64 binaries containing `libdartjni.so`. Artifact integrity and compilation passed; this did **not** prove on-device startup.
- GitHub Actions `39342340042` passed a real Android **14 x86_64 emulator** launch, reaching `Toti Chat`, but it installed a **debug/JIT** APK, not the user's **release/AOT ARM64** binary.
- A successful emulator result must not override the user-reported phone failure. The actual reason for the failure on the phone remains **unconfirmed** without corresponding device evidence.

## Work resumed (code, not a successful runtime claim)

1. `flutter_app/lib/main.dart` now contains an explicitly labeled, offline `TOTICHAT_DIAGNOSTIC_ONLY` Flutter first-frame screen which does not initialize Supabase, sign in, query a room, or connect to LiveKit.
2. `flutter_app/test/startup_gate_test.dart` has a widget assertion for that isolated diagnostic.
3. `.github/workflows/android-release-boot-smoke.yml` builds a release/AOT emulator APK, cold launches it twice on Android 14, asserts the login text is present, and retains screenshots, UI dumps and filtered Android logs.
4. `.github/workflows/android-offline-device-test.yml` creates a diagnostic **ARM64** APK with a distinct `com.totichat.beta.diagnostic` package and `TotiChat Device Test` launcher label, removing the beta OAuth handler. It is **not a functional beta** and must not be presented as one.

## Interpretation matrix (tentative; not proof by itself)

| Release emulator | Offline ARM64 test on target phone | Full beta on target phone | Where to investigate next |
| --- | --- | --- | --- |
| Fails | Unknown | Fails | Release/AOT app initialization or packaging; inspect CI logs before further delivery |
| Passes | White/frozen | White/frozen | Platform startup, ABI, GPU, Flutter engine, native plugin registration or install state |
| Passes | Shows `Flutter frame visible` | White/frozen | Beta-only startup paths (Supabase, auth, assets, plugin configuration) or differences from diagnostic packaging |
| Passes | Shows `Flutter frame visible` | Works | Proceed to real OAuth and two-phone audio tests; **still not a release acceptance** |

The diagnostic's changed package and compile-time tree shaking mean these comparisons are indicators, not controlled equivalence. Do not conclude that Supabase or rendering is the culprit solely from a screen.

## Stop conditions and safety

- Do not distribute another ordinary beta APK claiming the issue is solved merely because builds or emulators pass.
- Do not modify the established LiveKit audio SDK, production database, `main`, or public store.
- Device-specific evidence is required: last visible screen, full Android version, native `adb logcat` surrounding app launch where obtainable, and exact APK SHA-256. Do not upload authentication tokens or other private data to public CI logs.
- No APK publication, Google Play rollout or production deployment is authorized by these diagnostics.
