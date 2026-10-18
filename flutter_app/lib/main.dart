import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/approved_app.dart';

const stagingProjectId = 'rziaedugbdwefbefcxjt';
const stagingUrl = 'https://$stagingProjectId.supabase.co';
const stagingPublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (stagingPublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: stagingUrl,
      anonKey: stagingPublishableKey,
    );
  }
  runApp(MaterialApp(
    title: 'TotiChat',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25BE8E)),
    ),
    home: stagingPublishableKey.isEmpty
        ? const _ConfigurationRequired()
        : const _SessionGate(),
  ));
}

class _ConfigurationRequired extends StatelessWidget {
  const _ConfigurationRequired();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Staging publishable key is missing. '
          'Start with --dart-define=SUPABASE_PUBLISHABLE_KEY=<staging publishable key>. '
          'No mock login or fake content is available.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _subscription = auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() => _session = event.session);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _session == null ? const ApprovedLoginScreen() : const ApprovedApp();
}
