import 'package:flutter/material.dart';

import '../../models/room_models.dart';
import '../../models/room_seat_decoration.dart';
import '../../ui/toti_theme.dart';

/// Premium avatar seat without invented cosmetics. VIP, frame, gift count and
/// mic badges are displayed only when confirmed by the Staging server.
class RoomSeatVisual extends StatelessWidget {
  const RoomSeatVisual({
    super.key,
    required this.member,
    required this.isOwner,
    this.decoration,
  });
  final RoomMember? member;
  final bool isOwner;
  final RoomSeatDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final occupied = member != null;
    final vip = decoration?.vipTier ?? 0;
    final frameName = decoration?.frameName?.trim();
    final hasFrame = frameName != null && frameName.isNotEmpty;
    final frameIcon = decoration?.frameIcon?.trim();
    final shortIcon = frameIcon != null && frameIcon.isNotEmpty &&
        frameIcon.length <= 8 && !frameIcon.contains('://');
    final avatar = member?.avatarUrl;

    final accent = vip > 0 || hasFrame ? TotiColors.gold : TotiColors.plum;
    return LayoutBuilder(builder: (context, size) {
      final diameter = (size.maxWidth < size.maxHeight
          ? size.maxWidth : size.maxHeight).clamp(1.0, 80.0).toDouble();
      return Center(child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: Container(
            padding: EdgeInsets.all(occupied ? 3 : 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: occupied ? const LinearGradient(
                begin: Alignment.topRight, end: Alignment.bottomLeft,
                colors: [Color(0xFFF6B7D9), Color(0xFF8E7DE2),
                  Color(0xFFE8C690)],
              ) : const LinearGradient(
                colors: [Color(0xFFE8E0FF), Color(0xFFFCE9F3)],
              ),
              border: Border.all(
                color: vip > 0 || hasFrame ? accent : TotiColors.outline,
                width: vip > 0 || hasFrame ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x175E508F),
                  blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: ClipOval(child: ColoredBox(
              color: occupied ? const Color(0xFFF0E6FA) : Colors.white,
              child: occupied && avatar?.startsWith('https://') == true
                ? Image.network(avatar!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_rounded, color: TotiColors.plum))
                : Icon(occupied ? Icons.person_rounded : Icons.add_rounded,
                    size: occupied ? 26 : 24,
                    color: TotiColors.plum),
            )),
          )),
          if (vip > 0) Positioned(
            left: -4, top: -5,
            child: _SeatLabel(
              text: 'VIP $vip', background: const Color(0xFF56418B)),
          ),
          if (occupied && isOwner) const Positioned(
            right: -2, top: -6,
            child: Icon(Icons.workspace_premium_rounded,
              size: 17, color: TotiColors.gold),
          ),
          if (hasFrame) Positioned(
            right: -4, top: isOwner ? 14 : -5,
            child: Tooltip(
              message: 'Equipped frame: $frameName',
              child: shortIcon
                ? Text(frameIcon,
                    style: const TextStyle(fontSize: 15))
                : const Icon(Icons.auto_awesome_rounded,
                    color: TotiColors.gold, size: 16),
            ),
          ),
          if (decoration != null) Positioned(
            bottom: -6, left: -4,
            child: _SeatLabel(
              text: '🎁 ${decoration!.receivedGifts}',
              background: const Color(0xFFEDE6FA),
              foreground: TotiColors.ink,
            ),
          ),
          if (member?.isMuted == true) Positioned(
            right: -4, bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.mic_off_rounded,
                size: 13, color: TotiColors.plum),
            ),
          ),
        ]),
      ));
    });
  }
}

class _SeatLabel extends StatelessWidget {
  const _SeatLabel({
    required this.text,
    required this.background,
    this.foreground = Colors.white,
  });
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white),
    ),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: foreground,
        fontSize: 8, fontWeight: FontWeight.w800)),
  );
}
