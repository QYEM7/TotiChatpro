import 'package:flutter/material.dart';

/// Ten distinct VIP palettes. A tier is never displayed unless it is
/// returned by the verified server-backed entitlement.
abstract final class TotiVipTierStyle {
  static const List<Color> _colors = [
    Color(0xFF7681B3), // I
    Color(0xFF53A5B4), // II
    Color(0xFF4C996D), // III
    Color(0xFFA59B45), // IV
    Color(0xFFD08042), // V
    Color(0xFFAB6BA9), // VI
    Color(0xFFBB5765), // VII
    Color(0xFF8B6ECA), // VIII
    Color(0xFFCF9A3B), // IX
    Color(0xFFF2D385), // X
  ];

  static Color colorFor(int tier) =>
      tier >= 1 && tier <= _colors.length
          ? _colors[tier - 1]
          : const Color(0xFF198269);

  static LinearGradient gradientFor(int tier) {
    final center = colorFor(tier);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFF8E8BC), center, const Color(0xFFFFF3D4)],
      stops: const [0, .53, 1],
    );
  }
}
