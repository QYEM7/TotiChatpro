import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'domain.dart';
import 'staging_repository.dart';
import 'visual.dart';
import 'room_view.dart';

StagingRepository get repo => StagingRepository(Supabase.instance.client);
const loginRedirect = String.fromEnvironment('TOTICHAT_OAUTH_REDIRECT',
    defaultValue: 'com.totichat.next://login-callback/');

void showProblem(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تنفيذ العملية: ' + error.toString())));
}

class ApprovedLoginScreen extends StatefulWidget {
  const ApprovedLoginScreen({super.key});
  @override
  State<ApprovedLoginScreen> createState() => _ApprovedLoginScreenState();
}
class _ApprovedLoginScreenState extends State<ApprovedLoginScreen> {
  bool working = false;
  Future<void> login() async {
    if (working) return;
    setState(() => working = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google, redirectTo: loginRedirect);
      // Never assert logged-in here. SessionGate observes server auth events.
    } catch (e) {
      if (mounted) showProblem(context, e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF05010C),
      body: SafeArea(child: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(
          colors: [Color(0xFF32104A), Color(0xFF05010C)], radius: 1.2)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(children: [
          const Spacer(),
          Container(
            width: 224, height: 224,
            decoration: BoxDecoration(
              border: Border.all(color: ApprovedPalette.gold, width: 3),
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x77FFCC33), blurRadius: 35)],
            ),
            clipBehavior: Clip.antiAlias,
            child: ApprovedNetworkImage(url: approvedAsset('public/toti-login-bg.jpg')),
          ),
          const SizedBox(height: 20),
          const Text('Toti Chat', style: TextStyle(
            fontSize: 39, fontWeight: FontWeight.w900, color: ApprovedPalette.gold)),
          const Text('── توتى شات ──', style: TextStyle(
            fontSize: 23, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A))),
          const Spacer(),
          SizedBox(width: double.infinity, height: 58, child: FilledButton.icon(
            onPressed: working ? null : login,
            style: FilledButton.styleFrom(backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF151021)),
            icon: const Icon(Icons.login),
            label: Text(working ? 'جاري فتح Google...' : 'سجل الدخول عبر جوجل',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          )),
          const SizedBox(height: 15),
          const Text('حساب Google حقيقي فقط', style: TextStyle(color: Colors.white70)),
        ]),
      )),
    ),
  );
}

class ApprovedApp extends StatefulWidget {
  const ApprovedApp({super.key});
  @override
  State<ApprovedApp> createState() => _ApprovedAppState();
}
class _ApprovedAppState extends State<ApprovedApp> {
  int tab = 0;
  VoiceRoom? minimizedRoom;
  String subtab = 'party';
  String search = '';
  late Future<List<VoiceRoom>> rooms;
  late Future<List<BannerItem>> banners;

  @override
  void initState() {
    super.initState();
    reload();
  }
  void reload() {
    rooms = repo.publicRooms();
    banners = repo.publishedBanners();
  }
  Future<void> refresh() async {
    setState(reload);
    try { await Future.wait([rooms, banners]); } catch (_) {}
  }
  Future<void> openRoom(VoiceRoom room, {bool joined = false}) async {
    try {
      if (!joined) await repo.joinRoom(room.id);
      if (!mounted) return;
      final minimized = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => ApprovedRoomView(room: room)));
      if (mounted) {
        setState(() => minimizedRoom = minimized == true ? room : null);
      }
    } catch (error) {
      if (mounted) showProblem(context, error);
    } finally {
      if (mounted) setState(reload);
    }
  }
  Future<void> createRoom() async {
    final field = TextEditingController();
    final title = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إنشاء غرفة'),
      content: TextField(controller: field, maxLength: 60,
          decoration: const InputDecoration(hintText: 'اسم الغرفة')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('إنشاء')),
      ],
    ));
    field.dispose();
    if (title == null || title.trim().length < 2) return;
    try {
      final id = await repo.createRoom(title);
      if (!mounted) return;
      await openRoom(VoiceRoom(id: id, title: title.trim(),
        ownerId: repo.currentUserId ?? '', isPrivate: false), joined: true);
    } catch (error) {
      if (mounted) showProblem(context, error);
    }
  }
  Future<void> searchRooms() async {
    final field = TextEditingController(text: search);
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('بحث'),
      content: TextField(controller: field,
        decoration: const InputDecoration(hintText: 'اسم الغرفة')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('بحث')),
      ],
    ));
    field.dispose();
    if (value != null && mounted) setState(() => search = value.trim());
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: ApprovedPalette.cream,
      body: SafeArea(child: tab == 0 ? home() : tab == 1 ? messages() : profile()),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (minimizedRoom != null)
          Material(color: ApprovedPalette.violet, child: ListTile(
            title: Text(minimizedRoom!.title, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white)),
            leading: const Icon(Icons.keyboard_voice, color: ApprovedPalette.mint),
            trailing: const Icon(Icons.open_in_full, color: ApprovedPalette.gold),
            onTap: () {
              final room = minimizedRoom;
              if (room != null) openRoom(room, joined: true);
            },
          )),
        NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: tab,
        indicatorColor: const Color(0x3326C096),
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'الرسائل'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'أنا'),
        ],
        ),
      ]),
    ),
  );
  Widget home() => Column(children: [
    Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [ApprovedPalette.emerald, ApprovedPalette.emeraldDeep])),
      child: Row(children: [
        for (final item in [('party', 'حفلة'), ('royal', 'ملكي'), ('discover', 'اكتشف')])
          InkWell(
            onTap: () => setState(() => subtab = item.$1),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(children: [
                Text(item.$2, style: TextStyle(fontSize: 16,
                  color: subtab == item.$1 ? ApprovedPalette.ink : const Color(0x99064E3B),
                  fontWeight: FontWeight.w900)),
                if (subtab == item.$1)
                  Container(width: 17, height: 3, color: ApprovedPalette.ink),
              ]),
            ),
          ),
        const Spacer(),
        IconButton(onPressed: searchRooms,
          icon: const Icon(Icons.search, color: Colors.white)),
        IconButton(onPressed: createRoom,
          icon: const Icon(Icons.add_home_work_outlined, color: Colors.white)),
      ]),
    ),
    Expanded(child: RefreshIndicator(onRefresh: refresh, child: ListView(children: [
      FutureBuilder<List<BannerItem>>(future: banners, builder: (ctx, snap) {
        final entries = snap.data ?? const <BannerItem>[];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(borderRadius: BorderRadius.circular(16),
            child: ApprovedNetworkImage(url: entries.first.url, height: 156)),
        );
      }),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: _Category('الثروة', Color(0xFF7A1515), Icons.emoji_events)),
          SizedBox(width: 7),
          Expanded(child: _Category('الجاذبية', Color(0xFF123E6E), Icons.favorite)),
          SizedBox(width: 7),
          Expanded(child: _Category('الغرف', Color(0xFF0F543C), Icons.mic)),
        ]),
      ),
      FutureBuilder<List<VoiceRoom>>(future: rooms, builder: (ctx, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Padding(padding: EdgeInsets.all(45),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return emptyState('تعذر تحميل الغرف الحقيقية');
        if (subtab == 'royal') {
          return emptyState('تصنيف الغرف الملكية يحتاج بيانات موثقة من الخادم');
        }
        final entries = (snap.data ?? <VoiceRoom>[]).where(
          (r) => r.title.toLowerCase().contains(search.toLowerCase())).toList();
        if (entries.isEmpty) return emptyState('لا توجد غرف حقيقية للعرض');
        return Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الغرف الصوتية', style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 12),
            for (final room in entries)
              Padding(padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(onTap: () => openRoom(room),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4DDCB))),
                    child: Row(children: [
                      Container(width: 66, height: 66,
                        decoration: BoxDecoration(color: ApprovedPalette.emeraldDeep,
                          borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.graphic_eq, color: Colors.white, size: 32)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(room.title, style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
                      const Icon(Icons.chevron_left),
                    ]),
                  )),
              ),
          ]));
      }),
    ]))),
  ]);
  Widget messages() => Column(children: [
    const _Header('الرسائل'),
    Expanded(child: emptyState('لا توجد محادثات مرتبطة بالخادم للعرض حالياً')),
  ]);
  Widget profile() => FutureBuilder<Map<String, dynamic>>(
    future: repo.myProfile(),
    builder: (ctx, snap) {
      if (snap.hasError) return emptyState('تعذر تحميل ملفك الشخصي');
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final profile = snap.data!;
      final avatar = profile['avatar_url'] as String?;
      return ListView(children: [
        const _Header('ملفي'),
        const SizedBox(height: 32),
        Center(child: CircleAvatar(radius: 46,
          foregroundImage: avatar != null ? NetworkImage(avatar) : null,
          child: avatar == null ? const Icon(Icons.person, size: 44) : null)),
        const SizedBox(height: 12),
        Text(profile['display_name'] as String? ?? '',
          textAlign: TextAlign.center, style: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 23)),
        const SizedBox(height: 7),
        Text(profile['bio'] as String? ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FutureBuilder<int>(future: repo.coinsBalance(), builder: (ctx, balance) =>
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('الرصيد الحقيقي'),
            trailing: Text(balance.hasData ? balance.data.toString() : 'غير متاح'),
          )),
        const ListTile(
          leading: Icon(Icons.admin_panel_settings_outlined),
          enabled: false,
          title: Text('مركز الإدارة'),
          subtitle: Text('يُفعّل فقط بعد التحقق من الصلاحيات على الخادم'),
        ),
        Padding(padding: const EdgeInsets.all(18),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            onPressed: () async {
              try { await Supabase.instance.client.auth.signOut(); }
              catch (e) { if (context.mounted) showProblem(context, e); }
            },
          )),
      ]);
    },
  );
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext context) => Container(
    color: ApprovedPalette.emerald,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.all(18),
    child: Text(title, style: const TextStyle(
      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
  );
}

class _Category extends StatelessWidget {
  final String title;
  final Color background;
  final IconData icon;
  const _Category(this.title, this.background, this.icon);
  @override
  Widget build(BuildContext context) => GoldBorder(
    color: background,
    child: SizedBox(height: 92, child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(title, style: const TextStyle(
          color: Color(0xFFFDE68A), fontWeight: FontWeight.w900)),
        Icon(icon, size: 30, color: ApprovedPalette.gold),
      ],
    )),
  );
}

Widget emptyState(String text) => Padding(
  padding: const EdgeInsets.all(26),
  child: Center(child: Text(text, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black54))),
);
