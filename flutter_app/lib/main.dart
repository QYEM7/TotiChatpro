import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/staging_config.dart';
import 'src/core/ui_text.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';

// A compile-time, offline diagnostic is intentionally separate from the
// beta experience. It bypasses Supabase, OAuth, assets and LiveKit entirely,
// so a white screen here points to the Android/Flutter rendering path rather
// than the network or auth setup. This must never masquerade as a beta app.
const bool startupDiagnosticOnly = bool.fromEnvironment(
  'TOTICHAT_DIAGNOSTIC_ONLY',
  defaultValue: false,
);

class StartupDiagnosticsApp extends StatelessWidget {
  const StartupDiagnosticsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TotiChat Device Test',
        home: Scaffold(
          backgroundColor: const Color(0xFF103A57),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFFFBBF24),
                      size: 68,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'TotiChat Device Test',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Flutter frame visible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Offline renderer check only. No login, rooms, audio or account access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// Render the first Flutter frame immediately. A slow native-plugin or local
// credential-store initialization must never leave Android on its blank
// launch theme with no visible diagnostic state.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (startupDiagnosticOnly) {
    runApp(const StartupDiagnosticsApp());
    return;
  }
  ErrorWidget.builder = (details) => const Material(
        color: Color(0xFFFDFBF7),
        child: Center(child: Text('TotiChat screen failed to load')),
      );
  runApp(StartupGate(
    initialize: initializeStagingBackend,
    ready: const TotiChatApp(),
  ));
}

Future<void> initializeStagingBackend() async {
  if (!StagingConfig.valid) {
    throw StateError('Invalid beta configuration');
  }
  await UiText.load().timeout(const Duration(seconds: 8));
  // Use only the public Staging key; no privileged credentials in clients.
  await Supabase.initialize(
    url: StagingConfig.configuredUrl,
    publishableKey: StagingConfig.publishableKey,
  ).timeout(const Duration(seconds: 15));
}

/// The first frame is visible before any storage, asset or Auth SDK await.
/// It shows an explicit failure instead of an indefinitely blank splash.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.ready,
  });

  final Future<void> Function() initialize;
  final Widget ready;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = Future<void>.sync(widget.initialize);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TotiChat Beta',
        home: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _BootstrapScreen(
                message: 'Starting TotiChat Beta...',
                loading: true,
              );
            }
            if (snapshot.hasError) {
              return const _BootstrapScreen(
                message:
                    'TotiChat could not start. Check connection and restart the app.',
                loading: false,
              );
            }
            return widget.ready;
          },
        ),
      );
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({
    required this.message,
    required this.loading,
  });

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFDFBF7),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.headphones,
                    size: 56,
                    color: Color(0xFF26C096),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TotiChat Beta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 18),
                  ] else ...[
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFB91C1C),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
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
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _verified = false;
          _error = UiText.get('auth_failed');
        });
      },
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
