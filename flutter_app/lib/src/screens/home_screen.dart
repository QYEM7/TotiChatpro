import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../data/room_repository.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  const _HomeData(this.rooms, this.banners);
  final List<RoomSummary> rooms;
  final List<HomeBanner> banners;
}

class _HomeScreenState extends State<HomeScreen> {
  late final RoomRepository _repository;
  late Future<_HomeData> _future;
  int _tab = 0;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _repository = RoomRepository(Supabase.instance.client);
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final rooms = await _repository.publicRooms();
    final banners = await _repository.activeBanners();
    return _HomeData(rooms, banners);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder owns error rendering.
    }
  }

  Future<void> _enter(RoomSummary room) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await _repository.join(room.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: RoomScreen(room: room, repository: _repository),
          ),
        ),
      );
      if (mounted) await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('room_enter_failed'))),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF26C096);
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: mint,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 15),
              child: Row(children: [
                Text(
                  UiText.get('home_party'),
                  style: const TextStyle(
                    color: Color(0xFF064E3B),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  UiText.get('home_royal'),
                  style: const TextStyle(
                    color: Color(0xAA064E3B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  UiText.get('home_discover'),
                  style: const TextStyle(
                    color: Color(0xAA064E3B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF064E3B)),
                  onPressed: _refresh,
                  tooltip: UiText.get('refresh'),
                ),
              ]),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _homeBody(),
                1 => Center(child: Text(UiText.get('message_pending'))),
                _ => const _ProfileView(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: mint),
            label: UiText.get('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: UiText.get('messages'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: UiText.get('profile'),
          ),
        ],
      ),
    );
  }

  Widget _homeBody() => FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    UiText.get('rooms_load_failed'),
                    textAlign: TextAlign.center,
                  ),
                ),
                OutlinedButton(
                  onPressed: _refresh,
                  child: Text(UiText.get('retry')),
                ),
              ]),
            );
          }
          final data = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (data.banners.isNotEmpty)
                  SliverToBoxAdapter(child: _bannerStrip(data.banners)),
                if (data.rooms.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(UiText.get('rooms_empty'))),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                    sliver: SliverGrid.builder(
                      itemCount: data.rooms.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.86,
                      ),
                      itemBuilder: (context, index) => _roomCard(
                        data.rooms[index],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _bannerStrip(List<HomeBanner> banners) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          itemBuilder: (context, index) => SizedBox(
            width: MediaQuery.sizeOf(context).width - 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                banners[index].url,
                fit: BoxFit.cover,
                semanticLabel: banners[index].title,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: banners.length,
        ),
      );

  Widget _roomCard(RoomSummary room) {
    final imageUrl = _repository.coverUrl(room);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _joining ? null : () => _enter(room),
      child: Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.expand(
              child: imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xFFE2E8F0),
                      child: Icon(Icons.headphones, color: Color(0xFF64748B)),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE2E8F0),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          room.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ]),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileData {
  const _ProfileData({required this.name, required this.publicId});
  final String name;
  final String? publicId;
}

class _ProfileViewState extends State<_ProfileView> {
  late final Future<_ProfileData> _profile = _loadProfile();

  Future<_ProfileData> _loadProfile() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    final profile = await client
        .from('profiles')
        .select('display_name')
        .eq('id', uid)
        .maybeSingle();
    if (profile == null) throw StateError('Profile missing');
    final status = await client.rpc(
      'phase5_special_id_status',
      params: {'p_target': uid},
    );
    final data = status as Map<String, dynamic>;
    return _ProfileData(
      name: profile['display_name'] as String,
      publicId: data['publicId'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ProfileData>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(UiText.get('profile_load_failed')));
          }
          final profile = snapshot.requireData;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.person, size: 34),
                ),
                const SizedBox(height: 24),
                Text(
                  '${UiText.get('profile_name')}: ${profile.name}',
                ),
                const SizedBox(height: 12),
                Text(
                  '${UiText.get('profile_public_id')}: ${profile.publicId ?? UiText.get('profile_public_id_pending')}',
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: Text(UiText.get('sign_out')),
                ),
              ],
            ),
          );
        },
      );
}
