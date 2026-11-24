import '../../../core/utils/formatos.dart';

enum TipoAviso {
  stock('stock', 'Stock'),
  orden('orden', 'Orden'),
  cita('cita', 'Cita'),
  pago('pago', 'Pago'),
  facturacion('facturacion', 'Facturación');

  const TipoAviso(this.valor, this.label);
  final String valor;
  final String label;

  static TipoAviso desde(String? valor) => TipoAviso.values.firstWhere(
    (t) => t.valor == valor || t.name == valor,
    orElse: () => TipoAviso.orden,
  );
}

/// Aviso interno del taller (tabla avisos). Equivale a las
/// notificaciones de cambio de estado de la app de referencia.
class Aviso {
  const Aviso({
    this.id = '',
    required this.tipo,
    required this.texto,
    required this.fecha,
    this.ordenId,
    this.leidoPor = const [],
  });

  final String id;
  final TipoAviso tipo;
  final String texto;
  final DateTime fecha;
  final String? ordenId;

  /// uid (o id del dispositivo) de quienes ya lo vieron ('*' = todos).
  final List<String> leidoPor;

  bool leidoPara(String usuarioId) =>
      leidoPor.contains('*') || leidoPor.contains(usuarioId);

  /// "hace 10 min", "ayer"...
  String hora({DateTime? ahora}) => tiempoRelativo(fecha, ahora: ahora).toLowerCase();

  Aviso copyWith({String? id, List<String>? leidoPor}) => Aviso(
    id: id ?? this.id,
    tipo: tipo,
    texto: texto,
    fecha: fecha,
    ordenId: ordenId,
    leidoPor: leidoPor ?? this.leidoPor,
  );

  /// Fila de la tabla avisos.
  factory Aviso.desdeMapa(Map<String, dynamic> fila) => Aviso(
    id: '${fila['id'] ?? ''}',
    tipo: TipoAviso.desde(fila['tipo']),
    texto: fila['texto'] ?? '',
    fecha: leerFecha(fila['created_at']),
    ordenId: fila['orden_id'],
    leidoPor: leerListaTextos(fila['leido_por']),
  );

  /// Columnas al crearlo (id y fecha los pone la base).
  Map<String, dynamic> aMapa() => {
    'tipo': tipo.valor,
    'texto': texto,
    'orden_id': ordenId,
    'leido_por': leidoPor,
  };
}
