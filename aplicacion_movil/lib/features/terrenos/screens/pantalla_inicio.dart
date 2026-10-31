import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/models/configuracion_simulacion.dart'
    show ConfiguracionSimulacion, SolicitudConfiguracion, TerrenosApi;
import '../../../core/network/models/respuesta_simulacion.dart' as api_models;
import '../../../core/theme/app_theme.dart';
import '../../configuracion/screens/pantalla_configuracion.dart';
import '../../simulacion/screens/pantalla_simulacion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, this.backendApiService});

  final BackendApiService? backendApiService;

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
  bool _configuracionGuardada = false;
  bool _registroEnCurso = false;
  bool _consultandoEstado = false;
  bool _operacionSimulacionEnCurso = false;
  bool _estadoConfirmado = false;
  String? _errorBackend;
  BackendApiService? _ownedBackendApi;

  BackendApiService get _backendApi =>
      widget.backendApiService ?? (_ownedBackendApi ??= BackendApiService());

  void _irA(int seccion) {
    setState(() => _seccion = seccion);
    if (seccion == 3) unawaited(_consultarEstado());
  }

  EstadoSimulacion _estadoDesdeApi(api_models.EstadoSimulacionApi estado) =>
      switch (estado) {
        api_models.EstadoSimulacionApi.sinConfigurar =>
          EstadoSimulacion.sinConfigurar,
        api_models.EstadoSimulacionApi.lista => EstadoSimulacion.lista,
        api_models.EstadoSimulacionApi.enEjecucion =>
          EstadoSimulacion.enEjecucion,
        api_models.EstadoSimulacionApi.detenida => EstadoSimulacion.detenida,
      };

  void _sincronizarDesdeBackend(
    api_models.EstadoSimulacionApi estado,
    ConfiguracionSimulacion? configuracion,
  ) {
    _estadoSimulacion = _estadoDesdeApi(estado);
    if (configuracion == null) {
      _terreno = null;
      _configuracion = const ConfiguracionTerreno(
        color: AppTheme.verde,
        altura: 50,
      );
      _configuracionGuardada = false;
      return;
    }
    _terreno = TerrenosApi.aNombre(configuracion.terreno);
    _configuracion = ConfiguracionTerreno.desdeApi(configuracion);
    _configuracionGuardada = true;
  }

  void _aplicarRespuestaBackend(api_models.RespuestaSimulacion respuesta) {
    _sincronizarDesdeBackend(respuesta.estado, respuesta.configuracion);
    _estadoConfirmado = true;
    _errorBackend = null;
  }

  Future<void> _consultarEstado() async {
    if (_consultandoEstado || _operacionSimulacionEnCurso) return;
    setState(() {
      _consultandoEstado = true;
      _estadoConfirmado = false;
      _errorBackend = null;
    });
    try {
      final respuesta = await _backendApi.obtenerEstado();
      if (!mounted) return;
      setState(() {
        _sincronizarDesdeBackend(respuesta.estado, respuesta.configuracion);
        _estadoConfirmado = true;
      });
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _errorBackend = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorBackend = error.message);
    } finally {
      if (mounted) setState(() => _consultandoEstado = false);
    }
  }

  Future<api_models.RespuestaSimulacion> _iniciarSimulacion() =>
      _ejecutarOperacionSimulacion(_backendApi.iniciarSimulacion);

  Future<api_models.RespuestaSimulacion> _detenerSimulacion() =>
      _ejecutarOperacionSimulacion(_backendApi.detenerSimulacion);

  Future<api_models.RespuestaSimulacion> _ejecutarOperacionSimulacion(
    Future<api_models.RespuestaSimulacion> Function() operacion,
  ) async {
    if (_operacionSimulacionEnCurso || !_estadoConfirmado) {
      throw StateError(
        'Espera a confirmar el estado del servidor antes de continuar.',
      );
    }
    setState(() {
      _operacionSimulacionEnCurso = true;
      _errorBackend = null;
    });
    try {
      final respuesta = await operacion();
      if (mounted) setState(() => _aplicarRespuestaBackend(respuesta));
      return respuesta;
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _errorBackend = error.message);
      rethrow;
    } finally {
      if (mounted) setState(() => _operacionSimulacionEnCurso = false);
    }
  }

  Future<api_models.RespuestaSimulacion> _registrarConfiguracion(
    SolicitudConfiguracion solicitud,
  ) async {
    if (_registroEnCurso) {
      throw StateError('Ya hay un registro de configuración en curso.');
    }
    setState(() {
      _registroEnCurso = true;
      _configuracionGuardada = false;
    });
    try {
      final respuesta = await _backendApi.registrarConfiguracion(solicitud);
      if (mounted) {
        final coincideConLaActual =
            _terreno != null &&
            TerrenosApi.aId(_terreno!) == solicitud.terreno &&
            _configuracion.nombreColor == solicitud.color &&
            _configuracion.altura == solicitud.altura;
        setState(() {
          if (coincideConLaActual) {
            _aplicarRespuestaBackend(respuesta);
          } else {
            _configuracionGuardada = false;
            _estadoConfirmado = false;
          }
        });
      }
      return respuesta;
    } finally {
      if (mounted) setState(() => _registroEnCurso = false);
    }
  }

  @override
  void dispose() {
    _ownedBackendApi?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = <Widget>[
      _Inicio(
        terreno: _terreno,
        configuracion: _configuracion,
        configuracionGuardada: _configuracionGuardada,
        irA: _irA,
      ),
      _Terrenos(
        seleccionado: _terreno,
        configuracion: _configuracion,
        configuracionGuardada: _configuracionGuardada,
        alSeleccionar: (nombre) => setState(() {
          _configuracionGuardada = false;
          _estadoConfirmado = false;
          if (_terreno == nombre) {
            _terreno = null;
          } else {
            _terreno = nombre;
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
          configuracionGuardada: _configuracionGuardada,
          registroEnCurso: _registroEnCurso,
          onConfiguracionChanged: (configuracion) => setState(() {
            _configuracion = configuracion;
            _configuracionGuardada = false;
            _estadoConfirmado = false;
          }),
          onRegistrarConfiguracion: _registrarConfiguracion,
        ),
      PantallaSimulacion(
        terreno: _terreno,
        configuracion: _configuracion,
        estado: _estadoSimulacion,
        estadoConfirmado: _estadoConfirmado,
        consultandoEstado: _consultandoEstado,
        operacionEnCurso: _operacionSimulacionEnCurso,
        errorBackend: _errorBackend,
        alIniciar: _iniciarSimulacion,
        alDetener: _detenerSimulacion,
        alActualizarEstado: () => unawaited(_consultarEstado()),
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
    required this.configuracionGuardada,
    required this.irA,
  });

  final String? terreno;
  final ConfiguracionTerreno configuracion;
  final bool configuracionGuardada;
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
                if (terreno != null) ...[
                  const SizedBox(height: 8),
                  _EstadoRegistro(guardada: configuracionGuardada),
                ],
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
      _EstadoConexion(configuracionGuardada: configuracionGuardada),
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
  const _EstadoConexion({required this.configuracionGuardada});

  final bool configuracionGuardada;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: configuracionGuardada
            ? AppTheme.verde.withValues(alpha: .12)
            : const Color(0xFFFFF0E9),
        child: Icon(
          configuracionGuardada
              ? Icons.cloud_done_rounded
              : Icons.cloud_upload_rounded,
          color: configuracionGuardada ? AppTheme.verde : AppTheme.terracota,
        ),
      ),
      title: Text(
        configuracionGuardada
            ? 'Configuración registrada'
            : 'Registro en servidor pendiente',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        configuracionGuardada
            ? 'FastAPI confirmó el registro de la configuración actual.'
            : 'Guarda tu terreno y sus ajustes para enviarlos a FastAPI.',
      ),
      trailing: Icon(
        Icons.circle,
        size: 10,
        color: configuracionGuardada ? AppTheme.verde : AppTheme.terracota,
      ),
    ),
  );
}

class _EstadoRegistro extends StatelessWidget {
  const _EstadoRegistro({required this.guardada});

  final bool guardada;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      avatar: Icon(
        guardada ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
        size: 18,
        color: guardada ? AppTheme.verde : AppTheme.terracota,
      ),
      label: Text(guardada ? 'Guardada en servidor' : 'Pendiente de registro'),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _Terrenos extends StatelessWidget {
  const _Terrenos({
    required this.seleccionado,
    required this.configuracion,
    required this.configuracionGuardada,
    required this.alSeleccionar,
    required this.irA,
  });

  final String? seleccionado;
  final ConfiguracionTerreno configuracion;
  final bool configuracionGuardada;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<int> irA;
  static const _terrenos = [
    (
      'Montañas',
      'Cumbres altas y pendientes pronunciadas.',
      Icons.landscape_rounded,
    ),
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
                            activo ? Icons.check_circle : Icons.circle_outlined,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.palette_outlined,
                    color: configuracion.color,
                  ),
                  title: Text(
                    '${configuracion.nombreColor} · ${configuracion.altura.round()}% de altura',
                  ),
                  subtitle: Text(
                    configuracionGuardada
                        ? 'Configuración guardada en el servidor'
                        : 'Configuración local',
                  ),
                  trailing: Icon(
                    configuracionGuardada
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                    color: configuracionGuardada
                        ? AppTheme.verde
                        : AppTheme.terracota,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => irA(2),
                  icon: const Icon(Icons.tune),
                  label: const Text('Continuar a configuración'),
                ),
              ),
            ],
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
