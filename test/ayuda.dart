import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tallersmart/core/services/sesion_service.dart';
import 'package:tallersmart/modules/avisos/services/aviso_service.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_service.dart';
import 'package:tallersmart/modules/citas/services/cita_service.dart';
import 'package:tallersmart/modules/clientes/services/cliente_service.dart';
import 'package:tallersmart/modules/cuentas/models/rol.dart';
import 'package:tallersmart/modules/cuentas/services/cuenta_service.dart';
import 'package:tallersmart/modules/ordenes/services/cotizacion_service.dart';
import 'package:tallersmart/modules/ordenes/services/orden_service.dart';

const jefe = Actor(rol: Rol.jefeTaller, nombre: 'Jefe');
const mecanico = Actor(rol: Rol.mecanico, nombre: 'Mecánico');
const administracion = Actor(rol: Rol.administracion, nombre: 'Admin');

/// Carga las fuentes reales (Ahem, la de los tests, es más ancha y desborda
/// de más).
Future<void> cargarFuentes() async {
  Future<void> cargar(String familia, List<String> archivos) async {
    final cargador = FontLoader(familia);
    for (final archivo in archivos) {
      cargador.addFont(rootBundle.load('assets/fonts/$archivo'));
    }
    await cargador.load();
  }

  await cargar('Barlow', ['Barlow-Regular.ttf', 'Barlow-Medium.ttf', 'Barlow-SemiBold.ttf']);
  await cargar('BarlowCondensed', ['BarlowCondensed-Medium.ttf', 'BarlowCondensed-SemiBold.ttf']);
}

/// Deja los servicios (modo local, sin Firebase) como al abrir la app.
Future<void> reiniciarTodo({DateTime? ahora}) async {
  SharedPreferences.setMockInitialValues({});
  await SesionService.instancia.iniciar();
  if (CuentaService.instancia.sesionIniciada) await CuentaService.instancia.cerrarSesion();
  CatalogoService.instancia.reiniciarLocal();
  OrdenService.instancia.reiniciarLocal(ahora: ahora);
  ClienteService.instancia.reiniciarLocal();
  CitaService.instancia.reiniciarLocal(hoy: ahora);
  AvisoService.instancia.reiniciarLocal();
  CotizacionService.instancia.vaciar(remoto: false);
}
