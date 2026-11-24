import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/sesion_service.dart';
import '../../../core/services/supabase_servicio.dart';
import '../models/aviso.dart';

/// Avisos del taller en tiempo real (tabla avisos). Las órdenes, el
/// inventario, los pagos y la facturación los generan solos (como los
/// mensajes de estado que recibía el cliente en la app de referencia).
class AvisoService extends ChangeNotifier {
  AvisoService._();

  static final instancia = AvisoService._();

  static const limite = 50;

  List<Aviso> _avisos = avisosDeEjemplo();
  StreamSubscription<Object?>? _suscripcion;

  String get _usuario => SesionService.instancia.usuarioId;

  /// Más recientes primero.
  List<Aviso> get avisos => List.unmodifiable(_avisos);

  int get sinLeer => _avisos.where((a) => !a.leidoPara(_usuario)).length;

  /// Avisos de ejemplo del modo local (sin Supabase).
  static List<Aviso> avisosDeEjemplo({DateTime? ahora}) {
    final hoy = ahora ?? DateTime.now();
    return [
      Aviso(
        id: 'local-a1',
        tipo: TipoAviso.stock,
        fecha: hoy.subtract(const Duration(minutes: 10)),
        texto: 'Líquido de frenos DOT4 quedó en 2 unidades, por debajo del mínimo de 12.',
      ),
      Aviso(
        id: 'local-a2',
        tipo: TipoAviso.orden,
        fecha: hoy.subtract(const Duration(minutes: 35)),
        texto: 'OT-1041 pasó a reparación. Entrega estimada: mañana 10:00.',
      ),
      Aviso(
        id: 'local-a3',
        tipo: TipoAviso.cita,
        fecha: hoy.subtract(const Duration(hours: 2)),
        texto: 'Sara Huamán confirmó su cita de mantenimiento para las 17:00.',
      ),
      Aviso(
        id: 'local-a4',
        tipo: TipoAviso.facturacion,
        fecha: hoy.subtract(const Duration(days: 1)),
        texto: 'Comprobante B001-00247 aceptado por SUNAT.',
        leidoPor: const ['*'],
      ),
    ];
  }

  /// Con Supabase: escucha los últimos avisos. Sin Supabase: los de ejemplo.
  void iniciar() {
    if (!haySupabase || _suscripcion != null) return;
    _avisos = [];
    notifyListeners();
    _suscripcion = supabase
        .from('avisos')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .limit(limite)
        .listen((filas) {
          _avisos = filas.map(Aviso.desdeMapa).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
          notifyListeners();
        }, onError: (_) {});
  }

  /// Vuelve a los avisos de ejemplo. Solo para pruebas y al cerrar sesión.
  void reiniciarLocal() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _avisos = avisosDeEjemplo();
    notifyListeners();
  }

  /// Registra un aviso. No lanza errores: un aviso nunca debe frenar una
  /// orden o un cobro.
  Future<void> registrar(TipoAviso tipo, String texto, {String? ordenId}) async {
    final aviso = Aviso(tipo: tipo, texto: texto, fecha: DateTime.now(), ordenId: ordenId);
    if (!haySupabase) {
      _avisos = [
        aviso.copyWith(id: 'local-${DateTime.now().microsecondsSinceEpoch}'),
        ..._avisos,
      ].take(limite).toList();
      notifyListeners();
      return;
    }
    try {
      await supabase.from('avisos').insert(aviso.aMapa()).timeout(const Duration(seconds: 10));
    } catch (_) {
      // sin permisos o sin conexión: el aviso se pierde, la acción no
    }
  }

  /// Marca todos como leídos para el usuario actual.
  Future<void> marcarLeidos() async {
    final usuario = _usuario;
    final pendientes = _avisos.where((a) => !a.leidoPara(usuario)).toList();
    if (pendientes.isEmpty) return;
    _avisos = [
      for (final a in _avisos)
        a.leidoPara(usuario) ? a : a.copyWith(leidoPor: [...a.leidoPor, usuario]),
    ];
    notifyListeners();
    if (!haySupabase) return;
    try {
      await supabase.rpc('marcar_avisos_leidos');
    } catch (_) {
      // sin conexión: se vuelven a marcar la próxima vez
    }
  }
}
