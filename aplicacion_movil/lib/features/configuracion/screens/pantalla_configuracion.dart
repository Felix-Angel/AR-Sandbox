import 'package:flutter/material.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/models/configuracion_simulacion.dart';
import '../../../core/network/models/respuesta_simulacion.dart';
import '../../../core/theme/app_theme.dart';

@immutable
class ConfiguracionTerreno {
  const ConfiguracionTerreno({
    required this.color,
    required this.altura,
    this.nombreColorApi,
  });

  final Color color;
  final double altura;
  final String? nombreColorApi;

  factory ConfiguracionTerreno.desdeApi(ConfiguracionSimulacion config) {
    final color = coloresDisponibles[config.color];
    if (color == null) {
      throw FormatException('Color recibido no reconocido: ${config.color}');
    }
    return ConfiguracionTerreno(
      color: color,
      altura: config.altura,
      nombreColorApi: config.color,
    );
  }

  static const Map<String, Color> coloresDisponibles = {
    'Verde bosque': AppTheme.verde,
    'Terracota': AppTheme.terracota,
    'Crema': AppTheme.crema,
    'Tinta': AppTheme.tinta,
    'Maíz': AppTheme.maiz,
    'Turquesa': AppTheme.turquesa,
    'Bugambilia': AppTheme.bugambilia,
    'Café': AppTheme.cafe,
    'Gris': AppTheme.gris,
  };

  String get nombreColor {
    if (nombreColorApi != null) return nombreColorApi!;
    for (final entrada in coloresDisponibles.entries) {
      if (entrada.value == color) return entrada.key;
    }
    return 'Personalizado';
  }
}

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({
    super.key,
    required this.terreno,
    required this.configuracion,
    required this.configuracionGuardada,
    required this.registroEnCurso,
    required this.onConfiguracionChanged,
    required this.onRegistrarConfiguracion,
  });

  final String terreno;
  final ConfiguracionTerreno configuracion;
  final bool configuracionGuardada;
  final bool registroEnCurso;
  final ValueChanged<ConfiguracionTerreno> onConfiguracionChanged;
  final Future<RespuestaSimulacion> Function(SolicitudConfiguracion)
  onRegistrarConfiguracion;

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  bool _enviando = false;
  RespuestaSimulacion? _respuestaRegistro;

  static const _colores = ConfiguracionTerreno.coloresDisponibles;

  void _actualizar({Color? color, double? altura}) {
    if (_enviando) return;
    setState(() => _respuestaRegistro = null);
    widget.onConfiguracionChanged(
      ConfiguracionTerreno(
        color: color ?? widget.configuracion.color,
        altura: altura ?? widget.configuracion.altura,
        nombreColorApi: color == null
            ? widget.configuracion.nombreColorApi
            : null,
      ),
    );
  }

  Future<void> _guardarConfiguracion() async {
    if (_enviando || widget.registroEnCurso) return;
    setState(() => _enviando = true);
    try {
      final solicitud = SolicitudConfiguracion.desdeInterfaz(
        terreno: widget.terreno,
        color: widget.configuracion.nombreColor,
        altura: widget.configuracion.altura,
      );
      final respuesta = await widget.onRegistrarConfiguracion(solicitud);
      if (!mounted) return;
      setState(() => _respuestaRegistro = respuesta);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(respuesta.mensaje)));
    } on ArgumentError catch (error) {
      _mostrarError('Revisa la selección antes de guardar: ${error.message}');
    } on BackendApiException catch (error) {
      final mensaje = switch (error.statusCode) {
        400 => 'El backend rechazó la operación: ${error.message}',
        404 => 'No se encontró el endpoint de configuración. ${error.message}',
        422 => 'Los datos no cumplen el contrato: ${error.message}',
        null => 'No se pudo conectar con el servidor. Verifica que FastAPI esté activo y vuelve a intentar.',
        _ => 'No se pudo guardar la configuración: ${error.message}',
      };
      _mostrarError(mensaje);
    } on FormatException catch (error) {
      _mostrarError(
        'La respuesta del servidor no tiene el formato esperado: ${error.message}',
      );
    } on StateError catch (error) {
      _mostrarError(error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.terracota),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuracion;
    final controlesDeshabilitados = _enviando || widget.registroEnCurso;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Personaliza tu terreno',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppTheme.tinta, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Ajusta el color y la altura del relieve.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.verde.withValues(alpha: .12),
              child: const Icon(Icons.landscape_rounded, color: AppTheme.verde),
            ),
            title: Text(
              widget.terreno,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Tipo de relieve'),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Color del terreno',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          'Seleccionado: ${config.nombreColor}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colores.entries.map((entrada) {
            final nombre = entrada.key;
            final color = entrada.value;
            final seleccionado = color == config.color;
            return Semantics(
              button: true,
              selected: seleccionado,
              label: nombre,
              child: Tooltip(
                message: nombre,
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onTap: controlesDeshabilitados
                      ? null
                      : () => _actualizar(color: color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: seleccionado ? AppTheme.verde : AppTheme.borde,
                        width: seleccionado ? 3 : 1,
                      ),
                      boxShadow: [
                        if (seleccionado)
                          BoxShadow(
                            color: AppTheme.verde.withValues(alpha: .17),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: seleccionado
                        ? Icon(
                            Icons.check_rounded,
                            color: color.computeLuminance() < .35
                                ? Colors.white
                                : AppTheme.tinta,
                          )
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                'Altura del relieve',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${config.altura.round()}%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.verde,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: config.altura,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppTheme.verde,
          label: '${config.altura.round()}%',
          onChanged: controlesDeshabilitados
              ? null
              : (value) => _actualizar(altura: value),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('0%'), Text('100%')],
        ),
        const SizedBox(height: 22),
        if (widget.configuracionGuardada && _respuestaRegistro != null)
          Card(
            color: AppTheme.verde.withValues(alpha: .08),
            child: ListTile(
              leading: const Icon(
                Icons.cloud_done_outlined,
                color: AppTheme.verde,
              ),
              title: const Text('Configuración guardada en FastAPI'),
              subtitle: Text(
                'Estado recibido: ${_respuestaRegistro!.estado.valorApi}',
              ),
            ),
          ),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen de simulación',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _DatoResumen(
                  icono: Icons.terrain_rounded,
                  etiqueta: 'Terreno',
                  valor: widget.terreno,
                  color: AppTheme.verde,
                ),
                const SizedBox(height: 10),
                _DatoResumen(
                  icono: Icons.palette_outlined,
                  etiqueta: 'Color',
                  valor: config.nombreColor,
                  color: config.color,
                ),
                const SizedBox(height: 10),
                _DatoResumen(
                  icono: Icons.height_rounded,
                  etiqueta: 'Altura',
                  valor: '${config.altura.round()}%',
                  color: AppTheme.terracota,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: controlesDeshabilitados ? null : _guardarConfiguracion,
          icon: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _enviando ? 'Guardando configuración…' : 'Guardar configuración',
          ),
        ),
      ],
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, size: 19, color: color),
      const SizedBox(width: 9),
      SizedBox(
        width: 68,
        child: Text(
          etiqueta,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.tinta.withValues(alpha: .7)),
        ),
      ),
      Expanded(
        child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ],
  );
}
