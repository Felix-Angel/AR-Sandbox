import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Paleta cálida inspirada en cafeterías: espresso, crema, canela y salvia.
/// Se mantienen los nombres públicos para no alterar los flujos existentes.
class AppTheme {
  // Colores de terreno: se conservan para que la selección siga coincidiendo
  // con los nombres y colores que entiende el backend y la simulación.
  static const Color verde = Color(0xFF315C45);
  static const Color terracota = Color(0xFFC66A4A);
  static const Color crema = Color(0xFFF6F7F2);
  static const Color tinta = Color(0xFF26352D);
  static const Color maiz = Color(0xFFE5B94B);
  static const Color turquesa = Color(0xFF3E9B98);
  static const Color bugambilia = Color(0xFFB64D73);
  static const Color cafe = Color(0xFF7A4A2F);
  static const Color gris = Color(0xFF7D8797);
  static const Color borde = Color(0xFFE7E4DA);

  // Nueva identidad visual de la app.
  static const Color espresso = Color(0xFF4A3024);
  static const Color canela = Color(0xFFB86E4B);
  static const Color fondo = Color(0xFFF5EFE6);
  static const Color texto = Color(0xFF30241E);
  static const Color caramelo = Color(0xFFD3A36F);
  static const Color salvia = Color(0xFF738A78);
  static const Color rosaArcilla = Color(0xFFA96F70);
  static const Color taupe = Color(0xFF82766E);
  static const Color arena = Color(0xFFE6DACE);
  static const Color superficie = Color(0xFFFFFCF8);

  static ThemeData get theme {
    final esquema = ColorScheme.fromSeed(
      seedColor: espresso,
      primary: espresso,
      secondary: canela,
      tertiary: salvia,
      surface: superficie,
      onSurface: texto,
      outline: arena,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: fondo,
      colorScheme: esquema,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: fondo,
        foregroundColor: texto,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: texto,
          fontSize: 22,
          letterSpacing: -.35,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: ThemeData.light().textTheme
          .apply(bodyColor: texto, displayColor: texto, fontFamily: 'Roboto')
          .copyWith(
            headlineSmall: const TextStyle(
              color: texto,
              fontSize: 25,
              height: 1.15,
              letterSpacing: -.6,
              fontWeight: FontWeight.w800,
            ),
            titleLarge: const TextStyle(
              color: texto,
              fontSize: 20,
              letterSpacing: -.25,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              color: texto,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: const TextStyle(
              color: taupe,
              fontSize: 14,
              height: 1.45,
            ),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: espresso,
          foregroundColor: superficie,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: const StadiumBorder(),
          elevation: 2,
          shadowColor: espresso.withValues(alpha: .18),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 2,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: texto.withValues(alpha: .07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: arena, width: .8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: espresso,
          foregroundColor: superficie,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: const StadiumBorder(),
          elevation: 2,
          shadowColor: espresso.withValues(alpha: .2),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          iconSize: 20,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: espresso,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: arena),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: canela,
          minimumSize: const Size(48, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: espresso,
          shape: const CircleBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fondo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: arena),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: arena),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: canela, width: 1.7),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: canela,
        thumbColor: canela,
        inactiveTrackColor: canela.withValues(alpha: .2),
        overlayColor: canela.withValues(alpha: .12),
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return superficie;
          return taupe;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return canela;
          return arena;
        }),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return canela;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: arena, width: 1.5),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(canela)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: canela,
        linearTrackColor: arena,
      ),
      dividerTheme: const DividerThemeData(color: arena, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: crema,
        selectedColor: caramelo.withValues(alpha: .3),
        side: const BorderSide(color: arena),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: texto, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: espresso,
        contentTextStyle: const TextStyle(color: superficie),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }
}
