import 'package:flutter/material.dart';

import '../../data/totichat_repository.dart';
import '../../models/room_models.dart';
import '../../ui/toti_theme.dart';
import '../room/room_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});
  final TotiChatRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RoomsDirectory(repository: widget.repository, explore: false),
      RoomsDirectory(repository: widget.repository, explore: true),
      AccountPage(repository: widget.repository, walletOnly: true),
      AccountPage(repository: widget.repository, walletOnly: false),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: 'اكتشف'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'محفظتي'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'ملفي'),
          ],
        ),
      ),
    );
  }
}

class RoomsDirectory extends StatefulWidget {
  const RoomsDirectory({super.key, required this.repository, required this.explore});
  final TotiChatRepository repository;
  final bool explore;

  @override
  State<RoomsDirectory> createState() => _RoomsDirectoryState();
}

class _RoomsDirectoryState extends State<RoomsDirectory> {
  Future<List<RoomInfo>>? _rooms;
  Future<List<Map<String, dynamic>>>? _banners;
  String _filter = '';

  @override
  void initState() { super.initState(); _reload(); }

  void _reload() {
    setState(() {
      _rooms = widget.repository.publicRooms();
      _banners = widget.repository.activeBanners();
    });
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController();
    bool isPrivate = false;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) =>
        AlertDialog(
          title: const Text('إنشاء غرفة حقيقية'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, maxLength: 60,
              decoration: const InputDecoration(labelText: 'اسم الغرفة (3–60 حرفاً)')),
            SwitchListTile(
              title: const Text('غرفة خاصة'), value: isPrivate,
              onChanged: (v) => setDialogState(() => isPrivate = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(
              context, (controller.text, isPrivate)), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      final room = await widget.repository.createRoom(result.$1, isPrivate: result.$2);
      if (!mounted) return;
      _reload();
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => RoomScreen(repository: widget.repository, room: room)));
      if (mounted) _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء الغرفة: $error')));
    }
  }

  Future<void> _enter(RoomInfo room) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => RoomScreen(repository: widget.repository, room: room)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _rooms;
        await _banners;
      },
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(children: [
            const FalconMark(size: 48),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TotiChat', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: TotiColors.ink)),
                Text('مجتمعك الصوتي', style: TextStyle(color: Colors.black54)),
              ])),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
          ]),
        )),
        if (!widget.explore) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(colors: [TotiColors.plum, Color(0xFF9C86D8)]),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.graphic_eq_rounded, size: 42, color: TotiColors.gold),
              SizedBox(height: 12),
              Text('كل الأصوات إلها مكان', style: TextStyle(
                fontSize: 23, color: Colors.white, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('اكتشف غرفاً حقيقية أو ابدأ جلستك الخاصة.',
                style: TextStyle(color: Colors.white70)),
            ]),
          ),
        )),
        if (!widget.explore) SliverToBoxAdapter(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _banners,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return SizedBox(height: 145, child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final b = snapshot.data![i];
                return ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: Stack(children: [
                    Image.network(b['image_url'] as String, width: 265, height: 140,
                      fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                    Positioned(right: 12, bottom: 10, child: Text(
                      b['title']?.toString() ?? '', style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))),
                  ]));
              },
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemCount: snapshot.data!.length,
            ));
          },
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(child: Text(widget.explore ? 'اكتشف الغرف' : 'الغرف العامة',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            FilledButton.tonalIcon(onPressed: _createRoom,
              icon: const Icon(Icons.add), label: const Text('غرفة جديدة')),
          ]),
        )),
        if (widget.explore) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (value) => setState(() => _filter = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'ابحث عن اسم غرفة...'),
          ),
        )),
        FutureBuilder<List<RoomInfo>>(
          future: _rooms,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SliverFillRemaining(child: Center(
                child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذّر تحميل الغرف من الخادم'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                ],
              )));
            }
            final rooms = (snapshot.data ?? []).where((room) =>
              room.title.toLowerCase().contains(_filter.toLowerCase())).toList();
            if (rooms.isEmpty) {
              return SliverFillRemaining(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.meeting_room_outlined, size: 50, color: TotiColors.plum),
                  const SizedBox(height: 12),
                  Text(_filter.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد غرف عامة حالياً'),
                ],
              )));
            }
            return SliverList.builder(
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Card(child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _enter(room),
                    child: Padding(padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(width: 58, height: 58,
                          decoration: BoxDecoration(
                            color: TotiColors.lavender,
                            borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.mic_rounded, color: TotiColors.plum, size: 29)),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('غرفة صوتية', style: TextStyle(color: Colors.black54)),
                          ])),
                        const Icon(Icons.chevron_left_rounded),
                      ]))),
                  ),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ]),
    );
  }
}
