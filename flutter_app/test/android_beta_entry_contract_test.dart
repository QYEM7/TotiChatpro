import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Google OAuth callback is consistent with the Flutter app', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final config = File('lib/core/app_config.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final login = File('lib/features/auth/login_screen.dart')
        .readAsStringSync();

    expect(config, contains(
        "static const oauthRedirect = 'com.totichat.next://auth/callback'"));
    expect(manifest, contains('android:scheme="com.totichat.next"'));
    expect(manifest, contains('android:host="auth"'));
    expect(manifest, contains('android:pathPrefix="/callback"'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(main, contains('AuthFlowType.pkce'));
    expect(main, contains('supabase.auth.onAuthStateChange'));
    expect(login, contains('OAuthProvider.google'));
    expect(login, contains('redirectTo: AppConfig.oauthRedirect'));
    expect(login, isNot(contains('OAuthProvider.apple')));
    expect(login, isNot(contains('signInWithPassword(')));
    expect(login, isNot(contains('signInAnonymously(')));
  });

  test('the Android beta has microphone permissions and staging isolation',
      () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final config = File('lib/core/app_config.dart').readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.MODIFY_AUDIO_SETTINGS'));
    expect(config, contains('rziaedugbdwefbefcxjt.supabase.co'));
    expect(config, contains(
        "isStaging && publishableKey.startsWith('sb_publishable_')"));
    expect(config, isNot(contains('service_role')));
  });
}
