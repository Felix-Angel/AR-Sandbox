/// Configuración central de conexión para el backend de AR Sandbox.
class BackendConfig {
  BackendConfig._();

  /// Dirección del host desde Android Emulator.
  ///
  /// Para un dispositivo físico, sustituir por la IP local del equipo que
  /// ejecuta FastAPI (por ejemplo, `http://192.168.1.20:8000`).
  static const String baseUrl = 'http://10.0.2.2:8000';
}
