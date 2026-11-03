import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/backend_api_service.dart';
import '../../../core/network/backend_config.dart';
import '../../../core/network/models/configuracion_simulacion.dart'
    show ConfiguracionSimulacion, SolicitudConfiguracion, TerrenosApi;
import '../../../core/network/models/respuesta_simulacion.dart' as api_models;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/imagen_terreno.dart';
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
  List<api_models.SimulacionGuardada> _simulacionesGuardadas = [];
  int? _simulacionSeleccionadaId;
  BackendApiService? _ownedBackendApi;

  BackendApiService get _backendApi =>
      widget.backendApiService ?? (_ownedBackendApi ??= BackendApiService());

  void _irA(int seccion) {
    setState(() => _seccion = seccion);
    if (seccion == 3) unawaited(_consultarEstado());
  }

  void _iniciarNuevaSimulacion() {
    if (_estadoConfirmado &&
        _estadoSimulacion == EstadoSimulacion.enEjecucion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detén la simulación actual antes de crear otra.'),
        ),
      );
      _irA(3);
      return;
    }
    setState(() {
      _terreno = null;
      _configuracion = const ConfiguracionTerreno(
        color: AppTheme.verde,
        altura: 50,
      );
      _configuracionGuardada = false;
      _estadoConfirmado = false;
      _simulacionSeleccionadaId = null;
      _seccion = 1;
    });
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
      var simulaciones = _simulacionesGuardadas;
      try {
        simulaciones = await _backendApi.listarSimulacionesGuardadas();
      } on BackendApiException {
        // La consulta del estado sigue siendo útil aunque la biblioteca no
        // esté disponible todavía (por ejemplo, con un backend anterior).
      }
      if (!mounted) return;
      setState(() {
        _sincronizarDesdeBackend(respuesta.estado, respuesta.configuracion);
        _simulacionesGuardadas = simulaciones;
        _simulacionSeleccionadaId = _idDeConfiguracion(respuesta.configuracion);
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

  int? _idDeConfiguracion(ConfiguracionSimulacion? configuracion) {
    if (configuracion == null) return null;
    for (final simulacion in _simulacionesGuardadas) {
      final guardada = simulacion.configuracion;
      if (guardada.terreno == configuracion.terreno &&
          guardada.color == configuracion.color &&
          guardada.altura == configuracion.altura) {
        return simulacion.id;
      }
    }
    return null;
  }

  Future<api_models.RespuestaSimulacion> _guardarSimulacion(
    String nombre,
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
      final respuesta = await _backendApi.guardarSimulacion(nombre, solicitud);
      final simulaciones = await _backendApi.listarSimulacionesGuardadas();
      if (mounted) {
        setState(() {
          _simulacionesGuardadas = simulaciones;
          _aplicarRespuestaBackend(respuesta);
          _simulacionSeleccionadaId = _idDeConfiguracion(
            respuesta.configuracion,
          );
        });
      }
      return respuesta;
    } finally {
      if (mounted) setState(() => _registroEnCurso = false);
    }
  }

  Future<void> _seleccionarSimulacion(int id) async {
    if (_operacionSimulacionEnCurso || !_estadoConfirmado) return;
    setState(() {
      _operacionSimulacionEnCurso = true;
      _errorBackend = null;
    });
    try {
      final respuesta = await _backendApi.seleccionarSimulacion(id);
      if (!mounted) return;
      setState(() {
        _aplicarRespuestaBackend(respuesta);
        _simulacionSeleccionadaId = id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulación seleccionada. Ya puedes iniciarla.'),
        ),
      );
    } on BackendApiException catch (error) {
      if (mounted) {
        setState(() => _errorBackend = error.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppTheme.canela,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operacionSimulacionEnCurso = false);
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
        nuevaSimulacion: _iniciarNuevaSimulacion,
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
          onGuardarSimulacion: _guardarSimulacion,
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
        simulacionesGuardadas: _simulacionesGuardadas,
        simulacionSeleccionadaId: _simulacionSeleccionadaId,
        alSeleccionarSimulacion: _seleccionarSimulacion,
      ),
      const _Ajustes(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.espresso,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.public_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('AR Sandbox'),
          ],
        ),
      ),
      body: IndexedStack(index: _seccion, children: pantallas),
      bottomNavigationBar: _BarraNavegacion(
        selectedIndex: switch (_seccion) {
          0 => 0,
          1 || 2 => 1,
          3 => 2,
          _ => 3,
        },
        onDestinationSelected: (index) => switch (index) {
          0 => _irA(0),
          1 => _iniciarNuevaSimulacion(),
          2 => _irA(3),
          _ => _irA(4),
        },
      ),
    );
  }
}

class _BarraNavegacion extends StatelessWidget {
  const _BarraNavegacion({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinos = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.add_rounded, Icons.add_rounded, 'Crear'),
    (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Guardadas'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(18, 0, 18, 8),
    child: PhysicalModel(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: AppTheme.texto.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.superficie.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.superficie.withValues(alpha: .95),
              ),
            ),
            child: Row(
              children: List.generate(_destinos.length, (index) {
                final (icono, iconoActivo, etiqueta) = _destinos[index];
                final activo = selectedIndex == index;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: activo,
                    label: etiqueta,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onDestinationSelected(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: activo
                                ? AppTheme.espresso.withValues(alpha: .09)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: activo ? 1.08 : 1,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  activo ? iconoActivo : icono,
                                  color: activo
                                      ? AppTheme.espresso
                                      : AppTheme.texto.withValues(alpha: .62),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  color: activo
                                      ? AppTheme.espresso
                                      : AppTheme.texto.withValues(alpha: .62),
                                  fontSize: 10.5,
                                  fontWeight: activo
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                                child: Text(etiqueta, maxLines: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Inicio extends StatelessWidget {
  const _Inicio({
    required this.terreno,
    required this.configuracion,
    required this.configuracionGuardada,
    required this.irA,
    required this.nuevaSimulacion,
  });

  final String? terreno;
  final ConfiguracionTerreno configuracion;
  final bool configuracionGuardada;
  final ValueChanged<int> irA;
  final VoidCallback nuevaSimulacion;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
    children: [
      Text(
        'Tu laboratorio de paisajes',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: AppTheme.texto, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Explora relieves, crea nuevas escenas y ajusta cada detalle.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppTheme.texto.withValues(alpha: .78)),
      ),
      const SizedBox(height: 18),
      _HeroSimulacion(onTap: nuevaSimulacion, terreno: terreno),
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
                    const Icon(Icons.history_rounded, color: AppTheme.canela),
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
    ],
  );
}

class _HeroSimulacion extends StatelessWidget {
  const _HeroSimulacion({required this.onTap, required this.terreno});
  final VoidCallback onTap;
  final String? terreno;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 650),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1).animate(animation),
        child: child,
      ),
    ),
    child: Container(
      key: ValueKey(terreno ?? 'default-terrain'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(ImagenTerreno.rutaPara(terreno)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            AppTheme.texto.withValues(alpha: .6),
            BlendMode.darken,
          ),
        ),
        gradient: const LinearGradient(
          colors: [AppTheme.espresso, AppTheme.cafe],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.espresso.withValues(alpha: .2),
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
                  color: AppTheme.caramelo,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Elige un relieve, personaliza su apariencia y guarda tu creación.',
            style: TextStyle(color: AppTheme.superficie.withValues(alpha: .95)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.caramelo,
                foregroundColor: AppTheme.texto,
              ),
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva simulación'),
            ),
          ),
        ],
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
        color: guardada ? AppTheme.espresso : AppTheme.canela,
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
    ('Montañas', 'Cumbres altas y pendientes pronunciadas.'),
    ('Valles', 'Depresiones suaves entre montañas.'),
    ('Volcanes', 'Relieves elevados con cráteres.'),
    ('Llanuras', 'Superficies amplias y casi planas.'),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.espresso.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.terrain_rounded,
                color: AppTheme.espresso,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Elige un relieve',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
        child: Text('Toca una opción para seleccionarla.'),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final anchoTarjeta = (constraints.maxWidth - 54) / 2;
            final altoAdaptable = anchoTarjeta * .9;
            final altoTarjeta = altoAdaptable < 160 ? 160.0 : altoAdaptable;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              itemCount: _terrenos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: altoTarjeta,
              ),
              itemBuilder: (context, index) {
                final (nombre, descripcion) = _terrenos[index];
                final activo = seleccionado == nombre;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: activo ? AppTheme.espresso : AppTheme.arena,
                      width: activo ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => alSeleccionar(nombre),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImagenTerreno(
                          terreno: nombre,
                          escala: activo ? 1.08 : 1,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: .02),
                                Colors.black.withValues(alpha: .78),
                              ],
                            ),
                          ),
                        ),
                        if (activo)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.caramelo,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AppTheme.texto,
                              ),
                            ),
                          ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                descripcion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.superficie.withValues(
                                        alpha: .95,
                                      ),
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
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
                        ? AppTheme.espresso
                        : AppTheme.canela,
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
          const Icon(
            Icons.landscape_outlined,
            size: 64,
            color: AppTheme.espresso,
          ),
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
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
    children: [
      Text(
        'Ajustes',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: AppTheme.texto, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Información de la aplicación y conexión.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppTheme.texto.withValues(alpha: .72)),
      ),
      SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.espresso,
            child: Icon(Icons.landscape, color: Colors.white),
          ),
          title: Text('AR Sandbox'),
          subtitle: Text('Explora y configura terrenos interactivos.'),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.dns_outlined, color: AppTheme.espresso),
          title: const Text('Dirección de FastAPI'),
          subtitle: Text(BackendConfig.baseUrl),
          trailing: const Icon(Icons.lan_outlined, color: AppTheme.salvia),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'En el emulador Android, 10.0.2.2 apunta a tu computadora. Para un dispositivo físico se necesita la IP local del equipo.',
          style: TextStyle(color: AppTheme.texto, height: 1.4),
        ),
      ),
      const SizedBox(height: 4),
      Card(
        child: ListTile(
          leading: Icon(Icons.info_outline, color: AppTheme.salvia),
          title: Text('Aplicación móvil'),
          subtitle: Text('AR Sandbox · Versión 1.0.0'),
        ),
      ),
    ],
  );
}
