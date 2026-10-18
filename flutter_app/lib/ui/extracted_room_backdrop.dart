import 'package:flutter/material.dart';

/// Artwork only: no fake users, events, balances or room state.
/// The soft veil preserves legible real seat and message overlays.
class TotiRoomBackdrop extends StatelessWidget {
  const TotiRoomBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(child: Opacity(
        opacity: .22,
        child: Image.asset(
          'assets/room_royal_background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: Color(0xFFFFFCF8)),
        ),
      )),
      const Positioned.fill(child: IgnorePointer(
        child: ColoredBox(color: Color(0x78FFFDF7)),
      )),
      Positioned.fill(child: child),
    ],
  );
}
