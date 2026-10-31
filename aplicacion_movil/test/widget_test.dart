import 'dart:ui' show Size;

import 'package:aplicacion_movil/core/network/backend_api_service.dart';
import 'package:aplicacion_movil/core/network/models/configuracion_simulacion.dart';
import 'package:aplicacion_movil/core/network/models/respuesta_simulacion.dart'
    as api;
import 'package:aplicacion_movil/main.dart';
import 'package:flutter/material.dart'
    show FilledButton, Icons, Scrollable, Slider;
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
    expect(
      find.text('Cumbres altas y pendientes pronunciadas.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Montañas'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar a configuración'), findsOneWidget);
    await tester.tap(find.text('Continuar a configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Personaliza tu terreno'), findsOneWidget);

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
    final backend = _FakeBackendApiService();
    await tester.pumpWidget(ARSandboxApp(backendApiService: backend));

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
    final configuracionScrollable = find.ancestor(
      of: find.text('Personaliza tu terreno'),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Guardar configuración'),
      250,
      scrollable: configuracionScrollable,
    );
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Lista para iniciar'), findsOneWidget);
    expect(find.text('Montañas'), findsOneWidget);
    expect(find.text('Verde bosque'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    final simulacionScrollable = find.ancestor(
      of: find.text('Configuración actual'),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      200,
      scrollable: simulacionScrollable,
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(backend.estado, api.EstadoSimulacionApi.enEjecucion);
    await tester.scrollUntilVisible(
      find.text('Estado confirmado por FastAPI'),
      -200,
      scrollable: simulacionScrollable,
    );
    expect(find.text('En ejecuci\u00f3n'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      200,
      scrollable: simulacionScrollable,
    );

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Estado confirmado por FastAPI'),
      -200,
      scrollable: simulacionScrollable,
    );
    expect(find.text('En ejecuci\u00f3n'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      200,
      scrollable: simulacionScrollable,
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(backend.estado, api.EstadoSimulacionApi.detenida);
    await tester.scrollUntilVisible(
      find.text('Estado confirmado por FastAPI'),
      -200,
      scrollable: simulacionScrollable,
    );
    expect(find.text('Detenida'), findsOneWidget);

  });
}

class _FakeBackendApiService extends BackendApiService {
  _FakeBackendApiService() : super(baseUri: Uri.parse('http://localhost'));

  ConfiguracionSimulacion? configuracion;
  api.EstadoSimulacionApi estado = api.EstadoSimulacionApi.sinConfigurar;

  @override
  Future<api.EstadoSimulacion> obtenerEstado() async =>
      api.EstadoSimulacion(estado: estado, configuracion: configuracion);

  @override
  Future<api.RespuestaSimulacion> registrarConfiguracion(
    SolicitudConfiguracion solicitud,
  ) async {
    configuracion = ConfiguracionSimulacion.fromJson(solicitud.toJson());
    if (estado != api.EstadoSimulacionApi.enEjecucion) {
      estado = api.EstadoSimulacionApi.lista;
    }
    return _respuesta('Configuración recibida correctamente');
  }

  @override
  Future<api.RespuestaSimulacion> iniciarSimulacion() async {
    if (configuracion == null ||
        estado == api.EstadoSimulacionApi.enEjecucion) {
      throw BackendApiException.fromResponse(400, {
        'detail': {
          'mensaje': configuracion == null
              ? 'Selecciona y registra un terreno antes de iniciar'
              : 'Ya hay una simulación en ejecución',
          'estado': estado.valorApi,
        },
      });
    }
    estado = api.EstadoSimulacionApi.enEjecucion;
    return _respuesta('Simulación iniciada correctamente');
  }

  @override
  Future<api.RespuestaSimulacion> detenerSimulacion() async {
    if (estado != api.EstadoSimulacionApi.enEjecucion ||
        configuracion == null) {
      throw BackendApiException.fromResponse(400, {
        'detail': {
          'mensaje': 'No hay una simulación activa para detener',
          'estado': estado.valorApi,
        },
      });
    }
    estado = api.EstadoSimulacionApi.detenida;
    return _respuesta('Simulación detenida correctamente');
  }

  api.RespuestaSimulacion _respuesta(String mensaje) => api.RespuestaSimulacion(
    mensaje: mensaje,
    estado: estado,
    configuracion: configuracion!,
  );
}
