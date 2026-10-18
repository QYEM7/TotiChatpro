import 'package:flutter/material.dart';

import 'toti_theme.dart';
import 'extracted_premium_panels.dart';

/// Shared light visual language for the new Flutter-only TotiChat screens.
/// Decorative shapes never pretend to be banners, users or live activity.
class TotiAtmosphere extends StatelessWidget {
  const TotiAtmosphere({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: TotiColors.background)),
      const Positioned(top: -120, left: -130,
        child: _Glow(diameter: 330, color: Color(0x221B9977))),
      const Positioned(top: 105, right: -115,
        child: _Glow(diameter: 275, color: Color(0x30E9CA81))),
      const Positioned(bottom: -130, left: -105,
        child: _Glow(diameter: 310, color: Color(0x2715B590))),
      Positioned.fill(child: child),
    ]),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.diameter, required this.color});
  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: diameter, height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

class TotiGradientPanel extends StatelessWidget {
  const TotiGradientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 26,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: TotiColors.heroGradient,
      boxShadow: const [
        BoxShadow(color: Color(0x226253B0), blurRadius: 24, offset: Offset(0, 12)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        const Positioned(left: -35, top: -50,
          child: _Glow(diameter: 195, color: Color(0x55FFFFFF))),
        const Positioned(right: -20, bottom: -50,
          child: _Glow(diameter: 165, color: Color(0x55FFE6FB))),
        Padding(padding: padding, child: child),
      ]),
    ),
  );
}

class TotiGlassCard extends StatelessWidget {
  const TotiGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFCF7)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TotiRoyalPalette.mutedGold.withValues(alpha: .65)),
      boxShadow: const [
        BoxShadow(color: Color(0x108A6A42), blurRadius: 21, offset: Offset(0, 7)),
      ],
    ),
    child: child,
  );
}
