import 'package:flutter/material.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/models/respuesta_simulacion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/imagen_terreno.dart';
import '../../configuracion/screens/pantalla_configuracion.dart';

enum EstadoSimulacion { sinConfigurar, lista, enEjecucion, detenida }

class PantallaSimulacion extends StatelessWidget {
  const PantallaSimulacion({
    super.key,
    required this.terreno,
    required this.configuracion,
    required this.estado,
    required this.estadoConfirmado,
    required this.consultandoEstado,
    required this.operacionEnCurso,
    required this.errorBackend,
    required this.alIniciar,
    required this.alDetener,
    required this.alActualizarEstado,
    required this.alSeleccionarTerreno,
    this.simulacionesGuardadas = const [],
    this.simulacionSeleccionadaId,
    this.alSeleccionarSimulacion,
  });

  final String? terreno;
  final ConfiguracionTerreno configuracion;
  final EstadoSimulacion estado;
  final bool estadoConfirmado;
  final bool consultandoEstado;
  final bool operacionEnCurso;
  final String? errorBackend;
  final Future<RespuestaSimulacion> Function() alIniciar;
  final Future<RespuestaSimulacion> Function() alDetener;
  final VoidCallback alActualizarEstado;
  final VoidCallback alSeleccionarTerreno;
  final List<SimulacionGuardada> simulacionesGuardadas;
  final int? simulacionSeleccionadaId;
  final ValueChanged<int>? alSeleccionarSimulacion;

  Future<void> _ejecutarOperacion(
    BuildContext context,
    Future<RespuestaSimulacion> Function() operacion,
  ) async {
    try {
      final respuesta = await operacion();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(respuesta.mensaje)));
    } on BackendApiException catch (error) {
      if (!context.mounted) return;
      final mensaje = error.statusCode == null
          ? 'No se pudo conectar con FastAPI. ${error.message}'
          : 'FastAPI respondió HTTP ${error.statusCode}: ${error.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: AppTheme.canela),
      );
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configurada =
        estadoConfirmado &&
        terreno != null &&
        estado != EstadoSimulacion.sinConfigurar;
    final activa = estado == EstadoSimulacion.enEjecucion;
    final colorEstado = switch (estado) {
      EstadoSimulacion.sinConfigurar => AppTheme.canela,
      EstadoSimulacion.lista => AppTheme.salvia,
      EstadoSimulacion.enEjecucion => AppTheme.espresso,
      EstadoSimulacion.detenida => AppTheme.caramelo,
    };
    final textoEstado = switch (estado) {
      EstadoSimulacion.sinConfigurar => 'Sin configurar',
      EstadoSimulacion.lista => 'Lista para iniciar',
      EstadoSimulacion.enEjecucion => 'En ejecución',
      EstadoSimulacion.detenida => 'Detenida',
    };
    final iconoEstado = switch (estado) {
      EstadoSimulacion.sinConfigurar => Icons.pending_outlined,
      EstadoSimulacion.lista => Icons.check_circle_outline,
      EstadoSimulacion.enEjecucion => Icons.play_circle_fill_rounded,
      EstadoSimulacion.detenida => Icons.pause_circle_filled_rounded,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
      children: [
        Text(
          'Simulación',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppTheme.texto, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Inicia y controla tu relieve con la configuración actual.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (simulacionesGuardadas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmarks_outlined,
                        color: AppTheme.espresso,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Simulaciones guardadas',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text('${simulacionesGuardadas.length}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppTheme.espresso.withValues(
                          alpha: .08,
                        ),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige una versión para cargarla en el entorno.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Elegir simulación',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: simulacionSeleccionadaId,
                        hint: const Text('Elige una simulación'),
                        isExpanded: true,
                        items: simulacionesGuardadas.map((simulacion) {
                          final config = simulacion.configuracion;
                          return DropdownMenuItem<int>(
                            value: simulacion.id,
                            child: Text(
                              '${simulacion.nombre} · ${config.nombreTerreno} · ${config.color} · ${config.altura.round()}%',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: operacionEnCurso || activa
                            ? null
                            : (id) {
                                if (id != null) {
                                  alSeleccionarSimulacion?.call(id);
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.espresso.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      size: 28,
                      color: AppTheme.espresso,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu biblioteca está vacía',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Crea un terreno y guárdalo con un nombre para encontrarlo aquí.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: alSeleccionarTerreno,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crear simulación'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (consultandoEstado)
          const Card(
            child: ListTile(
              leading: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              title: Text('Consultando estado en FastAPI…'),
              subtitle: Text('Esperando una respuesta del servidor.'),
            ),
          )
        else if (!estadoConfirmado)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.cloud_off_outlined,
                color: AppTheme.canela,
              ),
              title: const Text('No se pudo confirmar el estado'),
              subtitle: Text(errorBackend ?? 'Vuelve a consultar el servidor.'),
              trailing: IconButton(
                tooltip: 'Volver a consultar',
                onPressed: operacionEnCurso ? null : alActualizarEstado,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          )
        else
          Card(
            color: colorEstado.withValues(alpha: .1),
            child: ListTile(
              leading: Icon(iconoEstado, color: colorEstado, size: 32),
              title: const Text('Estado confirmado por FastAPI'),
              subtitle: Text(textoEstado),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: colorEstado),
                  IconButton(
                    tooltip: 'Actualizar estado',
                    onPressed: operacionEnCurso ? null : alActualizarEstado,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (configurada) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 128,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImagenTerreno(terreno: terreno),
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
                            left: 14,
                            bottom: 12,
                            child: Text(
                              terreno!,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configuración actual',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  _DatoSimulacion(
                    icono: Icons.terrain_rounded,
                    titulo: 'Terreno',
                    valor: terreno!,
                    color: AppTheme.espresso,
                  ),
                  const SizedBox(height: 12),
                  _DatoSimulacion(
                    icono: Icons.palette_outlined,
                    titulo: 'Color',
                    valor: configuracion.nombreColor,
                    color: configuracion.color,
                  ),
                  const SizedBox(height: 12),
                  _DatoSimulacion(
                    icono: Icons.height_rounded,
                    titulo: 'Altura',
                    valor: '${configuracion.altura.round()}%',
                    color: AppTheme.canela,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (activa)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.canela),
                onPressed: operacionEnCurso
                    ? null
                    : () => _ejecutarOperacion(context, alDetener),
                icon: operacionEnCurso
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_rounded),
                label: const Text('Detener simulación'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: operacionEnCurso
                    ? null
                    : () => _ejecutarOperacion(context, alIniciar),
                icon: operacionEnCurso
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  estado == EstadoSimulacion.detenida
                      ? 'Reanudar simulación'
                      : 'Iniciar simulación',
                ),
              ),
            ),
        ] else if (estadoConfirmado) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.landscape_outlined,
                    size: 48,
                    color: AppTheme.canela,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecciona un terreno antes de iniciar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elige un relieve y configura su color y altura para preparar la simulación.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: alSeleccionarTerreno,
                    icon: const Icon(Icons.terrain_rounded),
                    label: const Text('Seleccionar terreno'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DatoSimulacion extends StatelessWidget {
  const _DatoSimulacion({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, color: color, size: 22),
      const SizedBox(width: 12),
      SizedBox(
        width: 72,
        child: Text(
          titulo,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.texto.withValues(alpha: .7)),
        ),
      ),
      Expanded(
        child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      if (titulo == 'Color') ...[
        const SizedBox(width: 8),
        CircleAvatar(radius: 10, backgroundColor: color),
      ],
    ],
  );
}
