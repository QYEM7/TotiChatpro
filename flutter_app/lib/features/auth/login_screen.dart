import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../../ui/toti_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final content = Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FalconMark(size: 78),
          const SizedBox(height: 26),
          const Text('TotiChat', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
              color: TotiColors.ink, letterSpacing: -.5)),
          const SizedBox(height: 6),
          const Text('عالمك الصوتي يبدأ من هنا', textAlign: TextAlign.center,
            style: TextStyle(color: TotiColors.plum, fontSize: 17)),
          const SizedBox(height: 48),
          const Text('أهلاً بعودتك', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('سجّل دخولك بحساب Google للانضمام إلى غرف حقيقية.',
            textAlign: TextAlign.right),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _googleSignIn,
            icon: _busy ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) :
                const Icon(Icons.login_rounded),
            label: Text(_busy ? 'جارٍ فتح Google…' : 'المتابعة باستخدام Google'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 14),
            child: Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          const Text('لا يوجد دخول تجريبي أو حسابات وهمية.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: wide ? Row(children: [
          Expanded(child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [TotiColors.plum, Color(0xFFAA8FD7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: const Center(child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.graphic_eq_rounded, size: 92, color: Colors.white),
                SizedBox(height: 20),
                Text('هنا يجتمع الصوت والصداقة', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, color: Colors.white,
                    fontWeight: FontWeight.w800)),
              ]),
            )),
          )),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450), child: content))),
        ]) : Center(child: SingleChildScrollView(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), child: content))),
      ),
    );
  }
}
