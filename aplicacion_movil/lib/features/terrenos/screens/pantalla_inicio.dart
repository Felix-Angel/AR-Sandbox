import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../configuracion/screens/pantalla_configuracion.dart';
import '../../simulacion/screens/pantalla_simulacion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _seccion = 0;
  String? _terreno;
  ConfiguracionTerreno _configuracion = const ConfiguracionTerreno(
    color: AppTheme.verde,
    altura: 50,
  );
  EstadoSimulacion _estadoSimulacion = EstadoSimulacion.sinConfigurar;

  void _irA(int seccion) => setState(() => _seccion = seccion);

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      _Inicio(terreno: _terreno, configuracion: _configuracion, irA: _irA),
      _Terrenos(
        seleccionado: _terreno,
        alSeleccionar: (nombre) => setState(() {
          if (_terreno == nombre) {
            _terreno = null;
            _estadoSimulacion = EstadoSimulacion.sinConfigurar;
          } else {
            _terreno = nombre;
            _estadoSimulacion = EstadoSimulacion.lista;
            _configuracion = const ConfiguracionTerreno(
              color: AppTheme.verde,
              altura: 50,
            );
          }
        }),
        irA: _irA,
      ),
      if (_terreno == null)
        _ConfigurarVacio(irA: _irA)
      else
        PantallaConfiguracion(
          key: ValueKey(_terreno),
          terreno: _terreno!,
          configuracion: _configuracion,
          onConfiguracionChanged: (configuracion) =>
              setState(() => _configuracion = configuracion),
        ),
      PantallaSimulacion(
        terreno: _terreno,
        configuracion: _configuracion,
        estado: _estadoSimulacion,
        alIniciar: () {
          if (_terreno != null &&
              _estadoSimulacion != EstadoSimulacion.enEjecucion) {
            setState(() => _estadoSimulacion = EstadoSimulacion.enEjecucion);
          }
        },
        alDetener: () {
          if (_estadoSimulacion == EstadoSimulacion.enEjecucion) {
            setState(() => _estadoSimulacion = EstadoSimulacion.detenida);
          }
        },
        alSeleccionarTerreno: () => _irA(1),
      ),
      const _Ajustes(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Sandbox'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _irA(4),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _seccion, children: pantallas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _seccion,
        labelBehavior: MediaQuery.sizeOf(context).width < 400
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.terrain_outlined),
            selectedIcon: Icon(Icons.terrain),
            label: 'Terrenos',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Configurar',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            selectedIcon: Icon(Icons.play_circle_fill_rounded),
            label: 'Simulación',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _Inicio extends StatelessWidget {
  const _Inicio({
    required this.terreno,
    required this.configuracion,
    required this.irA,
  });

  final String? terreno;
  final ConfiguracionTerreno configuracion;
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      Text(
        '¡Bienvenido!',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: AppTheme.tinta, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Explora, crea y aprende. Modela el paisaje y descubre cómo cambia el terreno.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppTheme.tinta.withValues(alpha: .78)),
      ),
      const SizedBox(height: 18),
      _HeroSimulacion(onTap: () => irA(3)),
      const SizedBox(height: 18),
      Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => irA(terreno == null ? 1 : 2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppTheme.terracota,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu último terreno',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                if (terreno == null)
                  const Text(
                    'Selecciona un terreno para comenzar. Aquí aparecerán su color y altura.',
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: configuracion.color.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.landscape_rounded,
                          color: configuracion.color,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              terreno!,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                      '${configuracion.nombreColor} · ${configuracion.altura.round()}% de altura',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Accesos rápidos',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _AccesoInicio(
              icono: Icons.terrain_rounded,
              titulo: 'Terrenos',
              detalle: 'Elige un paisaje',
              color: AppTheme.turquesa,
              onTap: () => irA(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AccesoInicio(
              icono: Icons.tune_rounded,
              titulo: 'Configurar',
              detalle: terreno == null ? 'Primero elige' : 'Color y altura',
              color: AppTheme.bugambilia,
              onTap: () => irA(terreno == null ? 1 : 2),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const _EstadoConexion(),
    ],
  );
}

class _HeroSimulacion extends StatelessWidget {
  const _HeroSimulacion({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.verde, Color(0xFF47785B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppTheme.verde.withValues(alpha: .2),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dale forma a tu paisaje',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.public_rounded,
                color: AppTheme.maiz,
                size: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Inicia una nueva simulación y crea un relieve a tu medida.',
          style: TextStyle(color: Colors.white.withValues(alpha: .9)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.maiz,
            foregroundColor: AppTheme.tinta,
          ),
          onPressed: onTap,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Nueva simulación'),
        ),
      ],
    ),
  );
}

class _AccesoInicio extends StatelessWidget {
  const _AccesoInicio({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icono, color: color),
            ),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(detalle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _EstadoConexion extends StatelessWidget {
  const _EstadoConexion();

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFF0E9),
        child: Icon(Icons.cloud_off_rounded, color: AppTheme.terracota),
      ),
      title: const Text(
        'Servidor sin configurar',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('La conexión estará disponible próximamente.'),
      trailing: const Icon(Icons.circle, size: 10, color: AppTheme.terracota),
    ),
  );
}

class _Terrenos extends StatelessWidget {
  const _Terrenos({
    required this.seleccionado,
    required this.alSeleccionar,
    required this.irA,
  });

  final String? seleccionado;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<int> irA;
  static const _terrenos = [
    ('Montañas', 'Cumbres altas y pendientes pronunciadas.', Icons.landscape_rounded),
    ('Valles', 'Depresiones suaves entre montañas.', Icons.waves_rounded),
    ('Volcanes', 'Relieves elevados con cráteres.', Icons.volcano_rounded),
    ('Llanuras', 'Superficies amplias y casi planas.', Icons.grass_rounded),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(
          'Elige un relieve',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Toca una opción para seleccionarla.'),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final anchoTarjeta = (constraints.maxWidth - 54) / 2;
            final altoAdaptable = anchoTarjeta * .9;
            final altoTarjeta = altoAdaptable < 160 ? 160.0 : altoAdaptable;

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _terrenos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: altoTarjeta,
              ),
              itemBuilder: (context, index) {
                final (nombre, descripcion, icono) = _terrenos[index];
                final activo = seleccionado == nombre;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: activo
                      ? AppTheme.verde.withValues(alpha: .1)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: activo ? AppTheme.verde : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => alSeleccionar(nombre),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icono,
                            size: 32,
                            color: activo ? AppTheme.terracota : AppTheme.verde,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nombre,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            descripcion,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            activo
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: activo
                                ? AppTheme.terracota
                                : AppTheme.tinta.withValues(alpha: .25),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      if (seleccionado != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => irA(2),
              icon: const Icon(Icons.tune),
              label: const Text('Continuar a configuración'),
            ),
          ),
        ),
    ],
  );
}

class _ConfigurarVacio extends StatelessWidget {
  const _ConfigurarVacio({required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.landscape_outlined, size: 64, color: AppTheme.verde),
          const SizedBox(height: 16),
          Text(
            'Primero elige un terreno',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Después podrás ajustar su color y altura.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => irA(1),
            child: const Text('Elegir terreno'),
          ),
        ],
      ),
    ),
  );
}

class _Ajustes extends StatelessWidget {
  const _Ajustes();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      Text(
        'Ajustes',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.verde,
            child: Icon(Icons.landscape, color: Colors.white),
          ),
          title: Text('AR Sandbox'),
          subtitle: Text('Explora y configura terrenos interactivos.'),
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off, color: AppTheme.terracota),
          title: Text('Servidor'),
          subtitle: Text('Conexión todavía no configurada'),
          trailing: Icon(Icons.circle, size: 10, color: AppTheme.terracota),
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.info_outline, color: AppTheme.turquesa),
          title: Text('Aplicación móvil'),
          subtitle: Text('AR Sandbox · Versión 1.0.0'),
        ),
      ),
    ],
  );
}
