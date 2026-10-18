import 'package:flutter/material.dart';

/// Premium decorative language inspired by the extracted TotiChat UI.
/// These widgets never synthesize account, wallet, room, or event data.
abstract final class TotiRoyalPalette {
  static const emerald = Color(0xFF126C59);
  static const deepEmerald = Color(0xFF0A4036);
  static const gold = Color(0xFFB8893A);
  static const parchment = Color(0xFFFFFCF6);
  static const mutedGold = Color(0xFFE7CE98);
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5C67E), Color(0xFFB68530), Color(0xFFF3DFAE)],
  );
}

class TotiRoyalPanel extends StatelessWidget {
  const TotiRoyalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFFFDF9), Color(0xFFFFF8EA), Color(0xFFF6E9CE)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TotiRoyalPalette.mutedGold, width: 1.2),
      boxShadow: const [
        BoxShadow(color: Color(0x1CB8893A), blurRadius: 19,
          offset: Offset(0, 7)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        const Positioned(
          top: -38,
          left: -45,
          child: IgnorePointer(child: Icon(
            Icons.auto_awesome, size: 130, color: Color(0x16B8893A))),
        ),
        Padding(padding: padding, child: child),
      ]),
    ),
  );
}

class TotiRoyalSectionHeading extends StatelessWidget {
  const TotiRoyalSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
  });
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          gradient: TotiRoyalPalette.goldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x26B8893A), blurRadius: 9),
          ],
        ),
        child: Icon(icon, color: TotiRoyalPalette.deepEmerald, size: 23),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: TotiRoyalPalette.deepEmerald,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          )),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(
            color: TotiRoyalPalette.emerald, fontSize: 11,
          )),
        ],
      )),
    ]),
  );
}

class TotiRoyalTopBanner extends StatelessWidget {
  const TotiRoyalTopBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.workspace_premium_rounded,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          TotiRoyalPalette.deepEmerald,
          TotiRoyalPalette.emerald,
          Color(0xFF22755D),
        ],
      ),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: TotiRoyalPalette.gold, width: 1.3),
    ),
    child: Row(children: [
      Container(
        width: 55, height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x24FFFFFF),
          border: Border.all(color: TotiRoyalPalette.mutedGold, width: 1.5),
        ),
        child: Icon(icon, color: TotiRoyalPalette.mutedGold, size: 31),
      ),
      const SizedBox(width: 15),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: Colors.white)),
          const SizedBox(height: 5),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12, color: Color(0xFFF8E8C9))),
        ],
      )),
    ]),
  );
}
