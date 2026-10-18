import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/staging_config.dart';
import 'src/core/ui_text.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UiText.load();

  if (!StagingConfig.valid) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text(UiText.get('app_config_error'))),
      ),
    ));
    return;
  }

  await Supabase.initialize(
    url: StagingConfig.configuredUrl,
    anonKey: StagingConfig.publishableKey,
  );
  runApp(const TotiChatApp());
}

class TotiChatApp extends StatelessWidget {
  const TotiChatApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TotiChat',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF26C096),
          ),
          fontFamily: 'sans-serif',
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AuthGate(),
        ),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  bool _checking = true;
  bool _verified = false;
  String? _error;
  int _verificationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _verifySession(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifySession());
  }

  Future<void> _verifySession() async {
    final generation = ++_verificationGeneration;
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (!mounted) return;

    if (session == null) {
      setState(() {
        _checking = false;
        _verified = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _checking = true;
      _verified = false;
      _error = null;
    });
    try {
      // RLS/authenticated alone is not sufficient: require backend verified
      // session (confirmed account, session row, MFA policy) to accept a login.
      final verifiedId = await client.rpc('phase4_verified_session');
      if (!mounted || generation != _verificationGeneration) return;
      if (verifiedId.toString() != session.user.id) {
        throw StateError('Server session identity mismatch');
      }
      setState(() {
        _checking = false;
        _verified = true;
      });
    } catch (_) {
      if (!mounted || generation != _verificationGeneration) return;
      setState(() {
        _checking = false;
        _verified = false;
        _error = UiText.get('auth_failed');
      });
    }
  }

  @override
  void dispose() {
    ++_verificationGeneration;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      return const LoginScreen();
    }
    if (_checking) {
      return _GateMessage(message: UiText.get('auth_pending'));
    }
    if (_verified) {
      return const HomeScreen();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error ?? UiText.get('auth_failed'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _verifySession,
                child: Text(UiText.get('retry')),
              ),
              TextButton(
                onPressed: () => client.auth.signOut(),
                child: Text(UiText.get('sign_out')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(message),
          ]),
        ),
      );
}
