import '../../catalogo/models/adicional.dart';
import '../../catalogo/models/codigo_promocional.dart';
import '../../catalogo/models/servicio.dart';
import 'linea_cotizacion.dart';

/// Desglose de la orden en céntimos. Lo usan el borrador, la orden y la
/// facturación, así los montos coinciden siempre al céntimo.
class DesgloseOrden {
  const DesgloseOrden({
    required this.subtotal,
    required this.descuento,
    required this.recargo,
  });

  static const vacio = DesgloseOrden(subtotal: 0, descuento: 0, recargo: 0);

  final int subtotal;
  final int descuento;

  /// Servicio a domicilio / recojo del vehículo.
  final int recargo;

  /// total = subtotal − descuento + recargo
  int get total => subtotal - descuento + recargo;

  /// En Perú los precios ya incluyen IGV (18 %).
  int get igvIncluido => igvDe(total);

  /// Operación gravada (valor de venta sin IGV), como en el comprobante.
  int get opGravada => total - igvIncluido;

  static int igvDe(int total) => (total - total / 1.18).round();
}

/// Única fuente de verdad de los precios (con tests en test/).
class CalculadoraPrecios {
  CalculadoraPrecios._();

  /// precio = precio del tipo de vehículo × (1 − descuento %) + Σ adicionales
  static int precioServicio({
    required Servicio servicio,
    required String variante,
    Iterable<Adicional> adicionales = const [],
  }) =>
      servicio.aplicarDescuento(servicio.precio(variante).precioCentimos) +
      adicionales.fold(0, (suma, a) => suma + a.precioCentimos);

  /// subtotal = Σ precio × cantidad
  static int subtotal(Iterable<LineaCotizacion> lineas) =>
      lineas.fold(0, (suma, l) => suma + l.totalLineaCentimos);

  static int cantidadItems(Iterable<LineaCotizacion> lineas) =>
      lineas.fold(0, (suma, l) => suma + l.cantidad);

  static DesgloseOrden calcular({
    required Iterable<LineaCotizacion> lineas,
    int recargoCentimos = 0,
    CodigoPromocional? promo,
    DateTime? ahora,
  }) {
    if (lineas.isEmpty) return DesgloseOrden.vacio;
    final sub = subtotal(lineas);
    return DesgloseOrden(
      subtotal: sub,
      descuento: promo?.descuentoPara(sub, ahora: ahora) ?? 0,
      recargo: recargoCentimos,
    );
  }
}
