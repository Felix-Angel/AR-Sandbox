import 'dart:ui' show Size;

import 'package:aplicacion_movil/main.dart';
import 'package:flutter/material.dart' show Icons, Slider;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('las tarjetas de terrenos caben en una pantalla estrecha', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ARSandboxApp());
    await tester.tap(find.byIcon(Icons.terrain_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Montañas'), findsOneWidget);
    final exception = tester.takeException();
    expect(exception, isNull, reason: exception.toString());
  });

  testWidgets('selección, configuración y resumen permanecen sincronizados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ARSandboxApp());

    await tester.tap(find.text('Terrenos'));
    await tester.pumpAndSettle();
    expect(find.text('Cumbres altas y pendientes pronunciadas.'), findsOneWidget);

    await tester.tap(find.text('Montañas'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar a configuración'), findsOneWidget);
    await tester.tap(find.text('Continuar a configuración'));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsNWidgets(2));
    expect(find.text('Montañas'), findsNWidgets(2));
    expect(find.textContaining('Verde bosque'), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Terracota'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionado: Terracota'), findsOneWidget);

    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Terracota ·'), findsOneWidget);
    expect(find.textContaining('Terracota · 50%'), findsNothing);

    await tester.tap(find.text('Terrenos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montañas'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar a configuración'), findsNothing);

    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();
    expect(find.text('Primero elige un terreno'), findsOneWidget);
  });

  testWidgets('inicia, conserva y detiene la simulación local', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ARSandboxApp());

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Sin configurar'), findsOneWidget);
    expect(find.text('Seleccionar terreno'), findsOneWidget);
    expect(find.text('Iniciar simulación'), findsNothing);

    await tester.ensureVisible(find.text('Seleccionar terreno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar terreno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montañas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar a configuración'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Lista para iniciar'), findsOneWidget);
    expect(find.text('Montañas'), findsOneWidget);
    expect(find.text('Verde bosque'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    await tester.tap(find.text('Iniciar simulación'));
    await tester.pumpAndSettle();
    expect(find.text('En ejecución'), findsOneWidget);
    expect(find.text('Detener simulación'), findsOneWidget);
    expect(find.text('Iniciar simulación'), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('En ejecución'), findsOneWidget);

    await tester.tap(find.text('Detener simulación'));
    await tester.pumpAndSettle();
    expect(find.text('Detenida'), findsOneWidget);
    expect(find.text('Reanudar simulación'), findsOneWidget);

    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Terracota'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Detenida'), findsOneWidget);
    expect(find.text('Terracota'), findsOneWidget);
  });
}
