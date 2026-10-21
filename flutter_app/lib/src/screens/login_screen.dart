import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/staging_config.dart';
import '../core/green_theme.dart';
import '../core/ui_text.dart';

/// Approved first-opening screen from the original 8-screen TotiChat board.
/// This changes presentation only: both buttons use the existing secure
/// Google OAuth, with the second button prompting account selection.
/// No password/guest login, mock session, or production backend is introduced.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _openingGoogle = false;

  Future<void> _loginWithGoogle({bool chooseAccount = false}) async {
    if (_openingGoogle) return;
    setState(() => _openingGoogle = true);
    try {
      final opened = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: StagingConfig.oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: chooseAccount ? {'prompt': 'select_account'} : null,
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
  Widget build(BuildContext context) => Scaffold(
        key: const Key('totichat-green-login'),
        backgroundColor: GreenTheme.background,
        body: Stack(children: [
          const Positioned.fill(child: CustomPaint(
            painter: _MintLandscapePainter(),
          )),
          SafeArea(
            child: LayoutBuilder(builder: (context, limits) {
              // The reference is a vertical screen. Allow smaller Android
              // devices and larger accessibility fonts to scroll safely.
              final h = limits.maxHeight;
              final compact = h < 680;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(25, compact ? 16 : 31, 25, 22),
                    child: Column(children: [
                      SizedBox(height: compact ? 15 : h * .075),
                      Image.asset(
                        'assets/images/reference_approved_falcon.webp',
                        key: const Key('reference-first-screen-falcon'),
                        width: compact ? 116 : 151,
                        height: compact ? 116 : 151,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.flutter_dash, size: 110,
                          color: Color(0xFF065540)),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'TotiChat',
                        style: TextStyle(
                          color: Color(0xFF084A3A),
                          fontSize: 37,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.9,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'صوت يجمعنا',
                        style: TextStyle(
                          color: Color(0xFF667F76),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 65 : h * .185),
                      const Text(
                        'مجتمع صوتي عربي',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF084D3D),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'أقرب إلى قلبك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF084D3D),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: compact ? 37 : h * .068),
                      _EntryButton(
                        key: const Key('totichat-google-sign-in'),
                        busy: _openingGoogle,
                        label: 'تسجيل الدخول بواسطة Google',
                        google: true,
                        onPressed: () => _loginWithGoogle(),
                      ),
                      const SizedBox(height: 18),
                      const Row(children: [
                        Expanded(child: Divider(color: Color(0xFFB2D9CB))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 17),
                          child: Text('أو', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: Color(0xFF0A4E3D))),
                        ),
                        Expanded(child: Divider(color: Color(0xFFB2D9CB))),
                      ]),
                      const SizedBox(height: 18),
                      _EntryButton(
                        key: const Key('totichat-other-account'),
                        busy: _openingGoogle,
                        label: 'تسجيل الدخول باسم آخر',
                        google: false,
                        onPressed: () => _loginWithGoogle(chooseAccount: true),
                      ),
                      SizedBox(height: compact ? 33 : h * .075),
                      Text(
                        UiText.get('login_terms_notice'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF718F85),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ]),
      );
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.busy,
    required this.google,
  });
  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final bool google;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 62,
    child: OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF073D33),
        side: const BorderSide(color: Color(0xFFD4E9DF)),
        shape: const StadiumBorder(),
        elevation: 3,
        shadowColor: const Color(0x210E9270),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.ltr,
        children: [
          if (busy) const SizedBox(width: 23, height: 23,
            child: CircularProgressIndicator(strokeWidth: 2))
          else if (google) const _GoogleMark()
          else const Icon(Icons.person_add_alt_1_outlined,
            color: Color(0xFF075E47), size: 27),
          const SizedBox(width: 13),
          Flexible(child: Text(
            label, textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          )),
        ],
      ),
    ),
  );
}

/// Google multi-colour mark, rendered without pulling another image asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26, height: 26,
    child: Stack(children: [
      const Positioned.fill(child: CircularProgressIndicator(
        value: .99, strokeWidth: 7,
        color: Color(0xFF34A853),
      )),
      const Positioned(top: 0, left: 0, right: 12, bottom: 12,
        child: ColoredBox(color: Color(0xFFEA4335))),
      const Positioned(bottom: 0, left: 0, right: 12, top: 14,
        child: ColoredBox(color: Color(0xFFFBBC05))),
      const Positioned(top: 10, right: 0, height: 7, width: 16,
        child: ColoredBox(color: Color(0xFF4285F4))),
      Center(child: Container(
        width: 11, height: 11,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      )),
    ]),
  );
}

/// Pale mint mountain silhouettes and curved waves reproduce the accepted
/// splash composition independently from the functional sign-in buttons.
class _MintLandscapePainter extends CustomPainter {
  const _MintLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFBFFFC), Color(0xFFF1FFF8), Color(0xFFD9F6E9)],
    ).createShader(bounds));

    Path ridge(double a, double b, double c, double d) => Path()
      ..moveTo(0, size.height * a)
      ..quadraticBezierTo(size.width * .14, size.height * b,
        size.width * .28, size.height * c)
      ..quadraticBezierTo(size.width * .57, size.height * d,
        size.width, size.height * b)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(ridge(.27,.47,.39,.57),
      Paint()..color = const Color(0x1537B593));
    canvas.drawPath(ridge(.39,.49,.55,.57),
      Paint()..color = const Color(0x1955CAA6));
    final left = Path()
      ..moveTo(0, size.height*.31)
      ..lineTo(size.width*.08,size.height*.37)
      ..lineTo(size.width*.17,size.height*.51)
      ..lineTo(size.width*.30,size.height*.55)
      ..lineTo(size.width*.40,size.height*.62)
      ..quadraticBezierTo(size.width*.17,size.height*.55,0,size.height*.57)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0x255EA88F));
    final right = Path()
      ..moveTo(size.width,size.height*.28)
      ..lineTo(size.width*.90,size.height*.40)
      ..lineTo(size.width*.83,size.height*.47)
      ..lineTo(size.width*.73,size.height*.57)
      ..lineTo(size.width*.62,size.height*.63)
      ..quadraticBezierTo(size.width*.88,size.height*.56,
        size.width,size.height*.64)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0x2159B99B));

    final wave1 = Path()
      ..moveTo(0,size.height*.58)
      ..cubicTo(size.width*.27,size.height*.80,size.width*.70,
        size.height*.59,size.width,size.height*.67)
      ..lineTo(size.width,size.height)
      ..lineTo(0,size.height)..close();
    canvas.drawPath(wave1,Paint()..color=const Color(0x55E6FFF1));
    final wave2 = Path()
      ..moveTo(0,size.height*.69)
      ..cubicTo(size.width*.35,size.height*.72,size.width*.78,
        size.height*.76,size.width,size.height*.64)
      ..lineTo(size.width,size.height)
      ..lineTo(0,size.height)..close();
    canvas.drawPath(wave2,Paint()..color=const Color(0x49E5FAEF));
    final bottom = Path()
      ..moveTo(0,size.height*.91)
      ..quadraticBezierTo(size.width*.53,size.height*.84,
        size.width,size.height*.90)
      ..lineTo(size.width,size.height)
      ..lineTo(0,size.height)..close();
    canvas.drawPath(bottom,Paint()..color=const Color(0x2675D5B4));
  }

  @override
  bool shouldRepaint(covariant _MintLandscapePainter oldDelegate) => false;
}
