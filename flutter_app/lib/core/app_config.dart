class AppConfig {
  AppConfig._();

  // Only this staging project is allowed by the first development milestone.
  static const stagingUrl = 'https://rziaedugbdwefbefcxjt.supabase.co';
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL', defaultValue: stagingUrl,
  );
  // Only the public/anon publishable key can be passed here. Never service_role.
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const oauthRedirect = 'com.totichat.next://auth/callback';

  static bool get isStaging => supabaseUrl == stagingUrl;

  static bool get isConfigured =>
      isStaging && publishableKey.isNotEmpty &&
      !publishableKey.toLowerCase().contains('service_role');

  static String get setupMessage {
    if (!isStaging) {
      return 'Production connections are blocked in this development build.';
    }
    return 'Staging publishable key is not configured. Build with '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=<public key>.';
  }
}
