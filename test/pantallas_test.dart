import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tallersmart/main.dart';
import 'package:tallersmart/modules/catalogo/models/servicio.dart';
import 'package:tallersmart/modules/ordenes/services/orden_service.dart';
import 'package:tallersmart/screens/catalogo_servicios_screen.dart';
import 'package:tallersmart/screens/clientes_screen.dart';
import 'package:tallersmart/screens/facturacion_screen.dart';
import 'package:tallersmart/screens/inventario_screen.dart';
import 'package:tallersmart/screens/notificaciones_screen.dart';
import 'package:tallersmart/screens/nueva_orden_screen.dart';
import 'package:tallersmart/screens/orden_detalle_screen.dart';
import 'package:tallersmart/screens/perfil_screen.dart';
import 'package:tallersmart/screens/reportes_screen.dart';
import 'package:tallersmart/screens/selector_catalogo.dart';
import 'package:tallersmart/state/app_state.dart';
import 'package:tallersmart/theme/industry_theme.dart';
import 'package:tallersmart/widgets/comunes.dart';
import 'package:tallersmart/widgets/ind_bottom_bar.dart';
import 'package:tallersmart/widgets/ind_side_bar.dart';

import 'ayuda.dart';

/// Prueba de humo del diseño: abre cada pantalla y hoja en un celular
/// angosto (360 px) y en una PC (1280 px). Falla si algo desborda o lanza al
/// construirse.
void main() {
  setUpAll(cargarFuentes);
  setUp(reiniciarTodo);

  testWidgets('pantallas y hojas caben en un celular de 360 px', (tester) async {
    await _recorrerTodo(tester, const Size(360, 740));
    // Celular: barra inferior, sin barra lateral.
    expect(find.byType(IndBottomBar), findsOneWidget);
    expect(find.byType(IndSideBar), findsNothing);
  });

  testWidgets('pantallas y hojas se ven bien en una PC de 1280 px', (tester) async {
    await _recorrerTodo(tester, const Size(1280, 800));
    // PC: barra lateral en lugar de la inferior y contenido centrado.
    expect(find.byType(IndSideBar), findsOneWidget);
    expect(find.byType(IndBottomBar), findsNothing);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    final lista = tester.getRect(find.byType(ListView).first);
    final banner = tester.getRect(find.text('Resumen del taller'));
    expect(lista.width, greaterThan(Ind.anchoContenido), reason: 'la página ocupa todo el ancho libre');
    expect(banner.left - lista.left, greaterThan(16), reason: 'el contenido queda centrado con margen');
  });
}

/// Ingresa como administración y abre cada pantalla, pestaña y hoja.
Future<void> _recorrerTodo(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // OT-1041 lista para entrega: así el detalle muestra el cobro.
  final ot1041 = OrdenService.instancia.locales.firstWhere((o) => o.codigo == 'OT-1041');
  await OrdenService.instancia.avanzar(ot1041, actor: jefe);

  await tester.pumpWidget(SmartTallerApp(state: AppState()));
  await tester.tap(find.text('Administración'));
  await tester.pump();
  await tester.enterText(find.byType(TextFormField).at(1), 'secreto');
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'Inicio');

  final contexto = tester.element(find.text('Resumen del taller'));
  final nav = Navigator.of(contexto);

  Future<void> revisar(String nombre) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: nombre);
  }

  // — Pantallas —
  final pantallas = <String, Widget>{
    for (final o in OrdenService.instancia.locales) 'Detalle ${o.codigo}': OrdenDetalleScreen(ordenId: o.id),
    'Nueva orden': const NuevaOrdenScreen(placaInicial: 'V2K-841'),
    'Clientes': const ClientesScreen(),
    'Cliente': const ClienteDetalleScreen(clienteId: 'local-c5'),
    'Catálogo': const CatalogoServiciosScreen(),
    'Inventario': const InventarioScreen(),
    'Facturación': const FacturacionScreen(),
    'Reportes': const ReportesScreen(),
    'Notificaciones': const NotificacionesScreen(),
    'Perfil': const PerfilScreen(),
  };
  for (final MapEntry(key: nombre, value: pantalla) in pantallas.entries) {
    nav.push(MaterialPageRoute(builder: (_) => pantalla));
    await revisar(nombre);
    nav.pop();
    await revisar('$nombre (al cerrar)');
  }

  // — Pestañas —
  for (final tab in ['Órdenes', 'Citas', 'Stock', 'Más', 'Inicio']) {
    await tester.tap(find.text(tab));
    await revisar('Pestaña $tab');
  }

  // — Hojas —
  abrirSelectorCatalogo(contexto,
      tipoVehiculo: TiposVehiculo.auto, alAgregarServicio: (_, _, _) {}, alAgregarRepuesto: (_, _) {});
  await revisar('Catálogo: servicios');
  await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Repuestos')));
  await revisar('Catálogo: repuestos');
  nav.pop();
  await revisar('Catálogo (al cerrar)');

  for (final (nombre, hoja) in [
    ('Nuevo servicio', const FormularioServicio()),
    ('Nuevo repuesto', const FormularioRepuesto()),
    ('Comprobante', HojaComprobante(orden: OrdenService.instancia.locales.first)),
  ]) {
    mostrarHoja<void>(contexto, hoja);
    await revisar(nombre);
    nav.pop();
    await revisar('$nombre (al cerrar)');
  }
  abrirFormularioCliente(contexto);
  await revisar('Registrar cliente');
  nav.pop();
  await revisar('Registrar cliente (al cerrar)');

  // Cobro de OT-1041 desde su detalle, con Yape elegido.
  nav.push(MaterialPageRoute(builder: (_) => OrdenDetalleScreen(ordenId: ot1041.id)));
  await revisar('Detalle OT-1041 lista');
  final cobrar = find.textContaining('Cobrar S/');
  // La última lista desplazable es la del detalle (en PC la barra lateral también se desplaza).
  await tester.scrollUntilVisible(cobrar, 300, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(cobrar);
  await tester.pumpAndSettle();
  await tester.tap(cobrar);
  await revisar('Cobro');
  await tester.tap(find.text('Yape'));
  await revisar('Cobro con Yape');
  nav.pop(); // hoja de cobro
  nav.pop(); // detalle de OT-1041
  await revisar('De vuelta en Inicio');
}
