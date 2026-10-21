import 'package:flutter/material.dart';

import 'green_theme.dart';

/// Shared visual components for all TotiChat premium surfaces.
/// Content always comes from authorized repositories, not design mockups.
class PremiumSurface extends StatelessWidget {
  const PremiumSurface({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: GreenTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDFEEE6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C075A42),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class PremiumHeader extends StatelessWidget {
  const PremiumHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          height: 36,
          width: 4,
          decoration: BoxDecoration(
            color: GreenTheme.gold,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: GreenTheme.primaryDark,
                  )),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GreenTheme.ink,
                    )),
            ],
          ),
        ),
        ?trailing,
      ]);
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: GreenTheme.highlight,
                ),
                child: Icon(icon, size: 36, color: GreenTheme.primaryDark),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GreenTheme.ink,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF608376),
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      );
}

class PremiumPage extends StatelessWidget {
  const PremiumPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: GreenTheme.background,
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: body),
      );
}

class PremiumRow extends StatelessWidget {
  const PremiumRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => PremiumSurface(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          leading: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: GreenTheme.highlight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: GreenTheme.primaryDark),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: trailing ??
              (onTap == null
                  ? null
                  : const Icon(Icons.chevron_left, color: GreenTheme.primaryDark)),
          onTap: onTap,
          ),
        ),
      );
}

class PremiumGoldLabel extends StatelessWidget {
  const PremiumGoldLabel({super.key, required this.title, this.icon = Icons.stars_rounded});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9CB85)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: GreenTheme.gold),
          const SizedBox(width: 5),
          Text(title,
              style: const TextStyle(
                  color: GreenTheme.primaryDark, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}
