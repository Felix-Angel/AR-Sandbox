/// Respuesta de GET /health.
class EstadoServidor {
  const EstadoServidor({required this.estado, required this.mensaje});

  final String estado;
  final String mensaje;

  bool get activo => estado == 'activo';

  factory EstadoServidor.fromJson(Map<String, dynamic> json) {
    final estado = json['estado'];
    final mensaje = json['mensaje'];
    if (estado is! String || mensaje is! String) {
      throw const FormatException(
        'La respuesta de /health debe incluir estado y mensaje de texto.',
      );
    }
    return EstadoServidor(estado: estado, mensaje: mensaje);
  }
}
