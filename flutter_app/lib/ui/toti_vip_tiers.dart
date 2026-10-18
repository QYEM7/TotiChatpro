import 'package:flutter/material.dart';
import 'toti_theme.dart';

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
          : TotiColors.plum;

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


/// A visual catalogue, NOT a list of owned or activated VIP entitlements.
class TotiVipTierGallery extends StatelessWidget {
  const TotiVipTierGallery({super.key, required this.currentTier});

  final int currentTier;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('تصاميم مستويات VIP العشرة',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
          color: TotiColors.ink)),
      const SizedBox(height: 4),
      const Text('معرض الشارات فقط، العضوية المفعّلة تحددها بيانات الخادم.',
        style: TextStyle(fontSize: 11, color: TotiColors.muted)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(10, (index) {
            final tier = index + 1;
            final selected = currentTier == tier;
            final tint = TotiVipTierStyle.colorFor(tier);
            return Container(
              width: itemWidth,
              height: 88,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [const Color(0xFFFFFAED), tint.withValues(alpha: .14)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: tint,
                  width: selected ? 2.6 : 1.3),
              ),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: TotiVipTierStyle.gradientFor(tier),
                    border: Border.all(color: tint, width: 2),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 28),
                ),
                const SizedBox(width: 7),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VIP $tier', maxLines: 1,
                      style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: TotiColors.ink)),
                    Text(selected ? 'مفعّل' : 'معاينة',
                      style: TextStyle(fontSize: 10,
                        fontWeight: selected
                          ? FontWeight.w900 : FontWeight.w500,
                        color: selected ? tint : TotiColors.muted)),
                  ],
                )),
              ]),
            );
          }),
        );
      }),
    ],
  );
}
