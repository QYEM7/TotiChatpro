import 'package:flutter/material.dart';

/// Shared light-green identity for the *current* Flutter client.
///
/// Keep the deprecated purple/cosmic surfaces out of the login-to-home path.
/// This is presentation only: no local mock profiles, room data or balances.
abstract final class GreenTheme {
  static const background = Color(0xFFF4FBF7);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF168A61);
  static const primaryDark = Color(0xFF075A42);
  static const mint = Color(0xFF26C096);
  static const highlight = Color(0xFFE2F8ED);
  static const gold = Color(0xFFB58128);
  static const ink = Color(0xFF183D32);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primaryDark,
        centerTitle: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: highlight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primaryDark
                : ink,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
