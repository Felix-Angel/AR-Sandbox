import 'package:aplicacion_movil/core/network/backend_api_service.dart';
import 'package:aplicacion_movil/core/network/models/configuracion_simulacion.dart';
import 'package:aplicacion_movil/core/network/models/respuesta_simulacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contrato de configuración', () {
    test('convierte nombre visible al identificador exacto del backend', () {
      final solicitud = SolicitudConfiguracion.desdeInterfaz(
        terreno: 'Montañas',
        color: 'Maíz',
        altura: 75,
      );

      expect(solicitud.toJson(), {
        'terreno': 'montanas',
        'color': 'Maíz',
        'altura': 75.0,
      });
      expect(TerrenosApi.aNombre('montanas'), 'Montañas');
    });

    test('lee configuración JSON con altura numérica', () {
      final configuracion = ConfiguracionSimulacion.fromJson({
        'terreno': 'volcanes',
        'color': 'Café',
        'altura': 42,
      });

      expect(configuracion.nombreTerreno, 'Volcanes');
      expect(configuracion.color, 'Café');
      expect(configuracion.altura, 42.0);
    });

    test('lee estado sin configuración y respuesta de configuración', () {
      final estado = EstadoSimulacion.fromJson({
        'estado': 'sin_configurar',
        'configuracion': null,
      });
      final respuesta = RespuestaConfiguracion.fromJson({
        'mensaje': 'Configuración actual',
        'estado': 'lista',
        'configuracion': {
          'terreno': 'llanuras',
          'color': 'Verde bosque',
          'altura': 75.0,
        },
      });

      expect(estado.estado, EstadoSimulacionApi.sinConfigurar);
      expect(estado.configuracion, isNull);
      expect(respuesta.estado, EstadoSimulacionApi.lista);
      expect(respuesta.configuracion.nombreTerreno, 'Llanuras');
    });

    test('rechaza valores fuera del contrato', () {
      expect(() => TerrenosApi.aId('Desierto'), throwsArgumentError);
      expect(() => ColoresApi.validar('Azul'), throwsArgumentError);
      expect(
        () => SolicitudConfiguracion.desdeInterfaz(
          terreno: 'Valles',
          color: 'Crema',
          altura: 101,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Errores HTTP del backend', () {
    test('conserva el mensaje de errores de negocio 400 y 404', () {
      final error400 = BackendApiException.fromResponse(400, {
        'detail': {'mensaje': 'Ya hay una simulación en ejecución'},
      });
      final error404 = BackendApiException.fromResponse(404, {
        'detail': {'mensaje': 'No existe configuración'},
      });

      expect(error400.statusCode, 400);
      expect(error400.message, 'Ya hay una simulación en ejecución');
      expect(error404.statusCode, 404);
      expect(error404.message, 'No existe configuración');
    });

    test('extrae el detalle de validación 422 de FastAPI', () {
      final error = BackendApiException.fromResponse(422, {
        'detail': [
          {'msg': 'Input should be less than or equal to 100'},
        ],
      });

      expect(error.statusCode, 422);
      expect(error.message, 'Input should be less than or equal to 100');
    });
  });
}
