import '../../../core/utils/formatos.dart';

/// Código de descuento o campaña del taller (tabla codigos_promocionales,
/// clave = código): porcentaje o monto fijo (céntimos).
class CodigoPromocional {
  const CodigoPromocional({
    required this.codigo,
    required this.tipo,
    required this.valor,
    this.minimoSubtotalCentimos = 0,
    this.activo = true,
    this.venceEn,
    this.maxUsos = 0,
    this.usados = 0,
    this.descripcion = '',
  });

  static const porcentaje = 'porcentaje';
  static const fijo = 'fijo';

  final String codigo;
  final String tipo; // porcentaje, fijo
  final int valor; // % o céntimos
  final int minimoSubtotalCentimos;
  final bool activo;
  final DateTime? venceEn;
  final int maxUsos; // 0 = ilimitado
  final int usados;
  final String descripcion;

  bool get esPorcentaje => tipo == porcentaje;

  String get resumen => esPorcentaje
      ? '$valor% de descuento'
      : '${formatoCentimos(valor)} de descuento';

  /// Mensaje de error o null si el código se puede usar con ese subtotal.
  String? validar(int subtotalCentimos, {DateTime? ahora}) {
    if (!activo) return 'El código $codigo no está activo';
    if (venceEn != null && (ahora ?? DateTime.now()).isAfter(venceEn!)) {
      return 'El código $codigo ya venció';
    }
    if (maxUsos > 0 && usados >= maxUsos) {
      return 'El código $codigo alcanzó su límite de usos';
    }
    if (subtotalCentimos < minimoSubtotalCentimos) {
      return 'Monto mínimo de ${formatoCentimos(minimoSubtotalCentimos)}';
    }
    return null;
  }

  /// Descuento en céntimos (nunca mayor al subtotal).
  int descuentoPara(int subtotalCentimos, {DateTime? ahora}) {
    if (validar(subtotalCentimos, ahora: ahora) != null) return 0;
    final descuento = esPorcentaje
        ? (subtotalCentimos * valor / 100).round()
        : valor;
    return descuento.clamp(0, subtotalCentimos);
  }

  /// Descuento de un código que la orden ya usó (al editar sus líneas): solo
  /// mira el monto mínimo, no la vigencia ni los usos. Igual que
  /// `_descuento_promo` en supabase/esquema.sql.
  int descuentoYaAplicado(int subtotalCentimos) {
    if (subtotalCentimos < minimoSubtotalCentimos) return 0;
    final descuento = esPorcentaje ? (subtotalCentimos * valor / 100).round() : valor;
    return descuento.clamp(0, subtotalCentimos);
  }

  CodigoPromocional copyWith({int? usados}) => CodigoPromocional(
    codigo: codigo,
    tipo: tipo,
    valor: valor,
    minimoSubtotalCentimos: minimoSubtotalCentimos,
    activo: activo,
    venceEn: venceEn,
    maxUsos: maxUsos,
    usados: usados ?? this.usados,
    descripcion: descripcion,
  );

  /// Fila de la tabla codigos_promocionales.
  factory CodigoPromocional.desdeMapa(Map<String, dynamic> fila) => CodigoPromocional(
    codigo: '${fila['codigo']}',
    tipo: fila['tipo'] ?? porcentaje,
    valor: leerInt(fila['valor']),
    minimoSubtotalCentimos: leerInt(fila['minimo_subtotal_centimos']),
    activo: fila['activo'] != false,
    venceEn: leerFechaOpcional(fila['vence_en']),
    maxUsos: leerInt(fila['max_usos']),
    usados: leerInt(fila['usados']),
    descripcion: fila['descripcion'] ?? '',
  );

  Map<String, dynamic> aMapa() => {
    'codigo': codigo,
    'tipo': tipo,
    'valor': valor,
    'minimo_subtotal_centimos': minimoSubtotalCentimos,
    'activo': activo,
    'vence_en': venceEn == null ? null : fechaIso(venceEn!),
    'max_usos': maxUsos,
    'usados': usados,
    'descripcion': descripcion,
  };
}
