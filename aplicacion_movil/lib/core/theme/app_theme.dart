import 'package:flutter/material.dart';

class AppTheme {
  static const Color verde = Color(0xFF315C45);
  static const Color terracota = Color(0xFFC66A4A);
  static const Color crema = Color(0xFFFAF7F0);
  static const Color tinta = Color(0xFF26352D);
  static const Color maiz = Color(0xFFE5B94B);
  static const Color turquesa = Color(0xFF3E9B98);
  static const Color bugambilia = Color(0xFFB64D73);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: crema,
      colorScheme: ColorScheme.fromSeed(
        seedColor: verde,
        primary: verde,
        secondary: terracota,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
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
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: maiz.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? verde : tinta,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}
