import 'package:flutter/material.dart';

import '../core/green_theme.dart';
import '../core/premium_ui.dart';
import '../core/ui_text.dart';
import '../data/room_repository.dart';

/// Searches only authoritative public rooms; no fabricated rooms or viewers.
class ExploreView extends StatefulWidget {
  const ExploreView({
    super.key,
    required this.repository,
    required this.onRoomSelected,
    this.onCreateRoom,
  });

  final RoomRepository repository;
  final ValueChanged<RoomSummary> onRoomSelected;
  final VoidCallback? onCreateRoom;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final _search = TextEditingController();
  late Future<List<RoomSummary>> _rooms = widget.repository.publicRooms();

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = widget.repository.publicRooms();
    setState(() => _rooms = next);
    try {
      await next;
    } catch (_) {
      // The error state offers explicit retry.
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumHeader(title: UiText.get('discover_title'), subtitle: UiText.get('discover_subtitle')),
              const SizedBox(height: 16),
              TextField(
                key: const Key('premium-discover-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: GreenTheme.surface,
                  prefixIcon: const Icon(Icons.search, color: GreenTheme.primaryDark),
                  hintText: UiText.get('discover_hint'),
                  suffixIcon: _search.text.isEmpty ? null : IconButton(
                    tooltip: UiText.get('clear'),
                    icon: const Icon(Icons.close),
                    onPressed: _search.clear,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFDFEEE6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFDFEEE6)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RoomSummary>>(
            future: _rooms,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return PremiumEmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: UiText.get('rooms_load_failed'),
                  action: OutlinedButton(onPressed: _refresh, child: Text(UiText.get('retry'))),
                );
              }
              final query = _search.text.trim().toLowerCase();
              final rooms = snapshot.requireData.where(
                (room) => room.title.toLowerCase().contains(query),
              ).toList(growable: false);
              return RefreshIndicator(
                onRefresh: _refresh,
                child: rooms.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * .52,
                        child: PremiumEmptyState(
                          icon: Icons.headphones_outlined,
                          title: query.isEmpty ? UiText.get('rooms_empty') : UiText.get('discover_no_match'),
                          subtitle: UiText.get('discover_empty_help'),
                          action: widget.onCreateRoom == null ? null : FilledButton.icon(
                            onPressed: widget.onCreateRoom,
                            icon: const Icon(Icons.add_circle_outline),
                            label: Text(UiText.get('room_create')),
                          ),
                        ),
                      ),
                    ])
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: rooms.length,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .86,
                      ),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final cover = widget.repository.coverUrl(room);
                        return InkWell(
                          onTap: () => widget.onRoomSelected(room),
                          borderRadius: BorderRadius.circular(22),
                          child: PremiumSurface(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: cover == null
                                      ? const ColoredBox(
                                          color: GreenTheme.highlight,
                                          child: Icon(Icons.headphones_rounded, color: GreenTheme.primaryDark, size: 44),
                                        )
                                      : Image.network(
                                          cover,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const ColoredBox(
                                            color: GreenTheme.highlight,
                                            child: Icon(Icons.headphones_rounded, color: GreenTheme.primaryDark),
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: GreenTheme.primaryDark, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 5),
                                Row(children: [
                                  const Icon(Icons.lock_open_rounded, size: 14, color: GreenTheme.primary),
                                  const SizedBox(width: 5),
                                  Text(UiText.get('discover_public_room'),
                                      style: const TextStyle(fontSize: 11, color: GreenTheme.ink)),
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              );
            },
          ),
        ),
      ]);
