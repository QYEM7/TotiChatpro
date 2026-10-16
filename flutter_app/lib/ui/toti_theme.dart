import 'package:flutter/material.dart';

class TotiColors {
  static const ink = Color(0xFF24213C);
  static const plum = Color(0xFF6654AC);
  static const lavender = Color(0xFFF1EAFB);
  static const gold = Color(0xFFF0B759);
  static const background = Color(0xFFF9F7FC);
}

ThemeData buildTotiTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TotiColors.plum,
    brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TotiColors.background,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: TotiColors.background,
      foregroundColor: TotiColors.ink,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TotiColors.plum,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TotiColors.plum, width: 1.3),
      ),
    ),
  );
}

class FalconMark extends StatelessWidget {
  const FalconMark({super.key, this.size = 58});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .25),
    child: Image.asset('assets/totichat_falcon.jpg',
      width: size, height: size, fit: BoxFit.cover),
  );
}
