import 'configuracion_simulacion.dart';

enum EstadoSimulacionApi {
  sinConfigurar('sin_configurar'),
  lista('lista'),
  enEjecucion('en_ejecucion'),
  detenida('detenida');

  const EstadoSimulacionApi(this.valorApi);

  final String valorApi;

  static EstadoSimulacionApi fromJson(String valor) =>
      EstadoSimulacionApi.values.firstWhere(
        (estado) => estado.valorApi == valor,
        orElse: () =>
            throw FormatException('Estado de simulación desconocido: $valor'),
      );
}

/// Respuesta común para configurar, iniciar y detener.
class RespuestaSimulacion {
  const RespuestaSimulacion({
    required this.mensaje,
    required this.estado,
    required this.configuracion,
  });

  final String mensaje;
  final EstadoSimulacionApi estado;
  final ConfiguracionSimulacion configuracion;

  factory RespuestaSimulacion.fromJson(Map<String, dynamic> json) {
    final mensaje = json['mensaje'];
    final estado = json['estado'];
    final configuracion = json['configuracion'];
    if (mensaje is! String || estado is! String || configuracion is! Map) {
      throw const FormatException(
        'La respuesta de simulación tiene campos inválidos.',
      );
    }
    return RespuestaSimulacion(
      mensaje: mensaje,
      estado: EstadoSimulacionApi.fromJson(estado),
      configuracion: ConfiguracionSimulacion.fromJson(
        Map<String, dynamic>.from(configuracion),
      ),
    );
  }
}

/// Respuesta de GET /simulaciones/estado; configuración puede ser null.
class EstadoSimulacion {
  const EstadoSimulacion({required this.estado, required this.configuracion});

  final EstadoSimulacionApi estado;
  final ConfiguracionSimulacion? configuracion;

  factory EstadoSimulacion.fromJson(Map<String, dynamic> json) {
    final estado = json['estado'];
    final configuracion = json['configuracion'];
    if (estado is! String || (configuracion != null && configuracion is! Map)) {
      throw const FormatException(
        'La respuesta de estado tiene campos inválidos.',
      );
    }
    return EstadoSimulacion(
      estado: EstadoSimulacionApi.fromJson(estado),
      configuracion: configuracion == null
          ? null
          : ConfiguracionSimulacion.fromJson(
              Map<String, dynamic>.from(configuracion as Map),
            ),
    );
  }
}

/// Respuesta de GET /simulaciones/configuracion.
class RespuestaConfiguracion {
  const RespuestaConfiguracion({
    required this.mensaje,
    required this.estado,
    required this.configuracion,
  });

  final String mensaje;
  final EstadoSimulacionApi estado;
  final ConfiguracionSimulacion configuracion;

  factory RespuestaConfiguracion.fromJson(Map<String, dynamic> json) {
    final respuesta = RespuestaSimulacion.fromJson(json);
    return RespuestaConfiguracion(
      mensaje: respuesta.mensaje,
      estado: respuesta.estado,
      configuracion: respuesta.configuracion,
    );
  }
}
