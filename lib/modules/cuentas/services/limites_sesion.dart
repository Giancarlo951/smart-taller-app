import 'package:shared_preferences/shared_preferences.dart';

/// Guía 12: cuándo se cierra sola la sesión del personal.
///
/// El celular del mostrador suele quedar a la vista de todos: si nadie lo
/// toca o la app se minimiza y nadie vuelve, la sesión se cierra.
class LimitesSesion {
  LimitesSesion._();

  /// 12.4: sin tocar la pantalla este tiempo, aparece "¿Sigues ahí?".
  static const inactividad = Duration(minutes: 5);

  /// Tiempo del aviso antes de cerrar la sesión.
  static const aviso = Duration(seconds: 30);

  /// 12.2: minimizada más de esto, al volver la sesión ya está cerrada.
  /// No es inmediato para poder revisar un Yape y regresar.
  static const enSegundoPlano = Duration(minutes: 1);

  /// Cuándo se minimizó (por si Android cierra la app mientras tanto).
  static const _claveFondo = 'sesionEnSegundoPlanoDesde';

  static Future<void> marcarSegundoPlano(SharedPreferences? preferencias, DateTime desde) async =>
      preferencias?.setInt(_claveFondo, desde.millisecondsSinceEpoch);

  static Future<void> limpiarSegundoPlano(SharedPreferences? preferencias) async =>
      preferencias?.remove(_claveFondo);

  /// true si la app se minimizó con la sesión abierta y pasó el límite.
  static bool vencioEnSegundoPlano(SharedPreferences? preferencias, DateTime ahora) {
    final desde = preferencias?.getInt(_claveFondo);
    if (desde == null) return false;
    return ahora.difference(DateTime.fromMillisecondsSinceEpoch(desde)) >= enSegundoPlano;
  }
}
