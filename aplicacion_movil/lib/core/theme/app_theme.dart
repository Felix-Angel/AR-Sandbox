import 'package:flutter/material.dart';

class AppTheme {
  static const Color verde = Color(0xFF315C45);
  static const Color terracota = Color(0xFFC66A4A);
  static const Color crema = Color(0xFFFAF7F0);
  static const Color tinta = Color(0xFF26352D);
  static const Color maiz = Color(0xFFE5B94B);
  static const Color turquesa = Color(0xFF3E9B98);
  static const Color bugambilia = Color(0xFFB64D73);
  static const Color cafe = Color(0xFF7A4A2F);
  static const Color gris = Color(0xFF7D8797);
  static const Color borde = Color(0xFFE7E4DA);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: crema,
      colorScheme: ColorScheme.fromSeed(
        seedColor: verde,
        primary: verde,
        secondary: terracota,
        tertiary: turquesa,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: crema,
        foregroundColor: tinta,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: tinta,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borde),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: verde,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: verde.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? verde
                : tinta.withValues(alpha: .68),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
