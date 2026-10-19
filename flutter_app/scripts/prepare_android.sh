#!/usr/bin/env bash
set -euo pipefail

# Generate the Android host only. Do not build APK/AAB or deploy.
cd "$(dirname "$0")/.."
# A real plugin registry and JNI native assets require pub resolution AFTER the
# Android host exists. --no-pub previously skipped plugin registration and
# produced installable APKs missing GeneratedPluginRegistrant/libdartjni.
flutter create --platforms=android --org=com.totichat --project-name=totichat .


python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
# Flutter release manifest must explicitly authorize network access.
for permission in ["android.permission.INTERNET",
                   "android.permission.RECORD_AUDIO",
                   "android.permission.MODIFY_AUDIO_SETTINGS"]:
    item = f'<uses-permission android:name="{permission}" />'
    if item not in text:
        if "<application" not in text:
            raise SystemExit("Android application element missing")
        text = text.replace("<application", item + "\n    <application", 1)
if 'android:scheme="com.totichat.beta"' not in text:
    callback = """
            <!-- Supabase Staging Google OAuth return route. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.totichat.beta"
                      android:host="auth"
                      android:pathPrefix="/callback" />
            </intent-filter>
"""
    if "</activity>" not in text:
        raise SystemExit("MainActivity not found; Android template may have changed")
    text = text.replace("</activity>", callback + "        </activity>", 1)
# Work around devices whose Vulkan/Impeller startup shows only a white
# surface. This is a QA compatibility setting; it does not change LiveKit.
# Keep within <application>, never next to <uses-permission> in <manifest>.
if 'io.flutter.embedding.android.EnableImpeller' not in text:
    import re
    match = re.search(r'<application\b[^>]*>', text, flags=re.S)
    if match is None:
        raise SystemExit("Cannot locate generated Android application element")
    text = (text[:match.end()] +
        '\n        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />' +
        text[match.end():])
manifest.write_text(text, encoding="utf-8")

assert 'io.flutter.embedding.android.EnableImpeller' in text
assert 'android:scheme="com.totichat.beta"' in text
assert 'android:host="auth"' in text
assert 'android:pathPrefix="/callback"' in text
assert 'android.intent.category.BROWSABLE' in text
assert '<uses-permission android:name="android.permission.INTERNET"' in text, (
    "Expected Android INTERNET permission was not found; review generated manifest"
)
gradle = Path("android/app/build.gradle.kts")
if gradle.exists():
    config = gradle.read_text(encoding="utf-8")
    if "minSdk = flutter.minSdkVersion" in config:
        config = config.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
        gradle.write_text(config, encoding="utf-8")
    if "minSdk = 24" not in config:
        raise SystemExit("Android minSdk compatibility with image picker requires review")
# The test package must be isolated from any existing published app.
# Leave the generated Kotlin namespace unchanged (MainActivity path).
if not gradle.exists():
    raise SystemExit("Missing Android Gradle Kotlin configuration")
config = gradle.read_text(encoding="utf-8")
if 'applicationId = "com.totichat.totichat"' in config:
    config = config.replace(
        'applicationId = "com.totichat.totichat"',
        'applicationId = "com.totichat.beta"'
    )
    gradle.write_text(config, encoding="utf-8")
if 'applicationId = "com.totichat.beta"' not in config:
    raise SystemExit("Staging applicationId mismatch; refuse unsafe APK build")

# The launcher is explicitly labeled as a beta so it cannot be confused
# with a production app on the phone.
text = manifest.read_text(encoding="utf-8")
if 'android:label="totichat"' in text:
    text = text.replace('android:label="totichat"', 'android:label="TotiChat Beta"')
    manifest.write_text(text, encoding="utf-8")
if 'android:label="TotiChat Beta"' not in text:
    raise SystemExit("The Android launcher is not clearly identified as beta")

# Every beta APK must include registered Android plugins. The old generated
# host lacked this Java file and Supabase failed before Google login.
registrant = Path("android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
if not registrant.is_file() or not registrant.read_text(encoding="utf-8").strip():
    raise SystemExit("Android GeneratedPluginRegistrant missing after flutter create")
if "sharedpreferences" not in registrant.read_text(encoding="utf-8").lower():
    raise SystemExit("Android shared_preferences native plugin missing")
print("Android host, native Flutter plugin registry and OAuth callback prepared.")
PY
