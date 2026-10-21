import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../core/green_theme.dart';
import '../core/premium_ui.dart';
import 'explore_view.dart';
import 'premium_account_screens.dart';
import 'premium_social_screens.dart';
import '../core/session_exit.dart';
import '../data/room_repository.dart';
import '../data/gift_repository.dart';
import '../data/admin_session_repository.dart';
import 'room_screen.dart';
import 'create_room_screen.dart';
import 'direct_inbox_view.dart';
import 'admin_center_screen.dart';

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
  bool _signingOut = false;
  final _roomKey = GlobalKey<RoomScreenState>();
  RoomSummary? _activeRoom;
  bool _roomMinimized = false;

  void _openRoom(RoomSummary room) {
    setState(() {
      _activeRoom = room;
      _roomMinimized = false;
    });
  }

  void _onRoomLeave() {
    setState(() {
      _activeRoom = null;
      _roomMinimized = false;
    });
    _refresh();
  }

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
    if (_activeRoom != null) {
      if (_activeRoom!.id == room.id) {
        setState(() => _roomMinimized = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiText.get('room_leave_first'))),
        );
      }
      return;
    }
    setState(() => _joining = true);
    try {
      await _repository.join(room.id);
      if (!mounted) return;
      _openRoom(room);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('room_enter_failed'))),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _signOutSafely() async {
    if (_signingOut) return;
    final active = _activeRoom;
    if (active != null) {
      final ownsRoom = active.ownerId ==
          Supabase.instance.client.auth.currentUser?.id;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(ownsRoom
              ? UiText.get('room_leave_owner_question')
              : UiText.get('room_leave_question')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(UiText.get('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(UiText.get('confirm')),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => _signingOut = true);
    try {
      await SessionExit.run(
        hasRoom: _activeRoom != null,
        closeRoom: () async {
          final state = _roomKey.currentState;
          return state != null && await state.closeWithoutPrompt();
        },
        signOut: () => Supabase.instance.client.auth.signOut(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiText.get('sign_out_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _createRoom() async {
    if (_joining) return;
    if (_activeRoom != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('room_leave_first'))),
      );
      return;
    }
    final created = await Navigator.of(context).push<RoomSummary>(
      MaterialPageRoute<RoomSummary>(
        builder: (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: CreateRoomScreen(),
        ),
      ),
    );
    if (created == null || !mounted) return;
    _openRoom(created);
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: page,
      ),
    ));
  }

  void _openExplore() => _openPage(
    Scaffold(
      backgroundColor: GreenTheme.background,
      appBar: AppBar(title: Text(UiText.get('discover_title'))),
      body: ExploreView(
        repository: _repository,
        onRoomSelected: (room) {
          Navigator.of(context).pop();
          _enter(room);
        },
        onCreateRoom: () {
          Navigator.of(context).pop();
          _createRoom();
        },
      ),
    ),
  );

  Widget _quickActions() {
    final actions = <({IconData icon, String label, VoidCallback call})>[
      (icon: Icons.explore_outlined, label: UiText.get('discover_title'), call: _openExplore),
      (icon: Icons.storefront_outlined, label: UiText.get('store_title'), call: () => _openPage(const StoreScreen())),
      (icon: Icons.account_balance_wallet_outlined, label: UiText.get('wallet_title'), call: () => _openPage(const WalletScreen())),
      (icon: Icons.favorite_border, label: UiText.get('cp_title'), call: () => _openPage(const RelationshipScreen())),
      (icon: Icons.apartment_outlined, label: UiText.get('agency_title'), call: () => _openPage(const AgencyScreen())),
    ];
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final action = actions[index];
          return InkWell(
            onTap: action.call,
            borderRadius: BorderRadius.circular(19),
            child: SizedBox(
              width: 86,
              child: PremiumSurface(
                padding: const EdgeInsets.all(9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, color: GreenTheme.primaryDark, size: 26),
                    const SizedBox(height: 6),
                    Text(action.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11, color: GreenTheme.primaryDark,
                        fontWeight: FontWeight.w800,
                      )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mint = GreenTheme.mint;
    return PopScope(
      canPop: _activeRoom == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeRoom != null && !_roomMinimized) {
          setState(() => _roomMinimized = true);
        }
      },
      child: Stack(
        children: [
          Scaffold(
      key: const Key('totichat-green-home'),
      backgroundColor: GreenTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: GreenTheme.highlight,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 15),
              child: Row(children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: GreenTheme.primaryDark,
                  backgroundImage: AssetImage('assets/images/toti-login-bg.jpg'),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text('TotiChat',
                    style: TextStyle(
                      color: GreenTheme.primaryDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    )),
                ),
                IconButton(
                  key: const Key('premium-search'),
                  icon: const Icon(Icons.search, color: GreenTheme.primaryDark),
                  onPressed: _openExplore,
                  tooltip: UiText.get('discover_title'),
                ),
                IconButton(
                  key: const Key('premium-notifications'),
                  icon: const Icon(Icons.notifications_none, color: GreenTheme.primaryDark),
                  onPressed: () => _openPage(const NotificationsScreen()),
                  tooltip: UiText.get('notifications_title'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: GreenTheme.primaryDark),
                  onPressed: _refresh,
                  tooltip: UiText.get('refresh'),
                ),
              ]),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _homeBody(),
                1 => const DirectInboxView(),
                _ => _ProfileView(onSignOut: _signOutSafely),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _joining ? null : _createRoom,
              icon: const Icon(Icons.add),
              label: Text(UiText.get('room_create')),
            )
          : null,
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
          ),
          if (_activeRoom != null)
            Positioned.fill(
              child: Offstage(
                offstage: _roomMinimized,
                child: RoomScreen(
                  key: _roomKey,
                  room: _activeRoom!,
                  repository: _repository,
                  onLeave: _onRoomLeave,
                  onMinimize: () => setState(() => _roomMinimized = true),
                ),
              ),
            ),
          if (_activeRoom != null && _roomMinimized)
            Positioned(
              left: 16,
              bottom: 96,
              child: FloatingActionButton.extended(
                heroTag: 'room-restore',
                onPressed: () => setState(() => _roomMinimized = false),
                icon: const Icon(Icons.headset),
                label: Text(_activeRoom!.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
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
                SliverToBoxAdapter(child: _quickActions()),
                if (data.banners.isNotEmpty)
                  SliverToBoxAdapter(child: _bannerStrip(data.banners)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: PremiumHeader(
                      title: UiText.get('rooms_section'),
                      trailing: TextButton(
                        onPressed: _openExplore,
                        child: Text(UiText.get('view_all')),
                      ),
                    ),
                  ),
                ),
                if (data.rooms.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: PremiumEmptyState(
                      icon: Icons.headphones_outlined,
                      title: UiText.get('rooms_empty'),
                      subtitle: UiText.get('discover_empty_help'),
                      action: FilledButton.icon(
                        onPressed: _createRoom,
                        icon: const Icon(Icons.add),
                        label: Text(UiText.get('room_create')),
                      ),
                    ),
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
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          separatorBuilder: (context, index) => const SizedBox(width: 10),
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
                      color: GreenTheme.highlight,
                      child: Icon(Icons.headphones, color: Color(0xFF64748B)),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const ColoredBox(
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
            color: GreenTheme.ink,
          ),
        ),
      ]),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileData {
  const _ProfileData({
    required this.name,
    required this.publicId,
    required this.wallet,
    required this.admin,
  });
  final String name;
  final String? publicId;
  final WalletBalance? wallet;
  final AdminSession? admin;
}

class _ProfileViewState extends State<_ProfileView> {
  late Future<_ProfileData> _profile = _loadProfile();

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
    WalletBalance? wallet;
    AdminSession? admin;
    try {
      wallet = await GiftRepository(client).balance();
    } catch (_) {
      // Keep wallet unknown, not a fabricated zero balance.
    }
    try {
      admin = await AdminSessionRepository(client).current();
    } catch (_) {
      // Fail closed: hidden admin entry without authoritative status.
    }
    return _ProfileData(
      name: profile['display_name'] as String,
      publicId: data['publicId'] as String?,
      wallet: wallet,
      admin: admin,
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
          return ListView(
            padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 22),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(UiText.get('wallet_balance')),
                subtitle: Text(profile.wallet == null
                    ? UiText.get('wallet_no_balance')
                    : '${UiText.get('wallet_coins')}: ${profile.wallet!.coins}    ${UiText.get('wallet_diamonds')}: ${profile.wallet!.diamonds}'),
              ),
              if (profile.admin?.canEnterCenter == true)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(UiText.get('admin_center')),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminCenterScreen(),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              PremiumHeader(title: UiText.get('profile_services')),
              const SizedBox(height: 12),
              PremiumRow(
                icon: Icons.edit_outlined,
                title: UiText.get('profile_edit'),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()),
                  );
                  if (changed == true && mounted) {
                    setState(() => _profile = _loadProfile());
                  }
                },
              ),
              const SizedBox(height: 10),
              PremiumRow(
                icon: Icons.account_balance_wallet_outlined,
                title: UiText.get('wallet_title'),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const WalletScreen())),
              ),
              const SizedBox(height: 10),
              PremiumRow(
                icon: Icons.storefront_outlined,
                title: UiText.get('store_title'),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const StoreScreen())),
              ),
              const SizedBox(height: 10),
              PremiumRow(
                icon: Icons.favorite_border,
                title: UiText.get('cp_title'),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const RelationshipScreen())),
              ),
              const SizedBox(height: 10),
              PremiumRow(
                icon: Icons.apartment_outlined,
                title: UiText.get('agency_title'),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const AgencyScreen())),
              ),
              const SizedBox(height: 34),
              OutlinedButton(
                onPressed: widget.onSignOut,
                child: Text(UiText.get('sign_out')),
              ),
            ],
          );
        },
      );
}
