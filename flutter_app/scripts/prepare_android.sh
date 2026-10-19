#!/usr/bin/env bash
set -euo pipefail

# Generate the Android host only. Do not build APK/AAB or deploy.
cd "$(dirname "$0")/.."
flutter create --platforms=android --org=com.totichat --project-name=totichat --no-pub .

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
        text = text.replace("<application", item + "\\n    <application", 1)
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
    manifest.write_text(text, encoding="utf-8")

assert 'android:scheme="com.totichat.beta"' in text
assert 'android:host="auth"' in text
assert 'android:pathPrefix="/callback"' in text
assert 'android.intent.category.BROWSABLE' in text
assert '<uses-permission android:name="android.permission.INTERNET"' in text, (
    "Expected Android INTERNET permission was not found; review generated manifest"
)
print("Android host & OAuth callback prepared; no Android application was built.")
PY
