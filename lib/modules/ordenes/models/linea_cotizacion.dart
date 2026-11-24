import '../../../core/utils/formatos.dart';
import '../../catalogo/models/servicio.dart';

/// Línea del borrador de una orden (equivale al ítem del carrito): un
/// servicio para un tipo de vehículo, con adicionales, o un repuesto.
class LineaCotizacion {
  const LineaCotizacion({
    required this.id,
    required this.tipo,
    required this.refId,
    required this.nombre,
    this.variante = '',
    this.adicionalIds = const [],
    required this.precioUnitarioCentimos,
    required this.cantidad,
    required this.agregadoEn,
  });

  static const tipoServicio = 'servicio';
  static const tipoRepuesto = 'repuesto';

  final String id;

  /// servicio o repuesto.
  final String tipo;

  /// Id del servicio o código del repuesto.
  final String refId;
  final String nombre;

  /// Tipo de vehículo (solo servicios).
  final String variante;
  final List<String> adicionalIds;
  final int precioUnitarioCentimos;
  final int cantidad;
  final DateTime agregadoEn;

  bool get esServicio => tipo == tipoServicio;
  bool get esRepuesto => tipo == tipoRepuesto;

  int get totalLineaCentimos => precioUnitarioCentimos * cantidad;

  String get etiquetaVariante =>
      esServicio ? TiposVehiculo.etiqueta(variante) : refId;

  /// La misma combinación (tipo, ítem, vehículo, adicionales) es una sola
  /// línea: al agregarla otra vez se suman las unidades.
  static String generarId(
    String tipo,
    String refId, {
    String variante = '',
    List<String> adicionales = const [],
  }) {
    final ordenados = [...adicionales]..sort();
    return [tipo, refId, variante, ...ordenados].where((p) => p.isNotEmpty).join('_');
  }

  LineaCotizacion copyWith({
    String? id,
    String? variante,
    List<String>? adicionalIds,
    int? precioUnitarioCentimos,
    int? cantidad,
  }) => LineaCotizacion(
    id: id ?? this.id,
    tipo: tipo,
    refId: refId,
    nombre: nombre,
    variante: variante ?? this.variante,
    adicionalIds: adicionalIds ?? this.adicionalIds,
    precioUnitarioCentimos: precioUnitarioCentimos ?? this.precioUnitarioCentimos,
    cantidad: cantidad ?? this.cantidad,
    agregadoEn: agregadoEn,
  );

  /// Elemento de personal.borrador (JSON).
  factory LineaCotizacion.desdeMapa(Map<String, dynamic> datos) => LineaCotizacion(
    id: datos['id'] ?? '',
    tipo: datos['tipo'] ?? tipoServicio,
    refId: datos['ref_id'] ?? '',
    nombre: datos['nombre'] ?? '',
    variante: datos['variante'] ?? '',
    adicionalIds: leerListaTextos(datos['adicional_ids']),
    precioUnitarioCentimos: leerInt(datos['precio_unitario_centimos']),
    cantidad: leerInt(datos['cantidad']),
    agregadoEn: leerFecha(datos['agregado_en']),
  );

  Map<String, dynamic> aMapa() => {
    'id': id,
    'tipo': tipo,
    'ref_id': refId,
    'nombre': nombre,
    'variante': variante,
    'adicional_ids': adicionalIds,
    'precio_unitario_centimos': precioUnitarioCentimos,
    'cantidad': cantidad,
    'agregado_en': fechaIso(agregadoEn),
  };
}
