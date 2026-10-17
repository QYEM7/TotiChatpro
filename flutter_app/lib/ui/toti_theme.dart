import 'package:flutter/material.dart';

/// Flutter rebuild palette. The retained field names keep existing connected
/// screens compatible while they are restyled one by one.
class TotiColors {
  static const ink = Color(0xFF282444);
  static const plum = Color(0xFF7162C3);
  static const lavender = Color(0xFFF0EAFF);
  static const pink = Color(0xFFED8CC6);
  static const sky = Color(0xFF94C8F1);
  static const muted = Color(0xFF817D9C);
  static const gold = Color(0xFFE6B36A);
  static const outline = Color(0xFFEAE6F4);
  static const background = Color(0xFFFCFAFF);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF8276D6), Color(0xFFBA85D8), Color(0xFFF0A2CD)],
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
      shadowColor: const Color(0x1A514F83),
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
