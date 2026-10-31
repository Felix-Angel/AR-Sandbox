import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

@immutable
class ConfiguracionTerreno {
  const ConfiguracionTerreno({required this.color, required this.altura});

  final Color color;
  final double altura;

  String get nombreColor {
    if (color == AppTheme.verde) return 'Verde bosque';
    if (color == Colors.brown) return 'Café';
    if (color == AppTheme.terracota) return 'Terracota';
    if (color == Colors.grey) return 'Gris';
    if (color == AppTheme.turquesa) return 'Turquesa';
    return 'Personalizado';
  }
}

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({
    super.key,
    required this.terreno,
    required this.configuracion,
    required this.onConfiguracionChanged,
  });

  final String terreno;
  final ConfiguracionTerreno configuracion;
  final ValueChanged<ConfiguracionTerreno> onConfiguracionChanged;

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  static const _colores = <Color>[
    AppTheme.verde,
    Colors.brown,
    AppTheme.terracota,
    Colors.grey,
    AppTheme.turquesa,
  ];

  void _actualizar({Color? color, double? altura}) {
    widget.onConfiguracionChanged(
      ConfiguracionTerreno(
        color: color ?? widget.configuracion.color,
        altura: altura ?? widget.configuracion.altura,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuracion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Personaliza tu terreno',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.tinta,
            fontWeight: FontWeight.bold,
          ),
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
            title: Text(widget.terreno, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tipo de relieve'),
          ),
        ),
        const SizedBox(height: 22),
        Text('Color del terreno', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('Seleccionado: ${config.nombreColor}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: _colores.map((color) {
            final seleccionado = color == config.color;
            final nombre = ConfiguracionTerreno(color: color, altura: config.altura).nombreColor;
            return Semantics(
              button: true,
              selected: seleccionado,
              label: nombre,
              child: Tooltip(
                message: nombre,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _actualizar(color: color),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: seleccionado ? AppTheme.tinta : Colors.white, width: seleccionado ? 3 : 1),
                      boxShadow: [if (seleccionado) BoxShadow(color: color.withValues(alpha: .35), blurRadius: 9)],
                    ),
                    child: seleccionado ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: Text('Altura del relieve', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          Text('${config.altura.round()}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.verde, fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: config.altura,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: AppTheme.verde,
          label: '${config.altura.round()}%',
          onChanged: (value) => _actualizar(altura: value),
        ),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('0%'), Text('100%')]),
        const SizedBox(height: 22),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Resumen de simulación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _DatoResumen(icono: Icons.terrain_rounded, etiqueta: 'Terreno', valor: widget.terreno, color: AppTheme.verde),
              const SizedBox(height: 10),
              _DatoResumen(icono: Icons.palette_outlined, etiqueta: 'Color', valor: config.nombreColor, color: config.color),
              const SizedBox(height: 10),
              _DatoResumen(icono: Icons.height_rounded, etiqueta: 'Altura', valor: '${config.altura.round()}%', color: AppTheme.terracota),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Configuración preparada: ${widget.terreno}, ${config.nombreColor}, ${config.altura.round()}%')),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Preparar simulación'),
        ),
      ],
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({required this.icono, required this.etiqueta, required this.valor, required this.color});

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icono, size: 19, color: color),
    const SizedBox(width: 9),
    SizedBox(width: 68, child: Text(etiqueta, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.tinta.withValues(alpha: .7)))),
    Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
  ]);
}
