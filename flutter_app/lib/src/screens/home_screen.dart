import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../core/green_theme.dart';
import '../core/reference_visuals.dart';
import 'reference_explore.dart';
import 'reference_notifications.dart';
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

  void _openDiscovery({String query = ''}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ReferenceExploreScreen(
          repository: _repository,
          initialQuery: query,
          onJoinRoom: (room) {
            Navigator.of(context).pop();
            _enter(room);
          },
          onCreateRoom: () {
            Navigator.of(context).pop();
            _createRoom();
          },
        ),
      ),
    ));
  }

  void _openNotifications() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const Directionality(
      textDirection: TextDirection.rtl,
      child: ReferenceNotificationsScreen(),
    )),
  );

  Widget _referenceHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(17, 8, 17, 11),
    child: Row(children: [
      const ReferenceBrand(),
      const Spacer(),
      IconButton(
        key: const Key('reference-search-open'),
        onPressed: _openDiscovery,
        icon: const Icon(Icons.search_rounded,size:26,color:ReferencePalette.ink),
        tooltip: UiText.get('home_discover'),
      ),
      const SizedBox(width: 3),
      IconButton(
        key: const Key('reference-notifications-open'),
        onPressed: _openNotifications,
        icon: const Icon(Icons.notifications_none_rounded,size:26,color:ReferencePalette.ink),
        tooltip: UiText.get('reference_notifications_title'),
      ),
    ]),
  );

  Widget _referenceCategories() {
    final entries=<({IconData icon,String label,Color color,Color background,VoidCallback tap})>[
      (
        icon:Icons.local_fire_department_rounded,
        label:UiText.get('reference_trending'),
        color:const Color(0xFFE66F3B),
        background:const Color(0xFFFFF1E5),
        tap:_openDiscovery,
      ),
      (
        icon:Icons.diamond_outlined,
        label:'VIP',
        color:ReferencePalette.teal,
        background:ReferencePalette.mint,
        tap:_openDiscovery,
      ),
      (
        icon:Icons.groups_2_rounded,
        label:UiText.get('reference_new_rooms'),
        color:ReferencePalette.teal,
        background:ReferencePalette.mint,
        tap:_openDiscovery,
      ),
      (
        icon:Icons.star_rounded,
        label:UiText.get('reference_featured'),
        color:const Color(0xFFDAAB33),
        background:const Color(0xFFFFF5E2),
        tap:_openDiscovery,
      ),
    ];
    return Padding(
      padding:const EdgeInsets.only(top:15,bottom:17),
      child:Row(
        mainAxisAlignment:MainAxisAlignment.spaceAround,
        children:entries.map((e)=>Expanded(child:ReferenceCategory(
          icon:e.icon,label:e.label,color:e.color,
          background:e.background,onTap:e.tap,
        ))).toList(),
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
      backgroundColor: ReferencePalette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _referenceHeader(),
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
    future:_future,
    builder:(context,snapshot) {
      if(snapshot.connectionState!=ConnectionState.done) {
        return const Center(child:CircularProgressIndicator(color:ReferencePalette.teal));
      }
      if(snapshot.hasError) {
        return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(UiText.get('rooms_load_failed')),
          const SizedBox(height:12),
          OutlinedButton(onPressed:_refresh,child:Text(UiText.get('retry'))),
        ]));
      }
      final data=snapshot.requireData;
      return RefreshIndicator(
        onRefresh:_refresh,
        child:CustomScrollView(
          key:const Key('reference-home-scroll'),
          physics:const AlwaysScrollableScrollPhysics(),
          slivers:[
            SliverPadding(
              padding:const EdgeInsets.fromLTRB(17,9,17,4),
              sliver:SliverToBoxAdapter(child:ReferenceWelcomeHero(
                title:UiText.get('reference_welcome_title'),
                subtitle:UiText.get('reference_welcome_subtitle'),
              )),
            ),
            if(data.banners.isNotEmpty)
              SliverToBoxAdapter(child:_bannerStrip(data.banners)),
            SliverPadding(
              padding:const EdgeInsets.symmetric(horizontal:12),
              sliver:SliverToBoxAdapter(child:_referenceCategories()),
            ),
            SliverPadding(
              padding:const EdgeInsets.fromLTRB(16,0,16,10),
              sliver:SliverToBoxAdapter(child:ReferenceSection(
                title:UiText.get('reference_featured_rooms'),
                actionLabel:UiText.get('reference_show_all'),
                onAction:_openDiscovery,
              )),
            ),
            if(data.rooms.isEmpty)
              SliverPadding(
                padding:const EdgeInsets.symmetric(horizontal:16),
                sliver:SliverToBoxAdapter(child:ReferenceEmptyRooms(
                  title:UiText.get('rooms_empty'),
                  subtitle:UiText.get('reference_no_rooms_explanation'),
                  actionLabel:UiText.get('room_create'),
                  onAction:_createRoom,
                )),
              )
            else
              SliverPadding(
                padding:const EdgeInsets.fromLTRB(15,0,15,15),
                sliver:SliverGrid.builder(
                  itemCount:math.min(data.rooms.length,4),
                  gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:2,
                    mainAxisSpacing:12,
                    crossAxisSpacing:12,
                    childAspectRatio:.98,
                  ),
                  itemBuilder:(context,index)=>_roomCard(data.rooms[index]),
                ),
              ),
            if(data.rooms.isNotEmpty) ...[
              SliverPadding(
                padding:const EdgeInsets.fromLTRB(16,8,16,10),
                sliver:SliverToBoxAdapter(child:ReferenceSection(
                  title:UiText.get('reference_suggested_rooms'),
                  actionLabel:UiText.get('reference_show_all'),
                  onAction:_openDiscovery,
                )),
              ),
              SliverPadding(
                padding:const EdgeInsets.fromLTRB(15,0,15,15),
                sliver:SliverGrid.builder(
                  itemCount:math.min(data.rooms.length,4),
                  gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,
                    childAspectRatio:1.08,
                  ),
                  itemBuilder:(context,index)=>_roomCard(
                    data.rooms[(index+2)%data.rooms.length]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child:SizedBox(height:96)),
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

  Widget _roomCard(RoomSummary room) => ReferenceRoomThumbnail(
    title:room.title,
    coverUrl:_repository.coverUrl(room),
    onTap:_joining?null:()=>_enter(room),
  );

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
