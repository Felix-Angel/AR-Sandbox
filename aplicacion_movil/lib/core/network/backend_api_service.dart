import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'backend_config.dart';
import 'models/configuracion_simulacion.dart';
import 'models/estado_servidor.dart';
import 'models/respuesta_simulacion.dart';

/// Cliente HTTP centralizado del backend AR Sandbox.
///
/// Está preparado para su uso futuro y no se conecta automáticamente desde la
/// interfaz. No requiere paquetes externos.
class BackendApiService {
  BackendApiService({Uri? baseUri, HttpClient? httpClient})
    : _baseUri = baseUri ?? Uri.parse(BackendConfig.baseUrl),
      _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _httpClient;

  /// Consulta el endpoint de disponibilidad sin afectar la simulación.
  Future<EstadoServidor> comprobarSalud() async {
    final json = await _request('GET', '/health');
    return EstadoServidor.fromJson(json);
  }

  Future<RespuestaSimulacion> registrarConfiguracion(
    SolicitudConfiguracion configuracion,
  ) async {
    final json = await _request(
      'POST',
      '/simulaciones/configuracion',
      body: configuracion.toJson(),
      expectedStatus: 201,
    );
    return RespuestaSimulacion.fromJson(json);
  }

  Future<RespuestaConfiguracion> obtenerConfiguracion() async {
    final json = await _request('GET', '/simulaciones/configuracion');
    return RespuestaConfiguracion.fromJson(json);
  }

  Future<RespuestaSimulacion> iniciarSimulacion() async {
    final json = await _request('POST', '/simulaciones/iniciar');
    return RespuestaSimulacion.fromJson(json);
  }

  Future<RespuestaSimulacion> detenerSimulacion() async {
    final json = await _request('POST', '/simulaciones/detener');
    return RespuestaSimulacion.fromJson(json);
  }

  Future<EstadoSimulacion> obtenerEstado() async {
    final json = await _request('GET', '/simulaciones/estado');
    return EstadoSimulacion.fromJson(json);
  }

  Future<List<SimulacionGuardada>> listarSimulacionesGuardadas() async {
    final uri = _baseUri.resolve('/simulaciones/guardadas');
    try {
      final request = await _httpClient
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final decoded = jsonDecode(await utf8.decoder.bind(response).join());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiException.fromResponse(response.statusCode, decoded);
      }
      if (decoded is! List) {
        throw const FormatException('La lista de simulaciones no es válida.');
      }
      return decoded
          .map(
            (item) => SimulacionGuardada.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on BackendApiException {
      rethrow;
    } on SocketException catch (error) {
      throw BackendApiException(
        message: 'No se pudo conectar con el backend: ${error.message}',
        cause: error,
      );
    } on FormatException catch (error) {
      throw BackendApiException(
        message: 'No se pudo interpretar la lista guardada: ${error.message}',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw BackendApiException(
        message: 'La consulta de simulaciones superó el tiempo de espera.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw BackendApiException(
        message: 'Error HTTP al consultar simulaciones: ${error.message}',
        cause: error,
      );
    }
  }

  Future<RespuestaSimulacion> guardarSimulacion(
    String nombre,
    SolicitudConfiguracion configuracion,
  ) async {
    final json = await _request(
      'POST',
      '/simulaciones/guardadas',
      body: {'nombre': nombre, ...configuracion.toJson()},
      expectedStatus: 201,
    );
    return RespuestaSimulacion.fromJson(json);
  }

  Future<RespuestaSimulacion> seleccionarSimulacion(int id) async {
    final json = await _request(
      'POST',
      '/simulaciones/guardadas/$id/seleccionar',
    );
    return RespuestaSimulacion.fromJson(json);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    int? expectedStatus,
  }) async {
    try {
      final uri = _baseUri.resolve(path);
      final request = await _httpClient
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      final dynamic decoded;
      try {
        decoded = jsonDecode(responseBody);
      } on FormatException {
        throw BackendApiException(
          statusCode: response.statusCode,
          message: 'El servidor devolvió una respuesta JSON inválida.',
          rawBody: responseBody,
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (expectedStatus != null && response.statusCode != expectedStatus)) {
        throw BackendApiException.fromResponse(response.statusCode, decoded);
      }
      if (decoded is! Map) {
        throw BackendApiException(
          statusCode: response.statusCode,
          message: 'La respuesta del servidor no es un objeto JSON.',
          rawBody: responseBody,
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on BackendApiException {
      rethrow;
    } on SocketException catch (error) {
      throw BackendApiException(
        message: 'No se pudo conectar con el backend: ${error.message}',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw BackendApiException(
        message: 'La petición al backend superó el tiempo de espera.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw BackendApiException(
        message: 'Error HTTP: ${error.message}',
        cause: error,
      );
    } on FormatException catch (error) {
      throw BackendApiException(
        message: 'No se pudo interpretar la respuesta del backend.',
        cause: error,
      );
    }
  }

  void close() => _httpClient.close();
}

/// Error de transporte, respuesta HTTP no exitosa o respuesta incompatible.
class BackendApiException implements Exception {
  const BackendApiException({
    required this.message,
    this.statusCode,
    this.details,
    this.rawBody,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final dynamic details;
  final String? rawBody;
  final Object? cause;

  factory BackendApiException.fromResponse(int statusCode, dynamic body) {
    final detail = body is Map ? body['detail'] : null;
    var message = 'El backend respondió con HTTP $statusCode.';
    if (detail is Map && detail['mensaje'] is String) {
      message = detail['mensaje'] as String;
    } else if (detail is List) {
      message = detail
          .whereType<Map>()
          .map((item) => item['msg'])
          .whereType<String>()
          .join(' ');
      if (message.isEmpty) {
        message = 'La solicitud no pasó la validación (HTTP 422).';
      }
    } else if (detail is String) {
      message = detail;
    }
    return BackendApiException(
      statusCode: statusCode,
      message: message,
      details: detail,
    );
  }

  @override
  String toString() => statusCode == null
      ? 'BackendApiException: $message'
      : 'BackendApiException (HTTP $statusCode): $message';
}
