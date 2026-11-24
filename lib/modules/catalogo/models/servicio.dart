import '../../../core/utils/formatos.dart';

/// Tipos de vehículo: el precio de la mano de obra cambia según el tamaño
/// del vehículo (equivale al tamaño de la pizza en la app de referencia).
abstract final class TiposVehiculo {
  static const auto = 'auto';
  static const suv = 'suv';
  static const pesado = 'pesado';

  static const claves = [auto, suv, pesado];

  static const etiquetas = {
    auto: 'Auto / sedán',
    suv: 'SUV / camioneta',
    pesado: 'Minivan / furgón',
  };

  static String etiqueta(String clave) => etiquetas[clave] ?? clave;
}

/// Precio y tiempo estimado de un servicio para un tipo de vehículo.
class PrecioVehiculo {
  const PrecioVehiculo({
    required this.clave,
    required this.precioCentimos,
    this.minutos = 60,
  });

  final String clave;
  final int precioCentimos;

  /// Tiempo estimado en bahía (para la hora de entrega).
  final int minutos;

  String get etiqueta => TiposVehiculo.etiqueta(clave);

  factory PrecioVehiculo.desdeMapa(String clave, Map<String, dynamic> datos) =>
      PrecioVehiculo(
        clave: clave,
        precioCentimos: leerInt(datos['precio_centimos']),
        minutos: datos['minutos'] == null ? 60 : leerInt(datos['minutos']),
      );

  Map<String, dynamic> aMapa() => {
    'precio_centimos': precioCentimos,
    'minutos': minutos,
  };

  PrecioVehiculo copyWith({int? precioCentimos, int? minutos}) => PrecioVehiculo(
    clave: clave,
    precioCentimos: precioCentimos ?? this.precioCentimos,
    minutos: minutos ?? this.minutos,
  );
}

/// Servicio del taller (colección servicios): mano de obra con precio por
/// tipo de vehículo, descuento, adicionales y disponibilidad.
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    this.subtitulo = '',
    this.descripcion = '',
    this.categoriaIds = const [],
    required this.precios,
    this.descuentoPorcentaje,
    this.disponible = true,
    this.popular = false,
    this.adicionalIds = const [],
    this.garantiaDias = 0,
    this.intervaloKm = 0,
  });

  final String id;
  final String nombre;
  final String subtitulo;
  final String descripcion;
  final List<String> categoriaIds;
  final Map<String, PrecioVehiculo> precios;
  final int? descuentoPorcentaje;
  final bool disponible;
  final bool popular;
  final List<String> adicionalIds;
  final int garantiaDias;

  /// Cada cuántos km se recomienda repetirlo (0 = no aplica).
  final int intervaloKm;

  bool get tieneDescuento => (descuentoPorcentaje ?? 0) > 0;

  /// precio × (1 − descuento %)
  int aplicarDescuento(int precioCentimos) => tieneDescuento
      ? (precioCentimos * (100 - descuentoPorcentaje!) / 100).round()
      : precioCentimos;

  /// Precio para [clave]; si ese tipo no tiene precio, el primero que haya.
  PrecioVehiculo precio(String clave) =>
      precios[clave] ??
      precios[TiposVehiculo.auto] ??
      (precios.isEmpty
          ? PrecioVehiculo(clave: clave, precioCentimos: 0)
          : precios.values.first);

  bool tienePrecioPara(String clave) => precios.containsKey(clave);

  String get varianteInicial => precios.containsKey(TiposVehiculo.auto)
      ? TiposVehiculo.auto
      : (precios.keys.isEmpty ? TiposVehiculo.auto : precios.keys.first);

  /// Precio más bajo con descuento ("desde S/ 40.00").
  int get precioDesdeCentimos {
    if (precios.isEmpty) return 0;
    final minimo = precios.values
        .map((p) => p.precioCentimos)
        .reduce((a, b) => a < b ? a : b);
    return aplicarDescuento(minimo);
  }

  /// Próximo mantenimiento sugerido a partir del km actual.
  int? proximoKm(int kmActual) =>
      intervaloKm > 0 ? kmActual + intervaloKm : null;

  Servicio copyWith({
    String? id,
    String? nombre,
    String? subtitulo,
    String? descripcion,
    List<String>? categoriaIds,
    Map<String, PrecioVehiculo>? precios,
    int? descuentoPorcentaje,
    bool quitarDescuento = false,
    bool? disponible,
    bool? popular,
    List<String>? adicionalIds,
    int? garantiaDias,
    int? intervaloKm,
  }) => Servicio(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    subtitulo: subtitulo ?? this.subtitulo,
    descripcion: descripcion ?? this.descripcion,
    categoriaIds: categoriaIds ?? this.categoriaIds,
    precios: precios ?? this.precios,
    descuentoPorcentaje: quitarDescuento
        ? null
        : descuentoPorcentaje ?? this.descuentoPorcentaje,
    disponible: disponible ?? this.disponible,
    popular: popular ?? this.popular,
    adicionalIds: adicionalIds ?? this.adicionalIds,
    garantiaDias: garantiaDias ?? this.garantiaDias,
    intervaloKm: intervaloKm ?? this.intervaloKm,
  );

  /// Fila de la tabla servicios.
  factory Servicio.desdeMapa(Map<String, dynamic> fila) {
    final precios = leerMapa(fila['precios']);
    final descuento = fila['descuento_porcentaje'];
    return Servicio(
      id: '${fila['id']}',
      nombre: fila['nombre'] ?? '',
      subtitulo: fila['subtitulo'] ?? '',
      descripcion: fila['descripcion'] ?? '',
      categoriaIds: leerListaTextos(fila['categoria_ids']),
      precios: {
        for (final clave in TiposVehiculo.claves)
          if (precios[clave] is Map)
            clave: PrecioVehiculo.desdeMapa(clave, leerMapa(precios[clave])),
      },
      descuentoPorcentaje: descuento is num && descuento > 0 ? descuento.toInt() : null,
      disponible: fila['disponible'] != false,
      popular: fila['popular'] == true,
      adicionalIds: leerListaTextos(fila['adicional_ids']),
      garantiaDias: leerInt(fila['garantia_dias']),
      intervaloKm: leerInt(fila['intervalo_km']),
    );
  }

  /// Columnas a guardar. Sin id, la base genera uno.
  Map<String, dynamic> aMapa() => {
    if (id.isNotEmpty) 'id': id,
    'nombre': nombre,
    'subtitulo': subtitulo,
    'descripcion': descripcion,
    'categoria_ids': categoriaIds,
    'precios': {for (final p in precios.values) p.clave: p.aMapa()},
    'descuento_porcentaje': descuentoPorcentaje,
    'disponible': disponible,
    'popular': popular,
    'adicional_ids': adicionalIds,
    'garantia_dias': garantiaDias,
    'intervalo_km': intervaloKm,
  };
}
