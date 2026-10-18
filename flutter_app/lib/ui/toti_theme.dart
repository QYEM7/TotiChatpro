import 'package:flutter/material.dart';

/// Flutter rebuild palette. The retained field names keep existing connected
/// screens compatible while they are restyled one by one.
class TotiColors {
  static const ink = Color(0xFF18352D);
  static const plum = Color(0xFF16866A);
  static const lavender = Color(0xFFE6F3EC);
  static const pink = Color(0xFFE6B47B);
  static const sky = Color(0xFF93C2C0);
  static const muted = Color(0xFF70847C);
  static const gold = Color(0xFFB8893A);
  static const outline = Color(0xFFE9DEC9);
  static const background = Color(0xFFFFFCF8);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0C594C), Color(0xFF1B9977), Color(0xFFCCA35C)],
    stops: [0.0, .56, 1.0],
  );
}

ThemeData buildTotiTheme() {
  const scheme = ColorScheme.light(
    primary: TotiColors.plum,
    onPrimary: Colors.white,
    secondary: TotiColors.pink,
    surface: Colors.white,
    onSurface: TotiColors.ink,
    outline: TotiColors.outline,
    error: Color(0xFFB93B6B),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TotiColors.background,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: TotiColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shadowColor: const Color(0x1A7E6533),
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TotiColors.outline),
        borderRadius: BorderRadius.circular(22),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TotiColors.plum,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .92),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 16,
      ),
      hintStyle: const TextStyle(color: TotiColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TotiColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TotiColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: TotiColors.plum, width: 1.4),
      ),
    ),
  );
}

class FalconMark extends StatelessWidget {
  const FalconMark({super.key, this.size = 58});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    padding: EdgeInsets.all(size * .055),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * .28),
      border: Border.all(color: const Color(0x88FFFFFF), width: 1.5),
      boxShadow: const [
        BoxShadow(color: Color(0x2B4D418C), blurRadius: 21, offset: Offset(0, 8)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .23),
      child: Image.asset('assets/totichat_falcon.jpg',
        width: size, height: size, fit: BoxFit.cover),
    ),
  );
}
