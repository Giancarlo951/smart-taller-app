import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/supabase_servicio.dart';

/// URL de la función de pagos (igual que `pagos_backend/` de la app de
/// referencia, desplegada en Vercel). Vacía = la tarjeta queda en modo demo.
///   flutter run --dart-define=PAGOS_URL=https://tu-proyecto.vercel.app
const urlServidorPagos = String.fromEnvironment('PAGOS_URL');

/// Cobro con tarjeta por Mercado Pago Checkout Pro. La clave secreta vive
/// solo en el servidor: la app pide el link de pago de la orden y lo abre;
/// el servidor marca la orden como pagada en Supabase (webhook).
class MercadoPagoService {
  MercadoPagoService({http.Client? cliente, String? urlBase})
    : _cliente = cliente ?? http.Client(),
      _urlBase = (urlBase ?? urlServidorPagos).replaceAll(RegExp(r'/$'), '');

  static final instancia = MercadoPagoService();

  final http.Client _cliente;
  final String _urlBase;

  /// Hace falta el servidor y Supabase (la orden debe existir en la base).
  bool get disponible => _urlBase.isNotEmpty && haySupabase;

  /// Link de Checkout Pro de la orden.
  Future<String> crearLinkDePago(String ordenId) async {
    final datos = await _post('/api/preferencia', {'ordenId': ordenId});
    final url = datos['urlPago'];
    if (url is! String || url.isEmpty) {
      throw StateError('Mercado Pago no devolvió el link de pago');
    }
    return url;
  }

  /// Consulta el pago en Mercado Pago y devuelve el paymentStatus de la
  /// orden (pending, paid o failed).
  Future<String> verificar(String ordenId) async {
    final datos = await _post('/api/verificar', {'ordenId': ordenId});
    return datos['estadoPago'] as String? ?? 'pending';
  }

  /// Abre el checkout dentro de la app (Custom Tabs); al cerrarlo se vuelve.
  Future<void> abrirCheckout(String url) async {
    final uri = Uri.parse(url);
    var abierto = false;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      // Algunos equipos no tienen navegador embebido.
    }
    if (!abierto) {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!abierto) throw StateError('No se pudo abrir Mercado Pago');
  }

  Future<Map<String, dynamic>> _post(String ruta, Map<String, Object?> cuerpo) async {
    if (_urlBase.isEmpty) {
      throw StateError('Falta configurar el servidor de pagos (PAGOS_URL)');
    }
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            Uri.parse('$_urlBase$ruta'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw StateError('El servidor de pagos no respondió, inténtalo de nuevo');
    } catch (_) {
      throw StateError('Sin conexión con el servidor de pagos');
    }
    Object? datos;
    try {
      datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } catch (_) {
      datos = null;
    }
    final mapa = datos is Map<String, dynamic> ? datos : <String, dynamic>{};
    if (respuesta.statusCode != 200) {
      throw StateError(
        mapa['error'] as String? ?? 'Error del servidor de pagos (${respuesta.statusCode})',
      );
    }
    return mapa;
  }
}
