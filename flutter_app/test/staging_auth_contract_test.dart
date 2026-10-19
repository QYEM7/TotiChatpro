import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/staging_config.dart';

void main() {
  group('Staging-only mobile authentication contract', () {
    test('uses the intended isolated Supabase project', () {
      expect(
        StagingConfig.url,
        'https://rziaedugbdwefbefcxjt.supabase.co',
      );
      expect(StagingConfig.configuredUrl, StagingConfig.url);
      expect(StagingConfig.valid, isTrue);
    });

    test('Google return stays within beta Android application', () {
      expect(
        StagingConfig.oauthRedirect,
        'com.totichat.beta://auth/callback',
      );
    });

    test('client configuration uses a public, non-secret key', () {
      final key = StagingConfig.publishableKey;
      expect(key, startsWith('sb_publishable_'));
      expect(key, isNot(contains('service_role')));
      expect(key, isNot(startsWith('sb_secret_')));
    });
  });
}
