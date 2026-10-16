import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/totichat_repository.dart';
import '../../ui/toti_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key, required this.repository, required this.walletOnly,
  });
  final TotiChatRepository repository;
  final bool walletOnly;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<List<Object?>>? _data;

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() {
    setState(() {
      _data = Future.wait<Object?>([
        widget.repository.ownProfile(),
        widget.repository.ownWallet(),
        widget.repository.ownAssignedId(),
      ]);
    });
  }

  String _coins(Object? value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '');
    return n == null ? '—' : n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { _refresh(); await _data; },
    child: ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        const FalconMark(size: 55),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.walletOnly ? 'محفظتي' : 'ملفي',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
      ]),
      const SizedBox(height: 20),
      FutureBuilder<List<Object?>>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _error('تعذّر جلب بيانات الحساب الحقيقية');
            return const Padding(padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()));
          }
          final profile = snapshot.data![0] as Map<String, dynamic>?;
          final wallet = snapshot.data![1] as Map<String, dynamic>?;
          final id = snapshot.data![2] as Map<String, dynamic>?;
          final publicId = id?['assigned'] == true ?
            (id?['publicId']?.toString() ?? '—') : 'بانتظار منح ID من الإدارة';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.walletOnly) Card(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                CircleAvatar(radius: 34, backgroundColor: TotiColors.lavender,
                  backgroundImage: profile?['avatar_url']?.toString().startsWith('https://') == true ?
                    NetworkImage(profile!['avatar_url'] as String) : null,
                  child: profile?['avatar_url'] == null ?
                    const Icon(Icons.person, size: 34) : null),
                const SizedBox(height: 14),
                Text(profile?['display_name']?.toString() ?? 'مستخدم TotiChat',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('ID: $publicId', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
                if (profile?['bio']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(profile!['bio'].toString(), textAlign: TextAlign.center),
                ],
              ]),
            )),
            const SizedBox(height: 16),
            const Text('الرصيد الحقيقي', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 12),
            if (wallet == null) const Card(child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('لم يرجع الخادم محفظة لهذا الحساب. لا نعرض رصيداً وهمياً.')))
            else Row(children: [
              Expanded(child: _metric('كوينز', _coins(wallet['coins']), Icons.toll)),
              const SizedBox(width: 8),
              Expanded(child: _metric('ألماس', _coins(wallet['diamonds']), Icons.diamond_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _metric('فضة', _coins(wallet['silver']), Icons.stars_outlined)),
            ]),
            if (!widget.walletOnly) ...[
              const SizedBox(height: 22),
              Card(child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('تسجيل Google'),
                subtitle: Text(Supabase.instance.client.auth.currentUser?.email ??
                  'حساب مصادق عليه'),
              )),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج'),
              ),
            ],
          ]);
        },
      ),
    ]),
  );

  Widget _metric(String title, String value, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(children: [
        Icon(icon, color: TotiColors.plum),
        const SizedBox(height: 7),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ])));

  Widget _error(String message) => Column(children: [
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
  ]);
}
