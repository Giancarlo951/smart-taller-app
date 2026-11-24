import '../models/orden.dart';
import 'mercado_pago_service.dart';

/// Modo demo: sin servidor de pagos (PAGOS_URL) la tarjeta simula un cobro
/// exitoso tras 1.2 s. Con servidor se cobra con Mercado Pago Checkout Pro.
bool get kPagosDemo => !MercadoPagoService.instancia.disponible;

/// Resultado del cobro: estado que se guarda en paymentStatus.
class ResultadoPago {
  const ResultadoPago({required this.estadoPago, this.referencia});

  final String estadoPago; // pending, pending_verification, paid
  final String? referencia; // N.° de operación Yape/Plin
}

/// Interfaz común de los medios de pago.
abstract class ServicioPago {
  const ServicioPago();

  String get metodo;

  Future<ResultadoPago> procesar({required int totalCentimos, String? referencia});

  factory ServicioPago.para(String metodo) => switch (metodo) {
    MetodosPago.yape || MetodosPago.plin => PagoYapePlin(metodo),
    MetodosPago.tarjeta => const PagoTarjeta(),
    _ => const PagoEfectivo(),
  };
}

/// Efectivo en caja: el cliente paga en el mostrador al recoger el vehículo,
/// así que queda pagado al registrarlo.
class PagoEfectivo extends ServicioPago {
  const PagoEfectivo();

  @override
  String get metodo => MetodosPago.efectivo;

  @override
  Future<ResultadoPago> procesar({required int totalCentimos, String? referencia}) async =>
      const ResultadoPago(estadoPago: EstadosPago.pagado);
}

/// Yape/Plin: el cliente paga al número del taller y se registra el N.° de
/// operación; administración lo verifica y aprueba (pending_verification).
class PagoYapePlin extends ServicioPago {
  const PagoYapePlin(this.metodo);

  @override
  final String metodo;

  @override
  Future<ResultadoPago> procesar({required int totalCentimos, String? referencia}) async {
    if (referencia == null || referencia.trim().isEmpty) {
      throw StateError('Ingresa el número de operación del pago');
    }
    return ResultadoPago(estadoPago: EstadosPago.verificando, referencia: referencia.trim());
  }
}

/// Tarjeta con Mercado Pago Checkout Pro. La orden queda "por cobrar" y se
/// abre el checkout; el servidor la marca pagada. En modo demo simula el cobro.
class PagoTarjeta extends ServicioPago {
  const PagoTarjeta();

  @override
  String get metodo => MetodosPago.tarjeta;

  /// true si el cobro sigue en Mercado Pago después de registrarlo.
  static bool get cobraConMercadoPago => !kPagosDemo;

  @override
  Future<ResultadoPago> procesar({required int totalCentimos, String? referencia}) async {
    if (cobraConMercadoPago) return const ResultadoPago(estadoPago: EstadosPago.porCobrar);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return const ResultadoPago(estadoPago: EstadosPago.pagado);
  }
}
