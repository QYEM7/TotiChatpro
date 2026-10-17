import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../../ui/toti_theme.dart';
import '../../ui/toti_visual_language.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _googleSignIn() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.oauthRedirect,
      );
    } catch (error) {
      if (mounted) setState(() { _error = 'تعذّر تسجيل Google. تحقق من الاتصال وإعدادات الربط.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hero({required bool wide}) => TotiGradientPanel(
    radius: wide ? 34 : 28,
    padding: EdgeInsets.symmetric(
      horizontal: wide ? 42 : 22, vertical: wide ? 38 : 30,
    ),
    child: SizedBox(
      height: wide ? 460 : 248,
      child: Stack(children: [
        const Positioned(top: 0, left: 0,
          child: Icon(Icons.auto_awesome_rounded,
            size: 30, color: Color(0xAAFFFFFF))),
        const Positioned(top: 65, right: 2,
          child: Icon(Icons.graphic_eq_rounded,
            size: 110, color: Color(0x38FFFFFF))),
        const Positioned(bottom: 12, left: 4,
          child: Icon(Icons.mic_external_on_rounded,
            size: 50, color: Color(0x33FFFFFF))),
        Align(
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const FalconMark(size: 86),
            const SizedBox(height: 20),
            const Text('TotiChat', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 40,
                letterSpacing: .2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Your voice. Your world.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white,
                fontSize: 16, letterSpacing: .3)),
          ]),
        ),
      ]),
    ),
  );

  Widget _loginPanel() => TotiGlassCard(
    radius: 28,
    padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome to TotiChat',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900,
            color: TotiColors.ink)),
        const SizedBox(height: 9),
        const Text('Join real voice rooms and meet your community.',
          style: TextStyle(fontSize: 14, color: TotiColors.muted)),
        const SizedBox(height: 30),
        SizedBox(height: 56, child: FilledButton(
          onPressed: _busy ? null : _googleSignIn,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_busy)
              const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2,
                  color: Colors.white))
            else
              Container(width: 29, height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(9)),
                child: const Text('G', style: TextStyle(
                  color: Color(0xFF4285F4), fontWeight: FontWeight.w900,
                  fontSize: 20))),
            const SizedBox(width: 12),
            Text(_busy ? 'Connecting to Google...' : 'Continue with Google',
              style: const TextStyle(fontWeight: FontWeight.w800,
                fontSize: 15)),
          ]),
        )),
        if (_error != null) Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(_error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        const SizedBox(height: 22),
        const Row(children: [
          Icon(Icons.shield_outlined, size: 17, color: TotiColors.muted),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Secure Google sign-in. No guest or demo accounts.',
            style: TextStyle(color: TotiColors.muted, fontSize: 12))),
        ]),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: TotiAtmosphere(
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Row(children: [
              Expanded(child: _hero(wide: true)),
              const SizedBox(width: 30),
              Expanded(child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _loginPanel(),
                ),
              )),
            ]),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
          child: Column(children: [
            _hero(wide: false),
            const SizedBox(height: 18),
            _loginPanel(),
          ]),
        );
      }),
    )),
  );
}
