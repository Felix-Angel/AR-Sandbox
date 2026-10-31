import 'package:flutter/material.dart';

import 'core/network/backend_api_service.dart';
import 'core/network/models/estado_servidor.dart';

/// Punto de entrada independiente para comprobar /health desde el emulador.
/// Ejecutar con: flutter run -t lib/diagnostico_conexion.dart
void main() {
  runApp(const DiagnosticoConexionApp());
}

class DiagnosticoConexionApp extends StatelessWidget {
  const DiagnosticoConexionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Diagnóstico AR Sandbox',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF315C45), useMaterial3: true),
    home: const PantallaDiagnosticoConexion(),
  );
}

class PantallaDiagnosticoConexion extends StatefulWidget {
  const PantallaDiagnosticoConexion({super.key});

  @override
  State<PantallaDiagnosticoConexion> createState() =>
      _PantallaDiagnosticoConexionState();
}

class _PantallaDiagnosticoConexionState
    extends State<PantallaDiagnosticoConexion> {
  final BackendApiService _api = BackendApiService();
  EstadoServidor? _respuesta;
  String? _error;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _comprobar());
  }

  Future<void> _comprobar() async {
    setState(() {
      _consultando = true;
      _respuesta = null;
      _error = null;
    });
    try {
      final respuesta = await _api.comprobarSalud();
      debugPrint(
        'GET /health recibido por Flutter: '
        'estado=${respuesta.estado}; mensaje=${respuesta.mensaje}',
      );
      if (!mounted) return;
      setState(() => _respuesta = respuesta);
    } on BackendApiException catch (error) {
      debugPrint('GET /health falló en Flutter: $error');
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prueba de conexión')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Petición real GET /health al backend FastAPI.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _consultando ? null : _comprobar,
              icon: const Icon(Icons.wifi_find),
              label: Text(_consultando ? 'Consultando…' : 'Probar conexión'),
            ),
            const SizedBox(height: 20),
            if (_respuesta case final respuesta?)
              _ResultadoSalud(respuesta: respuesta),
            if (_error case final error?)
              Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    ),
  );
}

class _ResultadoSalud extends StatelessWidget {
  const _ResultadoSalud({required this.respuesta});

  final EstadoServidor respuesta;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        respuesta.activo ? Icons.check_circle : Icons.error,
        color: respuesta.activo ? Colors.green : Colors.red,
      ),
      title: Text('HTTP correcto · estado: ${respuesta.estado}'),
      subtitle: Text(respuesta.mensaje),
    ),
  );
}
