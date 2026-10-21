# Android white screen incident — 2026-10-21

Status: **OPEN — physical-device startup failed**. Scope: TotiChat Flutter Beta on `rebuild/flutter-v1`; Supabase **Staging only**.

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
