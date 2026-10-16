import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'data/totichat_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'ui/toti_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const TotiChatApp(configured: false));
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  runApp(const TotiChatApp(configured: true));
}

class TotiChatApp extends StatelessWidget {
  const TotiChatApp({super.key, required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TotiChat',
    debugShowCheckedModeBanner: false,
    theme: buildTotiTheme(),
    locale: const Locale('ar', 'IQ'),
    home: configured ? const _AuthGate() : const _SetupScreen(),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final signedIn = supabase.auth.currentSession != null &&
            supabase.auth.currentUser != null;
        if (!signedIn) return const LoginScreen();
        return HomeShell(repository: TotiChatRepository(supabase));
      },
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const FalconMark(size: 92),
          const SizedBox(height: 22),
          const Text('TotiChat — Staging setup required',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SelectableText(AppConfig.setupMessage, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('No demonstration users or fabricated balances are available.'),
        ]),
      ),
    ),
  );
}
