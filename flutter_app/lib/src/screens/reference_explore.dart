import 'package:flutter/material.dart';
import '../core/reference_visuals.dart';
import '../core/ui_text.dart';
import '../data/room_repository.dart';

/// Interactive version of approved board #03: compact room discovery rows.
/// Only current public rooms are shown; no fake VIP, listener counts or avatars.
class ReferenceExploreScreen extends StatefulWidget {
  const ReferenceExploreScreen({
    super.key,
    required this.repository,
    required this.onJoinRoom,
    this.onCreateRoom,
    this.initialQuery = '',
  });
  final RoomRepository repository;
  final ValueChanged<RoomSummary> onJoinRoom;
  final VoidCallback? onCreateRoom;
  final String initialQuery;

  @override
  State<ReferenceExploreScreen> createState() => _ReferenceExploreScreenState();
}

class _ReferenceExploreScreenState extends State<ReferenceExploreScreen> {
  late final TextEditingController _query;
  late Future<List<RoomSummary>> _rooms;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    _query.addListener(_updatedQuery);
    _rooms = widget.repository.publicRooms();
  }

  void _updatedQuery() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    final next = widget.repository.publicRooms();
    setState(() => _rooms = next);
    try {
      await next;
    } catch (_) {
      // The visible error state provides a retry.
    }
  }

  @override
  void dispose() {
    _query.removeListener(_updatedQuery);
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReferencePalette.canvas,
    appBar: AppBar(
      backgroundColor: ReferencePalette.canvas,
      elevation: 0,
      title: Text(UiText.get('home_discover'), style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: ReferencePalette.ink,
      )),
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 13),
        child: TextField(
          key: const Key('reference-search'),
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: UiText.get('discover_hint_reference'),
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search_rounded, color: ReferencePalette.deep),
            suffixIcon: _query.text.isEmpty ? null : IconButton(
              tooltip: UiText.get('clear'),
              onPressed: _query.clear,
              icon: const Icon(Icons.close_rounded),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(color: Color(0xFFDBEBE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: const BorderSide(color: Color(0xFFDBEBE2)),
            ),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        alignment: Alignment.centerRight,
        child: const ReferenceCategoryLabel(),
      ),
      Expanded(child: FutureBuilder<List<RoomSummary>>(
        future: _rooms,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: ReferencePalette.teal));
          }
          if (snapshot.hasError) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(UiText.get('rooms_load_failed')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _reload, child: Text(UiText.get('retry'))),
              ],
            ));
          }
          final search = _query.text.trim().toLowerCase();
          final rooms = snapshot.requireData.where((room) =>
            room.title.toLowerCase().contains(search)).toList(growable: false);
          if (rooms.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(children: [
                const SizedBox(height: 42),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ReferenceEmptyRooms(
                    title: search.isEmpty ? UiText.get('rooms_empty')
                      : UiText.get('discover_no_results_reference'),
                    subtitle: UiText.get('discover_no_rooms_help_reference'),
                    actionLabel: UiText.get('room_create'),
                    onAction: widget.onCreateRoom ?? _reload,
                  ),
                ),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
              itemCount: rooms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final room = rooms[index];
                final cover = widget.repository.coverUrl(room);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => widget.onJoinRoom(room),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 86, width: 88,
                            child: ReferenceRoomThumbnail(
                              title: '', coverUrl: cover, onTap: () =>
                                widget.onJoinRoom(room),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(room.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15,
                                color: ReferencePalette.ink,
                                fontWeight: FontWeight.w900)),
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: ReferencePalette.paleMint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(UiText.get('discover_public_reference'),
                                style: const TextStyle(fontSize: 11, color: ReferencePalette.deep)),
                            ),
                          ],
                        )),
                        const Icon(Icons.chevron_left, color: ReferencePalette.teal),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      )),
    ]),
  );
}

class ReferenceCategoryLabel extends StatelessWidget {
  const ReferenceCategoryLabel({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    const Icon(Icons.headphones_rounded, color: ReferencePalette.gold, size: 20),
    const SizedBox(width: 7),
    Text(UiText.get('rooms_section_reference'),
      style: const TextStyle(fontSize: 16,
        color: ReferencePalette.ink,fontWeight: FontWeight.w900)),
  ]);
}
