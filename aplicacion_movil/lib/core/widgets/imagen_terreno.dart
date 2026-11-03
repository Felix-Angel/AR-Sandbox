import 'package:flutter/material.dart';

class ImagenTerreno extends StatelessWidget {
  const ImagenTerreno({
    super.key,
    required this.terreno,
    this.fit = BoxFit.cover,
    this.escala = 1,
  });

  final String? terreno;
  final BoxFit fit;
  final double escala;

  static const _imagenes = <String, String>{
    'montanas': 'assets/images/montanas.jpg',
    'valles': 'assets/images/valles.jpg',
    'volcanes': 'assets/images/volcanes.jpg',
    'llanuras': 'assets/images/llanuras.jpg',
  };

  static String rutaPara(String? terreno) {
    final nombreNormalizado = terreno?.toLowerCase().replaceAll('\u00f1', 'n');
    return _imagenes[nombreNormalizado] ?? _imagenes['valles']!;
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 520),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1).animate(animation),
        child: child,
      ),
    ),
    child: SizedBox.expand(
      key: ValueKey(rutaPara(terreno)),
      child: AnimatedScale(
        scale: escala,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: Image.asset(
          rutaPara(terreno),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: Color(0xFF4A3024),
            child: Center(
              child: Icon(
                Icons.landscape_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
