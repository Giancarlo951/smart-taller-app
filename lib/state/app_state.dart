import 'package:flutter/widgets.dart';

import '../core/widgets/mensajes.dart';
import '../modules/avisos/services/aviso_service.dart';
import '../modules/cuentas/models/rol.dart';
import '../modules/cuentas/services/cuenta_service.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';

/// Pestañas de la barra inferior, en orden.
enum AppTab {
  inicio('Inicio'),
  ordenes('Órdenes'),
  citas('Citas'),
  stock('Stock'),
  mas('Más');

  const AppTab(this.label);
  final String label;
}

/// Resultado de intentar avanzar una orden.
enum ResultadoAvance { avanzada, sinPermiso, yaCompletada, error }

/// Estado de la interfaz (pestaña activa y rol elegido en el login) y
/// atajos a la sesión. Los datos viven en los servicios de lib/modules.
class AppState extends ChangeNotifier {
  AppState({CuentaService? cuenta, AvisoService? avisos})
    : cuenta = cuenta ?? CuentaService.instancia,
      avisos = avisos ?? AvisoService.instancia {
    this.cuenta.addListener(_alCambiarSesion);
    this.avisos.addListener(notifyListeners);
  }

  final CuentaService cuenta;
  final AvisoService avisos;

  Rol _rolElegido = Rol.jefeTaller;
  AppTab _tab = AppTab.inicio;

  bool get sesionIniciada => cuenta.sesionIniciada;

  /// Rol de la sesión; antes de ingresar, el elegido en el login (demo).
  Rol get rol => cuenta.sesionIniciada ? cuenta.rol : _rolElegido;

  AppTab get tab => _tab;

  int get notificacionesPendientes => avisos.sinLeer;

  /// Quién hace las acciones (permisos e historial de la orden).
  Actor get actor => Actor(
    rol: rol,
    nombre: cuenta.perfil?.nombre ?? '',
    uid: cuenta.perfil?.uid ?? '',
  );

  void _alCambiarSesion() {
    if (!cuenta.sesionIniciada) _tab = AppTab.inicio;
    notifyListeners();
  }

  @override
  void dispose() {
    cuenta.removeListener(_alCambiarSesion);
    avisos.removeListener(notifyListeners);
    super.dispose();
  }

  /// Rol del modo demo (con Firebase el rol viene de personal/{uid}).
  void seleccionarRol(Rol rol) {
    if (_rolElegido == rol) return;
    _rolElegido = rol;
    notifyListeners();
  }

  Future<void> iniciarSesion({required String usuario, required String contrasena}) async {
    await cuenta.ingresar(usuario: usuario, contrasena: contrasena, rolDemo: _rolElegido);
    _tab = AppTab.inicio;
    notifyListeners();
  }

  Future<void> cerrarSesion() => cuenta.cerrarSesion();

  void irATab(AppTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// "Registrar avance" con el resultado para la interfaz.
  Future<(ResultadoAvance, String?)> avanzar(Orden orden) async {
    if (orden.estado.siguienteEtapa == null) return (ResultadoAvance.yaCompletada, null);
    try {
      await OrdenService.instancia.avanzar(orden, actor: actor);
      return (ResultadoAvance.avanzada, null);
    } on StateError catch (e) {
      final sinPermiso = e.message.startsWith('Solo ');
      return (sinPermiso ? ResultadoAvance.sinPermiso : ResultadoAvance.error, mensajeError(e));
    }
  }
}

/// Expone [AppState] al árbol de widgets y reconstruye a quien lo lea.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Acceso sin suscribirse (para callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
