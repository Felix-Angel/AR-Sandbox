import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/backend_config.dart';
import '../../../core/theme/app_theme.dart';

class PantallaSistema extends StatefulWidget {
  const PantallaSistema({super.key, required this.api, required this.activa});

  final BackendApiService api;
  final bool activa;

  @override
  State<PantallaSistema> createState() => _PantallaSistemaState();
}

class _PantallaSistemaState extends State<PantallaSistema> {
  Timer? _timer;
  Map<String, dynamic> _sensor = const {};
  Map<String, dynamic> _calibracion = _calibracionInicial;
  bool _proyeccionActiva = false;
  bool _consultando = false;
  bool _guardando = false;
  bool _capturaOcupada = false;
  bool _calibracionConsultada = false;
  String? _error;

  static const Map<String, dynamic> _calibracionInicial = {
    'superficie': 'caja',
    'orientacion': 'horizontal',
    'ancho': 21.6,
    'alto': 21.6,
    'desplazamientoX': 0.0,
    'desplazamientoY': 0.0,
    'escala': 1.0,
    'rotacion': 0.0,
    'centroSensorX': 50.0,
    'centroSensorY': 50.0,
    'anchoSensor': 100.0,
    'altoSensor': 100.0,
    'mostrarCuadricula': false,
    'mostrarMalla': false,
  };

  bool get _capturaSolicitada => _sensor['captura_solicitada'] != false;
  bool get _sensorConectado => _sensor['conectado'] == true;
  bool get _sensorCapturando => _sensor['capturando'] == true;

  @override
  void initState() {
    super.initState();
    if (widget.activa) _iniciarActualizacion();
  }

  @override
  void didUpdateWidget(covariant PantallaSistema oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa == oldWidget.activa) return;
    if (widget.activa) {
      _iniciarActualizacion();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _iniciarActualizacion() {
    unawaited(_actualizar());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_actualizar());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _actualizar() async {
    if (_consultando) return;
    _consultando = true;
    try {
      final sensor = await widget.api.obtenerEstadoSensor();
      final proyeccion = await widget.api.obtenerEstadoProyeccion();
      final calibracion = _calibracionConsultada
          ? _calibracion
          : await widget.api.obtenerCalibracion();
      if (!mounted) return;
      setState(() {
        _sensor = sensor;
        _proyeccionActiva = proyeccion;
        _calibracion = {..._calibracionInicial, ...calibracion};
        _calibracionConsultada = true;
        _error = null;
      });
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _consultando = false;
    }
  }

  Future<void> _alternarCaptura() async {
    setState(() => _capturaOcupada = true);
    try {
      final respuesta = await widget.api.controlarCapturaSensor(
        !_capturaSolicitada,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            respuesta['mensaje'] as String? ?? 'Estado actualizado',
          ),
        ),
      );
      await _actualizar();
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _capturaOcupada = false);
    }
  }

  Future<void> _alternarProyeccion() async {
    setState(() => _capturaOcupada = true);
    try {
      final activa = await widget.api.controlarProyeccion(!_proyeccionActiva);
      if (mounted) setState(() => _proyeccionActiva = activa);
      await _actualizar();
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _capturaOcupada = false);
    }
  }

  Future<void> _guardarCalibracion() async {
    setState(() => _guardando = true);
    try {
      final guardada = await widget.api.guardarCalibracion(_calibracion);
      if (!mounted) return;
      setState(() {
        _calibracion = {
          for (final key in _calibracion.keys)
            key: guardada[key] ?? _calibracion[key],
        };
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calibración guardada para reutilizarla.'),
        ),
      );
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _cambiarValor(String campo, double valor) {
    setState(() => _calibracion = {..._calibracion, campo: valor});
  }

  Widget _controlRango(
    String clave,
    String etiqueta,
    double min,
    double max, {
    String sufijo = '%',
  }) {
    final valor = (_calibracion[clave] as num?)?.toDouble() ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(etiqueta)),
            Text(
              '${valor.toStringAsFixed(0)}$sufijo',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.espresso,
              ),
            ),
          ],
        ),
        Slider(
          value: valor.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: (nuevo) => _cambiarValor(clave, nuevo),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoTexto = !_sensorConectado
        ? 'Kinect desconectado'
        : _sensorCapturando
        ? 'Capturando en vivo'
        : _capturaSolicitada
        ? 'Conectado · esperando fotogramas'
        : 'Conectado · captura pausada';
    final ancho = _sensor['ancho'] ?? 0;
    final alto = _sensor['alto'] ?? 0;
    final fps = (_sensor['fps'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
      children: [
        Text(
          'Sistema',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppTheme.texto, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text('Estado del sensor, proyección y calibración reutilizable.'),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded, color: AppTheme.espresso),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kinect Xbox 360',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _consultando ? null : _actualizar,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar estado',
                    ),
                  ],
                ),
                Text(
                  estadoTexto,
                  style: TextStyle(
                    color: _sensorCapturando
                        ? AppTheme.espresso
                        : AppTheme.texto,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$ancho × $alto px · ${fps.toStringAsFixed(1)} FPS'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sensor.isEmpty || _capturaOcupada
                        ? null
                        : _alternarCaptura,
                    icon: Icon(
                      _capturaSolicitada
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _capturaSolicitada ? 'Pausar captura' : 'Iniciar captura',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: SwitchListTile(
            value: _proyeccionActiva,
            onChanged: _capturaOcupada ? null : (_) => _alternarProyeccion(),
            secondary: const Icon(
              Icons.present_to_all_rounded,
              color: AppTheme.espresso,
            ),
            title: const Text(
              'Proyección',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _proyeccionActiva
                  ? 'Solicitud activa en el visor web'
                  : 'Proyección detenida',
            ),
          ),
        ),
        if (_proyeccionActiva)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              'El visor Vue debe estar abierto en la computadora. Pulsa su control de pantalla completa si el navegador lo solicita.',
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calibración de instalación',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Guarda estos valores en FastAPI para recuperarlos después de mover el sensor o el proyector.',
                ),
                const SizedBox(height: 12),
                _controlRango(
                  'centroSensorX',
                  'Centro Kinect horizontal',
                  0,
                  100,
                ),
                _controlRango(
                  'centroSensorY',
                  'Centro Kinect vertical',
                  0,
                  100,
                ),
                _controlRango('anchoSensor', 'Ancho del área Kinect', 10, 100),
                _controlRango('altoSensor', 'Alto del área Kinect', 10, 100),
                const Divider(),
                _controlRango(
                  'desplazamientoX',
                  'Ajuste horizontal del proyector',
                  -10,
                  10,
                  sufijo: '',
                ),
                _controlRango(
                  'desplazamientoY',
                  'Ajuste vertical del proyector',
                  -10,
                  10,
                  sufijo: '',
                ),
                _controlRango(
                  'escala',
                  'Escala del proyector',
                  0.1,
                  3,
                  sufijo: '×',
                ),
                _controlRango(
                  'rotacion',
                  'Rotación del proyector',
                  -180,
                  180,
                  sufijo: '°',
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardarCalibracion,
                    icon: _guardando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _guardando ? 'Guardando…' : 'Guardar calibración',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: const ListTile(
            leading: Icon(Icons.palette_outlined, color: AppTheme.espresso),
            title: Text('Colores y perfiles'),
            subtitle: Text(
              'Selecciona colores en Configuración y recupera perfiles en Simulación > Guardadas.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dns_outlined, color: AppTheme.espresso),
            title: const Text('FastAPI'),
            subtitle: Text(BackendConfig.baseUrl),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_error!),
            ),
          ),
        ],
      ],
    );
  }
}
