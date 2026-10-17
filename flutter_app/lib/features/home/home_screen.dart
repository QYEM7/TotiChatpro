import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/totichat_repository.dart';
import '../../data/totichat_services.dart';
import '../community/community_screen.dart';
import '../economy/real_gift_ticker.dart';
import '../../models/room_models.dart';
import '../../ui/toti_theme.dart';
import '../../ui/toti_visual_language.dart';
import '../../ui/toti_bottom_bar.dart';
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
  final GlobalKey<_RoomsDirectoryState> _homeDirectoryKey =
      GlobalKey<_RoomsDirectoryState>();
  RoomInfo? _activeRoom;
  bool _minimized = false;

  /// A single kept-alive room owns its LiveKit session while the user browses.
  /// Switching to a second room requires leaving the first to avoid ghost seats.
  void _openRoom(RoomInfo room) {
    if (_activeRoom != null && _activeRoom!.id != room.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Leave your current room before opening another.')));
      return;
    }
    setState(() {
      _activeRoom = room;
      _minimized = false;
    });
  }

  void _roomEnded() {
    if (!mounted) return;
    setState(() {
      _activeRoom = null;
      _minimized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _activeRoom;
    final pages = [
      RoomsDirectory(key: _homeDirectoryKey,
        repository: widget.repository, explore: false,
        onOpenRoom: _openRoom, activeRoomId: rooms?.id),
      RoomsDirectory(repository: widget.repository, explore: true,
        onOpenRoom: _openRoom, activeRoomId: rooms?.id),
      CommunityScreen(api: TotiChatServices(widget.repository.client)),
      AccountPage(repository: widget.repository, walletOnly: true,
        roomActive: rooms != null),
      AccountPage(repository: widget.repository, walletOnly: false,
        roomActive: rooms != null),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: rooms == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _activeRoom != null && _minimized) {
            setState(() => _minimized = false);
          }
        },
        child: Scaffold(
          body: SafeArea(child: TotiAtmosphere(child: Stack(children: [
            Positioned.fill(child: Column(children: [
              RealGiftTicker(client: widget.repository.client),
              Expanded(child: IndexedStack(index: _tab, children: pages)),
            ])),
            if (rooms != null)
              Positioned.fill(child: Offstage(
                offstage: _minimized,
                child: RoomScreen(
                  key: ValueKey('live-room-' + rooms.id),
                  repository: widget.repository,
                  room: rooms,
                  minimized: _minimized,
                  onExit: _roomEnded,
                  onMinimize: () => setState(() => _minimized = true),
                ),
              )),
            if (rooms != null && _minimized)
              Positioned(
                bottom: 8, left: 10, right: 10,
                child: Card(
                  elevation: 5,
                  child: ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(rooms.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: const Text('Room active in background'),
                    trailing: const Icon(Icons.open_in_full_rounded),
                    onTap: () => setState(() => _minimized = false),
                  ),
                ),
              ),
          ]))),
          bottomNavigationBar: rooms != null && !_minimized ? null :
            TotiBottomBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) =>
                setState(() => _tab = index),
              onCreateRoom: () {
                setState(() => _tab = 0);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _homeDirectoryKey.currentState?._createRoom();
                });
              },
            ),
        ),
      ),
    );
  }
}

class RoomsDirectory extends StatefulWidget {
  const RoomsDirectory({super.key, required this.repository, required this.explore,
    required this.onOpenRoom, this.activeRoomId});
  final TotiChatRepository repository;
  final bool explore;
  final ValueChanged<RoomInfo> onOpenRoom;
  final String? activeRoomId;

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
    if (widget.activeRoomId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Leave the active room before creating another.')));
      return;
    }
    final name = TextEditingController();
    final welcome = TextEditingController();
    var privateRoom = false;
    XFile? selected;
    final draft = await showDialog<({String title, String welcome, bool privateRoom, XFile cover})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('إنشاء غرفة جديدة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, maxLength: 60,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: 'اسم الغرفة *')),
              TextField(controller: welcome, maxLength: 500, maxLines: 3,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: 'رسالة الترحيب *')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery, maxWidth: 1600,
                      maxHeight: 1600, imageQuality: 88,
                    );
                    if (picked != null && dialogContext.mounted) {
                      update(() => selected = picked);
                    }
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('تعذر اختيار الصورة: $error')));
                    }
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(selected == null ? 'اختر صورة الغرفة *' : selected!.name),
              ),
              SwitchListTile(
                title: const Text('غرفة خاصة'),
                value: privateRoom,
                onChanged: (v) => update(() => privateRoom = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
            FilledButton(
              onPressed: selected == null ||
                  name.text.trim().length < 3 ||
                  welcome.text.trim().length < 2 ? null : () {
                    Navigator.pop(dialogContext, (
                      title: name.text, welcome: welcome.text,
                      privateRoom: privateRoom, cover: selected!,
                    ));
                  },
              child: const Text('إنشاء عبر الخادم'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    welcome.dispose();
    if (draft == null || !mounted) return;
    try {
      final room = await widget.repository.createRoomWithCover(
        title: draft.title,
        welcome: draft.welcome,
        image: draft.cover,
        isPrivate: draft.privateRoom,
      );
      if (!mounted) return;
      _reload();
      widget.onOpenRoom(room);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم تكتمل عملية الغرفة: $error'),
          duration: const Duration(seconds: 6)));
    }
  }

  Future<void> _joinPrivate() async {
    if (widget.activeRoomId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Leave the active room before joining another.')));
      return;
    }
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانضمام لغرفة خاصة'),
        content: TextField(controller: controller,
          decoration: const InputDecoration(labelText: 'رمز الدعوة من صاحب الغرفة'),
          maxLines: 2),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
            child:const Text('الانضمام')),
        ],
      ));
    controller.dispose();
    if(value==null||value.isEmpty||!mounted)return;
    try{
      final room=await widget.repository.acceptInvite(value);
      if(!mounted)return;
      widget.onOpenRoom(room);
    }catch(error){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('فشل قبول الدعوة: $error')));
    }
  }

  void _enter(RoomInfo room) => widget.onOpenRoom(room);

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
            if(widget.explore)IconButton(
              onPressed:_joinPrivate,
              tooltip:'دخول غرفة خاصة',
              icon:const Icon(Icons.lock_open_rounded)),
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
                          child: widget.repository.coverUrl(room) == null ?
                            const Icon(Icons.mic_rounded, color: TotiColors.plum, size: 29) :
                            ClipRRect(borderRadius: BorderRadius.circular(18),
                              child: Image.network(widget.repository.coverUrl(room)!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.mic_rounded, color: TotiColors.plum)))),
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
