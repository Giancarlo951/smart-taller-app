import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tallersmart/main.dart';
import 'package:tallersmart/modules/cuentas/models/rol.dart';
import 'package:tallersmart/modules/cuentas/services/cuenta_service.dart';
import 'package:tallersmart/modules/ordenes/models/orden.dart';
import 'package:tallersmart/modules/ordenes/services/orden_service.dart';
import 'package:tallersmart/state/app_state.dart';

import 'ayuda.dart';

void main() {
  setUpAll(cargarFuentes);

  setUp(reiniciarTodo);

  Future<AppState> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.pumpWidget(SmartTallerApp(state: state));
    return state;
  }

  Future<void> ingresar(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(1), 'secreto');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  testWidgets('el login exige contraseña', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('Ingrese su contraseña'), findsOneWidget);
    expect(state.sesionIniciada, isFalse);
  });

  testWidgets('login demo → inicio con KPIs y órdenes en proceso', (tester) async {
    final state = await pumpApp(tester);
    await tester.tap(find.text('Mecánico'));
    await tester.pump();
    expect(state.rol, Rol.mecanico);

    await ingresar(tester);
    expect(state.sesionIniciada, isTrue);
    expect(state.rol, Rol.mecanico);
    expect(find.text('Resumen del taller'), findsOneWidget);
    expect(find.text('Órdenes abiertas'), findsOneWidget);
    expect(find.text('V2K-841'), findsOneWidget);
    expect(find.text('B9M-772'), findsNothing); // OT-1039 ya se entregó
    // El mecánico no ve reportes en los accesos rápidos.
    expect(find.text('Ver reportes'), findsNothing);
  });

  testWidgets('barra inferior: órdenes, citas, stock y perfil con cierre de sesión', (tester) async {
    final state = await pumpApp(tester);
    await ingresar(tester);

    await tester.tap(find.text('Órdenes'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva orden de trabajo'), findsOneWidget);
    expect(find.text('W7B-320'), findsOneWidget);

    await tester.tap(find.text('Citas'));
    await tester.pumpAndSettle();
    expect(state.tab, AppTab.citas);
    expect(find.text('Agenda de citas'), findsWidgets);
    expect(find.text('C1T-509 · Pedro Loayza'), findsOneWidget);

    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.text('Inventario'), findsWidgets);
    expect(find.text('Stock crítico'), findsWidgets);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text(CuentaService.nombreDemo), findsOneWidget);
    expect(find.text('Modo local (sin Supabase)'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(state.sesionIniciada, isFalse);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('el detalle registra el avance y respeta el rol', (tester) async {
    final state = await pumpApp(tester);
    await ingresar(tester); // jefe de taller (rol por defecto)
    expect(state.rol, Rol.jefeTaller);

    await tester.ensureVisible(find.text('W7B-320'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('W7B-320'));
    await tester.pumpAndSettle();
    expect(find.text('Orden de trabajo'), findsOneWidget);
    final boton = find.text('Registrar avance: listo para entrega');
    await tester.scrollUntilVisible(boton, 300);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    final ot1041 = OrdenService.instancia.locales.firstWhere((o) => o.codigo == 'OT-1041');
    expect(ot1041.estado, EstadoOrden.listo);
    expect(find.textContaining('Cobrar'), findsOneWidget);
  });

  test('AppState.avanzar traduce los permisos', () async {
    final state = AppState();
    CuentaService.instancia.entrarDemo(Rol.mecanico);
    final ot1041 = OrdenService.instancia.locales.firstWhere((o) => o.codigo == 'OT-1041');
    final (sinPermiso, mensaje) = await state.avanzar(ot1041);
    expect(sinPermiso, ResultadoAvance.sinPermiso);
    expect(mensaje, contains('jefe de taller'));

    CuentaService.instancia.entrarDemo(Rol.jefeTaller);
    expect((await state.avanzar(ot1041)).$1, ResultadoAvance.avanzada);
    final lista = OrdenService.instancia.locales.firstWhere((o) => o.codigo == 'OT-1041');
    expect(lista.estado.etiqueta, 'Listo');
    expect((await state.avanzar(lista)).$1, ResultadoAvance.yaCompletada);
  });
}
