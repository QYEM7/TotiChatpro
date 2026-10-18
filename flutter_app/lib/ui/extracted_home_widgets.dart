import 'package:flutter/material.dart';

import '../models/room_models.dart';
import 'toti_theme.dart';

/// Visual details adapted from the owner's extracted TotiChat web UI.
/// All room content comes from the live repository, never from preview data.
class TotiExtractedHomeHeader extends StatelessWidget {
  const TotiExtractedHomeHeader({
    super.key,
    required this.explore,
    required this.onRefresh,
  });

  final bool explore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF25BE8E), Color(0xFF1DB184), Color(0xFF17976E)],
      ),
      boxShadow: [
        BoxShadow(color: Color(0x260E7058), blurRadius: 16, offset: Offset(0, 5)),
      ],
    ),
    child: Row(children: [
      const FalconMark(size: 48),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TotiChat', maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            )),
          Text(explore ? 'اكتشف الغرف الصوتية' : 'مساحتك للصوت والأصدقاء',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xE6FFFFFF), fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
        ],
      )),
      IconButton(
        key: const ValueKey('toti-refresh-rooms'),
        tooltip: 'Refresh live rooms',
        onPressed: onRefresh,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x30FFFFFF),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.refresh_rounded),
      ),
    ]),
  );
}

/// Two-column, square-cover layout from the extracted original UI.
/// Deliberately omits the old fake listener counts, rankings and host avatars.
class TotiExtractedRoomTile extends StatelessWidget {
  const TotiExtractedRoomTile({
    super.key,
    required this.room,
    required this.coverUrl,
    required this.onOpen,
  });

  final RoomInfo room;
  final String? coverUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'افتح غرفة ${room.title}',
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(fit: StackFit.expand, children: [
                const ColoredBox(color: Color(0xFFE4E6DE)),
                if (coverUrl != null && coverUrl!.startsWith('https://'))
                  Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.graphic_eq_rounded,
                        color: Color(0xFF17976E), size: 38)),
                  )
                else
                  const Center(child: Icon(Icons.graphic_eq_rounded,
                    color: Color(0xFF17976E), size: 38)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Colors.transparent,
                        Color(0x85000000)],
                      stops: [0, .56, 1],
                    ),
                  ),
                ),
                const Positioned(
                  right: 9, bottom: 9,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.graphic_eq_rounded,
                      size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text('صوتية', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                  ]),
                ),
              ]),
            )),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                room.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF293A35),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}
