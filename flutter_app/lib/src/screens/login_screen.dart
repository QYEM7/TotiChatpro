import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/staging_config.dart';
import '../core/ui_text.dart';

/// Layout cues are ported from the newly approved AuthScreen.tsx.
/// Phone/OTP simulation from the visual prototype is intentionally omitted.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _openingGoogle = false;

  Future<void> _loginWithGoogle() async {
    if (_openingGoogle) return;
    setState(() => _openingGoogle = true);
    try {
      final opened = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: StagingConfig.oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiText.get('google_login_failed'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('google_login_failed'))),
      );
    } finally {
      if (mounted) setState(() => _openingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFBBF24);
    return Scaffold(
      backgroundColor: const Color(0xFF05010C),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0515),
                    const Color(0xFF05010C),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -60,
            right: -60,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.24)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 14),
                        Column(children: [
                          Container(
                            width: 220,
                            height: 220,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: gold, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: gold.withValues(alpha: 0.38),
                                  blurRadius: 34,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                'https://raw.githubusercontent.com/mrbalmain11-star/-/main/public/toti-login-bg.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFF180A28),
                                  child: Icon(Icons.shield_outlined,
                                      size: 110, color: gold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Toti Chat',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: gold,
                            ),
                          ),
                          Text(
                            UiText.get('app_arabic_name'),
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ]),
                        Column(children: [
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed:
                                  _openingGoogle ? null : _loginWithGoogle,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E293B),
                              ),
                              child: _openingGoogle
                                  ? const CircularProgressIndicator()
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.login),
                                        Text(
                                          UiText.get('google_login'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const Icon(Icons.chevron_left),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            UiText.get('login_terms_notice'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
