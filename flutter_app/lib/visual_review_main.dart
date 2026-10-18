import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/totichat_repository.dart';
import 'data/totichat_services.dart';
import 'features/auth/login_screen.dart';
import 'features/economy/gift_sheet.dart';
import 'features/home/home_screen.dart';
import 'features/room/room_seat_visual.dart';
import 'models/room_models.dart';
import 'ui/extracted_premium_panels.dart';
import 'ui/extracted_room_backdrop.dart';
import 'ui/toti_bottom_bar.dart';
import 'ui/toti_theme.dart';
import 'ui/toti_vip_tiers.dart';
import 'ui/toti_visual_language.dart';

/// Visual-review entrypoint only. NEVER use this file as the real app entrypoint.
/// No Supabase initialization, OAuth, LiveKit connection, money, or test users.
void main() => runApp(const TotiVisualReviewApp());

class _NoConnectionClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyPreviewRepository extends TotiChatRepository {
  const _EmptyPreviewRepository(super.client);

  @override
  Future<List<RoomInfo>> publicRooms() async => const [];

  @override
  Future<List<Map<String, dynamic>>> activeBanners() async => const [];
}

class _EmptyPreviewGifts extends TotiChatServices {
  const _EmptyPreviewGifts(super.client);

  @override
  Future<List<Map<String, dynamic>>> gifts() async => const [];
}

class TotiVisualReviewApp extends StatefulWidget {
  const TotiVisualReviewApp({super.key});

  @override
  State<TotiVisualReviewApp> createState() => _TotiVisualReviewAppState();
}

class _TotiVisualReviewAppState extends State<TotiVisualReviewApp> {
  final _client = _NoConnectionClient();
  late final _repository = _EmptyPreviewRepository(_client);
  late final _gifts = _EmptyPreviewGifts(_client);
  int _selected = 1;

  static const tabs = <({String name, IconData icon})>[
    (name: 'الدخول', icon: Icons.login_rounded),
    (name: 'الرئيسية', icon: Icons.home_rounded),
    (name: 'الغرفة', icon: Icons.mic_rounded),
    (name: 'الهدايا', icon: Icons.card_giftcard_rounded),
    (name: 'VIP', icon: Icons.workspace_premium_rounded),
    (name: 'ملفي', icon: Icons.person_rounded),
    (name: 'الوكالات', icon: Icons.groups_rounded),
    (name: 'الإدارة', icon: Icons.admin_panel_settings_rounded),
  ];

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TotiChat — Flutter Visual Review',
    theme: buildTotiTheme(),
    locale: const Locale('ar'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TotiColors.background,
        body: SafeArea(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              color: TotiRoyalPalette.deepEmerald,
              child: const Row(children: [
                Icon(Icons.visibility_rounded,
                  color: TotiRoyalPalette.mutedGold, size: 20),
                SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TotiChat — معاينة Flutter', style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w900)),
                    Text('الشكل فقط · بيانات فارغة · ليست نسخة تشغيل حقيقية',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10,
                        color: Color(0xFFECE0C4))),
                  ],
                )),
              ]),
            ),
            Container(
              height: 56,
              color: const Color(0xFFFFF8EA),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ChoiceChip(
                  tooltip: tabs[index].name,
                  avatar: Icon(tabs[index].icon, size: 16,
                    color: _selected == index
                      ? Colors.white : TotiRoyalPalette.emerald),
                  selected: _selected == index,
                  label: Text(tabs[index].name),
                  labelStyle: TextStyle(
                    color: _selected == index
                      ? Colors.white : TotiColors.ink,
                    fontSize: 12, fontWeight: FontWeight.w700),
                  selectedColor: TotiRoyalPalette.emerald,
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _selected = index),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selected,
                children: [
                  const IgnorePointer(child: LoginScreen()),
                  _HomeReview(repository: _repository),
                  const _EmptyRoomReview(),
                  IgnorePointer(child: GiftSheet(
                    api: _gifts,
                    roomId: '00000000-0000-4000-8000-000000000219',
                    members: const [],
                  )),
                  const _VipReview(),
                  const _InfoReview(
                    title: 'ملفي',
                    subtitle: 'حسابك الحقيقي وشارات VIP وCP تظهر بعد تسجيل الدخول',
                    icon: Icons.person_rounded,
                    sections: ['بيانات الملف الشخصي',
                      'العضويات والعلاقات المؤكدة', 'المحفظة والسجل الحقيقي'],
                  ),
                  const _InfoReview(
                    title: 'وكالات TotiChat',
                    subtitle: 'طلبات العضوية تظهر للحسابات المصرّح لها فقط',
                    icon: Icons.groups_rounded,
                    sections: ['وكالات المضيفين',
                      'طلبات الانضمام', 'وكيل الشحن'],
                  ),
                  const _InfoReview(
                    title: 'مركز الإدارة',
                    subtitle: 'لا تُعرض الصلاحيات أو الحسابات في معاينة غير متصلة',
                    icon: Icons.admin_panel_settings_rounded,
                    sections: ['التقارير الإدارية',
                      'إدارة الغرف', 'البلاغات والدعم'],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _HomeReview extends StatelessWidget {
  const _HomeReview({required this.repository});
  final TotiChatRepository repository;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Scaffold(
      body: RoomsDirectory(
        repository: repository,
        explore: false,
        onOpenRoom: (_) {},
      ),
      bottomNavigationBar: TotiBottomBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        onCreateRoom: () {},
      ),
    ),
  );
}

class _EmptyRoomReview extends StatelessWidget {
  const _EmptyRoomReview();

  @override
  Widget build(BuildContext context) => TotiAtmosphere(
    child: TotiRoomBackdrop(
      child: SafeArea(child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          const TotiRoyalTopBanner(
            title: 'الغرفة الصوتية',
            subtitle: 'شكل المقاعد الـ15 — فارغة بدون أعضاء تجريبيين',
            icon: Icons.graphic_eq_rounded,
          ),
          const SizedBox(height: 20),
          TotiGlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const TotiRoyalSectionHeading(
                title: 'المقاعد الصوتية',
                subtitle: 'معاينة توزيع المقاعد الثابتة',
                icon: Icons.mic_none_rounded,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 5,
                    childAspectRatio: .76,
                  ),
                  itemCount: 15,
                  itemBuilder: (context, index) => Column(children: [
                    const Expanded(child: RoomSeatVisual(
                      member: null, isOwner: false)),
                    Text('${index + 1}', style: const TextStyle(
                      fontSize: 10, color: TotiColors.ink)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const TotiRoyalSectionHeading(
            title: 'دردشة الغرفة',
            subtitle: 'لا توجد رسائل، هدايا، أو حضور وهمي',
            icon: Icons.chat_bubble_outline_rounded,
          ),
        ],
      )),
    ),
  );
}

class _VipReview extends StatelessWidget {
  const _VipReview();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      TotiRoyalTopBanner(
        title: 'نادي VIP',
        subtitle: 'معرض التصميم — لا توجد عضوية مفترضة أو مفعّلة',
      ),
      SizedBox(height: 21),
      TotiVipTierGallery(currentTier: 0),
    ],
  );
}

class _InfoReview extends StatelessWidget {
  const _InfoReview({
    required this.title, required this.subtitle,
    required this.icon, required this.sections,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> sections;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TotiRoyalTopBanner(title: title, subtitle: subtitle, icon: icon),
      const SizedBox(height: 18),
      const Text(
        'معاينة عناصر التصميم فقط. هذه ليست صفحة مرتبطة بحساب أو خادم.',
        style: TextStyle(fontSize: 12, color: TotiColors.muted),
      ),
      const SizedBox(height: 14),
      for (final name in sections) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TotiRoyalPanel(
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded,
              size: 18, color: TotiRoyalPalette.emerald),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(
              fontSize: 15, color: TotiColors.ink,
              fontWeight: FontWeight.w700))),
            const Icon(Icons.visibility_off_outlined,
              color: TotiColors.muted, size: 18),
          ]),
        ),
      ),
    ],
  );
}
