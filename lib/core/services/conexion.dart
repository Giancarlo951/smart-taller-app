import 'dart:async';

import 'package:flutter/foundation.dart';

import 'comprobacion_internet.dart';

/// Estado de internet de toda la app (se comprueba cada 4 s).
/// [generacion] sube cada vez que la red vuelve.
class Conexion extends ChangeNotifier {
  Conexion._();

  static final instancia = Conexion._();

  /// Se puede sustituir en pruebas.
  static Future<bool> Function() verificar = hayInternet;

  bool? _enLinea;
  Timer? _reloj;
  bool _ocupado = false;
  bool _pendiente = false;

  bool get comprobado => _enLinea != null;
  bool get enLinea => _enLinea ?? false;

  /// Cambia al recuperar la conexión.
  int generacion = 0;

  void iniciar() {
    if (_reloj != null) return;
    comprobar();
    _reloj = Timer.periodic(const Duration(seconds: 4), (_) => comprobar());
  }

  void detener() {
    _reloj?.cancel();
    _reloj = null;
  }

  /// Deja el estado como al abrir la app. Solo para pruebas.
  void reiniciar() {
    detener();
    _enLinea = null;
    generacion = 0;
    _ocupado = false;
    _pendiente = false;
    verificar = hayInternet;
  }

  Future<bool> comprobar() async {
    if (_ocupado) {
      _pendiente = true;
      return enLinea;
    }
    _ocupado = true;
    final antes = _enLinea;
    var ok = false;
    try {
      ok = await verificar();
    } catch (_) {
      ok = false;
    }
    if (ok && antes == false) generacion++;
    _enLinea = ok;
    _ocupado = false;
    if (antes != ok) notifyListeners();
    if (_pendiente) {
      _pendiente = false;
      return comprobar();
    }
    return ok;
  }
}
