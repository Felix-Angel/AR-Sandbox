import 'package:flutter/material.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/models/configuracion_simulacion.dart';
import '../../../core/network/models/respuesta_simulacion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/imagen_terreno.dart';

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
    required this.onGuardarSimulacion,
  });

  final String terreno;
  final ConfiguracionTerreno configuracion;
  final bool configuracionGuardada;
  final bool registroEnCurso;
  final ValueChanged<ConfiguracionTerreno> onConfiguracionChanged;
  final Future<RespuestaSimulacion> Function(String, SolicitudConfiguracion)
  onGuardarSimulacion;

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

  Future<SolicitudConfiguracion?> _crearSolicitud() async {
    try {
      return SolicitudConfiguracion.desdeInterfaz(
        terreno: widget.terreno,
        color: widget.configuracion.nombreColor,
        altura: widget.configuracion.altura,
      );
    } on ArgumentError catch (error) {
      _mostrarError('Revisa la selección antes de guardar: ${error.message}');
      return null;
    }
  }

  Future<void> _guardarSimulacion() async {
    if (_enviando || widget.registroEnCurso) return;
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogoNombreSimulacion(),
    );
    if (nombre == null || nombre.isEmpty || !mounted) return;

    final solicitud = await _crearSolicitud();
    if (solicitud == null || !mounted) return;
    setState(() => _enviando = true);
    try {
      final respuesta = await widget.onGuardarSimulacion(nombre, solicitud);
      if (!mounted) return;
      setState(() => _respuestaRegistro = respuesta);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(respuesta.mensaje)));
    } on ArgumentError catch (error) {
      _mostrarError('Revisa la selección antes de guardar: ${error.message}');
    } on BackendApiException catch (error) {
      final mensaje = switch (error.statusCode) {
        400 => 'El backend rechazó la operación: ${error.message}',
        404 =>
          'No se encontró la ruta para guardar la simulación. ${error.message}',
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
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.canela),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuracion;
    final controlesDeshabilitados = _enviando || widget.registroEnCurso;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.canela.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.tune_rounded, color: AppTheme.canela),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Personaliza tu terreno',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.texto,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ajusta el color y la altura del relieve.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 148,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImagenTerreno(terreno: widget.terreno),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC2D1C14)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    children: [
                      const Icon(Icons.landscape_rounded, color: Colors.white),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          widget.terreno,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.caramelo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                        color: seleccionado
                            ? AppTheme.espresso
                            : AppTheme.arena,
                        width: seleccionado ? 3 : 1,
                      ),
                      boxShadow: [
                        if (seleccionado)
                          BoxShadow(
                            color: AppTheme.espresso.withValues(alpha: .17),
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
                                : AppTheme.texto,
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
                color: AppTheme.espresso,
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
          activeColor: AppTheme.canela,
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
            color: AppTheme.espresso.withValues(alpha: .08),
            child: ListTile(
              leading: const Icon(
                Icons.cloud_done_outlined,
                color: AppTheme.espresso,
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
                  color: AppTheme.espresso,
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
                  color: AppTheme.canela,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: controlesDeshabilitados ? null : _guardarSimulacion,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(
              _enviando ? 'Guardando simulación…' : 'Guardar simulación',
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogoNombreSimulacion extends StatefulWidget {
  const _DialogoNombreSimulacion();

  @override
  State<_DialogoNombreSimulacion> createState() =>
      _DialogoNombreSimulacionState();
}

class _DialogoNombreSimulacionState extends State<_DialogoNombreSimulacion> {
  final _controladorNombre = TextEditingController();

  @override
  void dispose() {
    _controladorNombre.dispose();
    super.dispose();
  }

  void _confirmar() {
    Navigator.of(context).pop(_controladorNombre.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Guardar simulación'),
    content: TextField(
      controller: _controladorNombre,
      autofocus: true,
      maxLength: 60,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Nombre',
        hintText: 'Ej. Llanura turquesa',
      ),
      onSubmitted: (_) => _confirmar(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirmar, child: const Text('Guardar')),
    ],
  );
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
              ?.copyWith(color: AppTheme.texto.withValues(alpha: .7)),
        ),
      ),
      Expanded(
        child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ],
  );
}
