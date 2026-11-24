import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Sesión del dispositivo. Con cuenta (Supabase Auth) el usuario es su uid
/// (personal/{uid}); sin Supabase, un id aleatorio del dispositivo.
class SesionService {
  SesionService._();

  static final instancia = SesionService._();

  static const _claveDispositivo = 'dispositivoId';

  SharedPreferences? _preferencias;

  /// uid del personal (con Supabase) o id del dispositivo (modo local).
  String usuarioId = '';

  /// true solo con uid de Supabase Auth.
  bool cuentaVinculada = false;

  SharedPreferences? get preferencias => _preferencias;

  Future<void> iniciar() async {
    try {
      _preferencias = await SharedPreferences.getInstance();
    } catch (_) {
      _preferencias = null; // sin almacenamiento local: sesión en memoria
    }
    usuarioId = _preferencias?.getString(_claveDispositivo) ?? '';
    if (usuarioId.isEmpty) {
      usuarioId = _generarId();
      await _preferencias?.setString(_claveDispositivo, usuarioId);
    }
  }

  /// Personal con cuenta: borrador, favoritos y avisos van con su uid.
  void usarCuenta(String uid) {
    usuarioId = uid;
    cuentaVinculada = true;
  }

  /// Cerrar sesión: borra los datos de este dispositivo y genera otro id.
  Future<void> cerrarSesion() async {
    cuentaVinculada = false;
    await _preferencias?.clear();
    usuarioId = _generarId();
    await _preferencias?.setString(_claveDispositivo, usuarioId);
  }

  static String _generarId() {
    const caracteres =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final aleatorio = Random.secure();
    return List.generate(
      20,
      (_) => caracteres[aleatorio.nextInt(caracteres.length)],
    ).join();
  }
}
