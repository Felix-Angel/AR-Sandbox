/// Conversión de los nombres mostrados en Flutter a los identificadores API.
class TerrenosApi {
  TerrenosApi._();

  static const Map<String, String> _idsPorNombre = {
    'Montañas': 'montanas',
    'Valles': 'valles',
    'Volcanes': 'volcanes',
    'Llanuras': 'llanuras',
  };

  static const Map<String, String> _nombresPorId = {
    'montanas': 'Montañas',
    'valles': 'Valles',
    'volcanes': 'Volcanes',
    'llanuras': 'Llanuras',
  };

  static const List<String> idsPermitidos = [
    'montanas',
    'valles',
    'volcanes',
    'llanuras',
  ];

  static String aId(String nombreVisible) {
    final id = _idsPorNombre[nombreVisible];
    if (id == null) {
      throw ArgumentError.value(
        nombreVisible,
        'nombreVisible',
        'Terreno no reconocido',
      );
    }
    return id;
  }

  static String aNombre(String id) {
    final nombre = _nombresPorId[id];
    if (nombre == null) {
      throw ArgumentError.value(
        id,
        'id',
        'Identificador de terreno no reconocido',
      );
    }
    return nombre;
  }
}

/// Nombres exactos de color admitidos por el backend.
class ColoresApi {
  ColoresApi._();

  static const List<String> permitidos = [
    'Verde bosque',
    'Terracota',
    'Crema',
    'Tinta',
    'Maíz',
    'Turquesa',
    'Bugambilia',
    'Café',
    'Gris',
  ];

  static String validar(String nombre) {
    if (!permitidos.contains(nombre)) {
      throw ArgumentError.value(nombre, 'nombre', 'Color no reconocido');
    }
    return nombre;
  }
}

/// Datos de configuración tal como los devuelve la API.
class ConfiguracionSimulacion {
  const ConfiguracionSimulacion({
    required this.terreno,
    required this.color,
    required this.altura,
  });

  /// Identificador del backend: montanas, valles, volcanes o llanuras.
  final String terreno;
  final String color;
  final double altura;

  String get nombreTerreno => TerrenosApi.aNombre(terreno);

  factory ConfiguracionSimulacion.fromJson(Map<String, dynamic> json) {
    final terreno = json['terreno'];
    final color = json['color'];
    final altura = json['altura'];
    if (terreno is! String || color is! String || altura is! num) {
      throw const FormatException(
        'La configuración recibida tiene campos inválidos.',
      );
    }
    if (!TerrenosApi.idsPermitidos.contains(terreno)) {
      throw FormatException('Terreno recibido no reconocido: $terreno');
    }
    ColoresApi.validar(color);
    if (altura < 0 || altura > 100) {
      throw FormatException('La altura recibida debe estar entre 0 y 100.');
    }
    return ConfiguracionSimulacion(
      terreno: terreno,
      color: color,
      altura: altura.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'terreno': terreno,
    'color': color,
    'altura': altura,
  };
}

/// Cuerpo exacto para POST /simulaciones/configuracion.
class SolicitudConfiguracion {
  const SolicitudConfiguracion({
    required this.terreno,
    required this.color,
    required this.altura,
  });

  /// Recibe el nombre visible que usa la interfaz (por ejemplo, Montañas).
  factory SolicitudConfiguracion.desdeInterfaz({
    required String terreno,
    required String color,
    required num altura,
  }) {
    if (altura < 0 || altura > 100) {
      throw ArgumentError.value(altura, 'altura', 'Debe estar entre 0 y 100');
    }
    return SolicitudConfiguracion(
      terreno: TerrenosApi.aId(terreno),
      color: ColoresApi.validar(color),
      altura: altura.toDouble(),
    );
  }

  /// Identificador exacto esperado por el backend.
  final String terreno;
  final String color;
  final double altura;

  Map<String, dynamic> toJson() => {
    'terreno': terreno,
    'color': color,
    'altura': altura,
  };
}
