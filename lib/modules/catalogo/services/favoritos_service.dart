import 'package:flutter/foundation.dart';

import '../../../core/services/sesion_service.dart';
import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';

/// Servicios favoritos del personal (accesos rápidos al armar una orden):
/// columna personal.favoritos, con copia en el dispositivo.
class FavoritosService extends ChangeNotifier {
  FavoritosService._();

  static final instancia = FavoritosService._();

  static const _claveLocal = 'favoritos';

  final Set<String> _ids = {};

  Set<String> get ids => Set.unmodifiable(_ids);

  bool esFavorito(String servicioId) => _ids.contains(servicioId);

  /// uid del personal con sesión (null sin Supabase).
  String? get _uid {
    final sesion = SesionService.instancia;
    if (!haySupabase || !sesion.cuentaVinculada) return null;
    return sesion.usuarioId;
  }

  Future<void> cargar() async {
    _ids
      ..clear()
      ..addAll(SesionService.instancia.preferencias?.getStringList(_claveLocal) ?? []);
    notifyListeners();
    final uid = _uid;
    if (uid == null) return;
    try {
      final fila = await supabase
          .from('personal')
          .select('favoritos')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final remotos = leerListaTextos(fila?['favoritos']);
      if (remotos.isNotEmpty) {
        _ids
          ..clear()
          ..addAll(remotos);
        _guardarLocal();
        notifyListeners();
      }
    } catch (_) {
      // sin conexión: se usan los favoritos locales
    }
  }

  void alternar(String servicioId) {
    _ids.contains(servicioId) ? _ids.remove(servicioId) : _ids.add(servicioId);
    notifyListeners();
    _guardarLocal();
    final uid = _uid;
    if (uid == null) return;
    supabase
        .from('personal')
        .update({'favoritos': _ids.toList()})
        .eq('id', uid)
        .then((_) {}, onError: (_) {});
  }

  /// Al cerrar sesión.
  void reiniciar() {
    _ids.clear();
    notifyListeners();
  }

  void _guardarLocal() {
    SesionService.instancia.preferencias?.setStringList(_claveLocal, _ids.toList());
  }
}
