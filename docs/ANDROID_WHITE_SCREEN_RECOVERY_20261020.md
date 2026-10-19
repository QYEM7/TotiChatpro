# TotiChat Android Beta — white screen / launch freeze recovery

Date: 2026-10-20. Branch: `rebuild/flutter-v1`. Staging only.

## User-reported failure (not simulated)

The user reports that both the 2026-10-20 ARM64 and ARM32 APKs freeze or show a white screen on launch. **Treat those two binaries as FAILED runtime acceptance**, despite their successful Flutter unit tests and APK compilation. Do not recategorize them as release-ready.

### Static evidence

- Both previously delivered APK ZIP archives passed package ZIP integrity checks.
- Both contained `libapp.so`, `libflutter.so`, `assets/flutter_assets/assets/i18n/ar.json` and the login-screen JPEG.
- This evidence **does not** establish that the Android rendering engine started, the app displayed a first Flutter frame, or that Supabase Auth initialized on the user's device.
- At the time of this repair, no `adb logcat` output or exact screenshots were provided. Root cause is **not proven**.

### Actual fixes in source

1. `flutter_app/lib/main.dart`: `runApp(StartupGate(...))` is called immediately after binding setup. The first frame displays `TotiChat Beta` and an activity indicator rather than awaiting asset loading/Supabase initialization on the Android launch theme.
2. Startup loading is time-bounded. A failed or hanging local asset/platform initialization shows a generic visible error, not an indefinite blank window; no service credentials or exception details are displayed to users.
3. `flutter_app/scripts/prepare_android.sh`: the test APK's AndroidManifest `<application>` contains `io.flutter.embedding.android.EnableImpeller=false` for an Android renderer compatibility trial. Flutter's official documentation provides this flag; it is **not proof** that Impeller caused the original failure.
4. `flutter_app/test/startup_gate_test.dart`: tests startup pending/ready/error states, including synchronous failures.
5. `.github/workflows/totichat-staging-compact-apk.yml`: validates first-frame source and the AndroidManifest renderer flag and creates separately labeled StartupFix ARM64/ARM32 artifacts.

## CI and testing

- [Flutter first-frame startup source/tests](https://github.com/QYEM7/TotiChatpro/actions/runs/39338037391).
- [StartupFix Android compact test APKs](https://github.com/QYEM7/TotiChatpro/actions/runs/39338065156).
- At document creation, runtime on the reported physical phone is still **NOT VERIFIED**. Emulator/device tests are not substituted by GitHub build success.

## Minimal on-device triage

1. Record phone manufacturer, model, Android version and CPU compatibility; preferably test ARM64 first.
2. When replacing an older QA build, verify no pending gift operations before clearing/uninstalling the local app, because the retry UUID can be retained locally. CI disposable debug signing may cause Android's update-signature mismatch, requiring uninstall of an old beta package.
3. Cold-launch the StartupFix APK, record whether **TotiChat Beta loading screen**, **clear error screen**, or **Google login screen** appears. Capture the last visible state and elapsed time.
4. If no Flutter frame is visible, collect Android `adb logcat` around launch, especially `AndroidRuntime`, `Flutter`, and graphics renderer messages; test an Android emulator or alternate chipset if available.
5. If loading/Google login renders, do not mark app accepted until real two-device OAuth, audio, wallet/gifts and moderation tests pass.

Do not apply changes to production, Google Play or `main` for this troubleshooting round.
