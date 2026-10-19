/// Staging is hard-pinned. A release must never silently point to production.
abstract final class StagingConfig {
  static const url = 'https://rziaedugbdwefbefcxjt.supabase.co';
  static const configuredUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: url,
  );
  static const publishableKey =
      String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_vVYku5VtyohuiGgehC3EdA_rSDGOUKB',
      );
  static const oauthRedirect = 'com.totichat.beta://auth/callback';

  static bool get valid =>
      configuredUrl == url && publishableKey.trim().isNotEmpty;
}
