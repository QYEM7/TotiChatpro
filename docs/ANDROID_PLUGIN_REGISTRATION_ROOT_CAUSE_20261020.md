# TotiChat Android splash hang — actual emulator root-cause evidence

Date: 2026-10-20. Development branch `rebuild/flutter-v1`, **never main**.
No database, LiveKit, Google Play or production changes.

## User symptom

Two prior installable ARM APK variants appeared to stall at the OS-native,
white Flutter-logo splash. The actual physical-device root cause is **not yet
proven** without the phone's logcat and exact APK provenance; launcher icon is
Flutter's stock icon on all those Android hosts.

## What the first real Android 14 emulator exposed

Test: [Android 14 emulator run #39340755038](https://github.com/QYEM7/TotiChatpro/actions/runs/39340755038),
x86_64 **debug build**, launched actual `com.totichat.beta` MainActivity.

The Android emulator did display a real Flutter error screen after 24s:
`TotiChat Beta — TotiChat could not start. Check connection and restart the app.`
The process remained alive. This is strong evidence of *initialization* failure
on that build, not proof that the Flutter rasterizer universally fails.

The captured 2.7MB logcat and screenshot are saved as GitHub Actions artifact
[`totichat-android14-startup-evidence`](https://github.com/QYEM7/TotiChatpro/actions/runs/39340755038/artifacts/12229186704).
The exact relevant errors were:

```text
E/GeneratedPluginsRegister: ClassNotFoundException: io.flutter.plugins.GeneratedPluginRegistrant
E/flutter: Unhandled Exception: Failed to load dynamic library at path: libdartjni.so
SharedPreferencesAndroid.getAll -> SharedPreferences.getInstance
-> SharedPreferencesGotrueAsyncStorage._initialize
-> Supabase.initialize
```

The old **ARM64 and ARM32 release-compiled APKs** were independently inspected
and neither contained `libdartjni.so`. The old generated Android host artifact
did not contain `GeneratedPluginRegistrant.java` either.

## Root cause in the source build pipeline

Prior pipeline order was:

1. `flutter pub get` before the Android host existed
2. `flutter create ... --no-pub .` to make the host but **skip** pub resolution
3. `flutter build apk ... --no-pub` to compile the app, again skipping refresh

The resulting installable APK lacked registered Android plugins/native JNI
dependencies. This was not found by Dart widget tests or simple APK ZIP checks.

## Implemented fix and gates

- `flutter_app/scripts/prepare_android.sh` now uses `flutter create` **without**
  `--no-pub`: plugin resolution occurs after the Android host exists.
- Host generation fails unless the generated Java
  `io/flutter/plugins/GeneratedPluginRegistrant.java` exists and contains
  the Android shared-preferences plugin.
- Compact QA build workflow additionally refuses ARM64/ARM32 outputs without
  the `lib/<ABI>/libdartjni.so` native library.
- Android 14 emulator smoke workflow refuses missing registry/native library
  and requires the **actual Toti Chat Google login UI**. It captures logcat
  and screenshot even if its checks fail.

## Acceptance still needed

Do not call the bug fixed on the user's device until a new verified ARM64 build
opens past the native splash on the phone. The failed Android 14 smoke workflow
result was caused by shell assertion syntax after successfully saving its
screenshot/logcat; its actual runtime evidence is valid.

At documentation time, refreshed compact APK build and Android emulator smoke
were still running. Check results rather than assuming success:
- [Compact rebuilt artifacts](https://github.com/QYEM7/TotiChatpro/actions/runs/39341651338)
- [Android 14 first-frame check](https://github.com/QYEM7/TotiChatpro/actions/runs/39341762931)

Release gate: device login/voice/financial transaction acceptance still open.
