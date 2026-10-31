import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../configuracion/screens/pantalla_configuracion.dart';

enum EstadoSimulacion { sinConfigurar, lista, enEjecucion, detenida }

class PantallaSimulacion extends StatelessWidget {
  const PantallaSimulacion({
    super.key,
    required this.terreno,
    required this.configuracion,
    required this.estado,
    required this.alIniciar,
    required this.alDetener,
    required this.alSeleccionarTerreno,
  });

  final String? terreno;
  final ConfiguracionTerreno configuracion;
  final EstadoSimulacion estado;
  final VoidCallback alIniciar;
  final VoidCallback alDetener;
  final VoidCallback alSeleccionarTerreno;

  @override
  Widget build(BuildContext context) {
    final configurada = terreno != null;
    final activa = estado == EstadoSimulacion.enEjecucion;
    final colorEstado = switch (estado) {
      EstadoSimulacion.sinConfigurar => AppTheme.terracota,
      EstadoSimulacion.lista => AppTheme.turquesa,
      EstadoSimulacion.enEjecucion => AppTheme.verde,
      EstadoSimulacion.detenida => AppTheme.maiz,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Simulación',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.tinta,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Inicia y controla tu relieve con la configuración actual.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          color: colorEstado.withValues(alpha: .1),
          child: ListTile(
            leading: Icon(iconoEstado, color: colorEstado, size: 32),
            title: const Text('Estado de simulación'),
            subtitle: Text(textoEstado),
            trailing: Icon(Icons.circle, size: 12, color: colorEstado),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.crema,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.turquesa),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta etapa controla una simulación local de prueba. No se conecta al servidor ni a la proyección física.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (configurada) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuración actual',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DatoSimulacion(
                    icono: Icons.terrain_rounded,
                    titulo: 'Terreno',
                    valor: terreno!,
                    color: AppTheme.verde,
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
                    color: AppTheme.terracota,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (activa)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracota,
              ),
              onPressed: alDetener,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Detener simulación'),
            )
          else
            FilledButton.icon(
              onPressed: alIniciar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                estado == EstadoSimulacion.detenida
                    ? 'Reanudar simulación'
                    : 'Iniciar simulación',
              ),
            ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.landscape_outlined,
                    size: 48,
                    color: AppTheme.terracota,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecciona un terreno antes de iniciar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.tinta.withValues(alpha: .7),
          ),
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
