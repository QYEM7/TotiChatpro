import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// A real, persistent room playlist. This screen does not imply playback:
/// there is no verified synchronized playback transport in Staging yet.
class RoomMusicQueueScreen extends StatefulWidget {
  const RoomMusicQueueScreen({
    super.key, required this.api, required this.roomId,
  });
  final TotiChatServices api;
  final String roomId;

  @override
  State<RoomMusicQueueScreen> createState() => _RoomMusicQueueScreenState();
}

class _RoomMusicQueueScreenState extends State<RoomMusicQueueScreen> {
  late Future<List<Map<String, dynamic>>> _queue;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() =>
    _queue = widget.api.musicQueue(widget.roomId));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Room music playlist'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ServerPanel<List<Map<String, dynamic>>>(
        future: _queue,
        retry: _refresh,
        builder: (context, rows) => RefreshIndicator(
          onRefresh: () async {
            _refresh();
            await _queue;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Server playlist',
                style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Songs listed here are real saved queue entries. '
                    'Synchronized audio, licensing, playback controls and '
                    'join-mid-track timing are not enabled yet.'),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const NoRecords('No music is saved in this room.'),
              ...rows.map((item) => recordCard(context,
                icon: Icons.library_music_outlined,
                title: item['title']?.toString() ?? 'Untitled recording',
                description: [
                  if (item['artist']?.toString().isNotEmpty == true)
                    'Artist: ${item['artist']}',
                  'Queued: ${item['created_at'] ?? 'Unavailable'}',
                ].join('\n'),
              )),
            ],
          ),
        ),
      ),
    ),
  );
}
