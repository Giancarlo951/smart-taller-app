import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tallersmart/core/services/sesion_service.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_local.dart';
import 'package:tallersmart/modules/citas/models/cita.dart';
import 'package:tallersmart/modules/citas/services/cita_service.dart';
import 'package:tallersmart/modules/clientes/models/cliente.dart';
import 'package:tallersmart/modules/clientes/services/cliente_service.dart';
import 'package:tallersmart/modules/cuentas/services/limites_sesion.dart';
import 'package:tallersmart/modules/cuentas/widgets/guardia_inactividad.dart';
import 'package:tallersmart/modules/ordenes/models/orden.dart';
import 'package:tallersmart/modules/ordenes/services/ordenes_local.dart';
import 'package:tallersmart/modules/reportes/models/reporte_stats.dart';
import 'package:tallersmart/modules/reportes/services/calculadora_reportes.dart';

import 'ayuda.dart';

void main() {
  // Lunes 14 de septiembre de 2026, 12:00.
  final ahora = DateTime(2026, 9, 14, 12);

  group('Reportes (calculadora del dashboard)', () {
    final ordenes = OrdenesLocal.ejemplo(ahora: ahora);

    test('mes: ingresos por fecha de cobro, estados, más pedidos y tiempo medio', () {
      final s = calcularReporte(periodo: Periodo.mes, ordenes: ordenes, ahora: ahora);
      expect(s.ingresosCentimos, 69000);
      expect(s.cobradas, 1);
      expect(s.ticketPromedioCentimos, 69000);
      expect(s.ordenes, 4);
      expect(s.porEstado[EstadoOrden.entregado], 1);
      expect(s.porEstado[EstadoOrden.reparacion], 1);
      expect(s.masPedidos.first.nombre, 'Rectificado de discos');
      expect(s.repuestosMasUsados.first.refId, 'LUB-1040');
      expect(s.horasServicio, closeTo(23, 0.01));
    });

    test('hoy compara con ayer y marca la hora en curso', () {
      final s = calcularReporte(periodo: Periodo.hoy, ordenes: ordenes, ahora: ahora);
      expect(s.ingresosCentimos, 0);
      expect(s.ingresosAnteriorCentimos, 69000);
      expect(s.variacionIngresos, -100);
      expect(s.barras.length, 11); // 8 a 18 h
      expect(s.indiceEnCurso, 4);
      expect(s.descripcionPico, 'Aún no hay cobros en este periodo');
    });

    test('semana de lunes a domingo; KPIs de inicio', () {
      final domingo = DateTime(2026, 9, 20, 10);
      expect(rangoActual(Periodo.semana, domingo).inicio, DateTime(2026, 9, 14));
      final kpis = KpisInicio.calcular(ordenes: ordenes, citasHoy: 5, stockCritico: 3, ahora: ahora);
      expect(kpis.ordenesAbiertas, 3);
      expect(kpis.ingresosHoyCentimos, 0);
    });
  });

  group('Citas', () {
    const config = CatalogoLocal.config; // 08:00 – 19:00, 3 bahías
    final temprano = DateTime(2026, 9, 14, 7);
    final delDia = CitaService.citasDeEjemplo(hoy: ahora);
    Cita cita(int h, int m, {String placa = 'Z1Z-999'}) => Cita(
      fecha: DateTime(2026, 9, 14, h, m),
      servicio: 'Revisión',
      placa: placa,
      cliente: 'Cliente',
      telefono: '964000000',
    );

    test('horario, intervalos, placa repetida y pasado', () {
      expect(CitaService.validar(cita(8, 30), delDia, config, ahora: temprano), isNull);
      expect(CitaService.validar(cita(8, 15), delDia, config, ahora: temprano), contains('30 minutos'));
      expect(CitaService.validar(cita(19, 0), delDia, config, ahora: temprano), contains('Fuera del horario'));
      expect(CitaService.validar(cita(9, 0, placa: 'V2K-841'), delDia, config, ahora: temprano), contains('ya tiene una cita'));
      expect(CitaService.validar(cita(8, 30), delDia, config, ahora: ahora), contains('pasado'));
    });

    test('no pasa de las bahías del taller', () {
      final llenas = [...delDia, cita(10, 0, placa: 'AAA-111'), cita(10, 0, placa: 'BBB-222')];
      expect(CitaService.validar(cita(10, 0), llenas, config, ahora: temprano), contains('No hay bahías'));
      final horarios = CitaService.horarios(DateTime(2026, 9, 14), llenas, config);
      expect(horarios.firstWhere((h) => h.$1.hour == 10 && h.$1.minute == 0).$2, 0);
      expect(horarios.first.$2, 3);
    });

    test('el flujo de estados no retrocede', () {
      expect(EstadoCita.confirmada.siguientes, contains(EstadoCita.enTaller));
      expect(EstadoCita.atendida.siguientes, isEmpty);
    });
  });

  group('Clientes', () {
    setUp(reiniciarTodo);

    test('no repite DNI ni placa y busca por placa', () async {
      final repetido = Cliente(
        nombre: 'Otra persona',
        tipoDocumento: Cliente.dni,
        numeroDocumento: '45120884',
        telefono: '964000000',
        creadoEn: DateTime.now(),
      );
      expect(() => ClienteService.instancia.guardar(repetido), throwsA(isA<StateError>()));
      final placaAjena = repetido.copyWith(
        numeroDocumento: '40000001',
        vehiculos: const [Vehiculo(placa: 'V2K-841', marca: 'Kia', modelo: 'Rio', anio: 2020)],
      );
      expect(() => ClienteService.instancia.guardar(placaAjena), throwsA(isA<StateError>()));
      final id = await ClienteService.instancia.guardar(
        placaAjena.copyWith(vehiculos: const [Vehiculo(placa: 'N3W-100', marca: 'Kia', modelo: 'Rio', anio: 2020)]),
      );
      expect(ClienteService.instancia.porPlaca('n3w100')!.$1.id, id);
      expect(ClienteService.buscar(ClienteService.instancia.actuales, 'mantaro').single.esEmpresa, isTrue);
    });
  });

  group('Cierre de sesión (Guía 12)', () {
    test('minimizada más de 1 minuto vence la sesión', () async {
      SharedPreferences.setMockInitialValues({});
      await SesionService.instancia.iniciar();
      final prefs = SesionService.instancia.preferencias;
      await LimitesSesion.marcarSegundoPlano(prefs, ahora);
      expect(LimitesSesion.vencioEnSegundoPlano(prefs, ahora.add(const Duration(seconds: 30))), isFalse);
      expect(LimitesSesion.vencioEnSegundoPlano(prefs, ahora.add(const Duration(minutes: 2))), isTrue);
    });

    testWidgets('sin tocar: "¿Sigues ahí?" y cierre a los 30 s', (tester) async {
      var cerrada = false;
      await tester.pumpWidget(MaterialApp(
        home: GuardiaInactividad(
          inactividad: const Duration(seconds: 5),
          aviso: const Duration(seconds: 3),
          alCerrarSesion: () async => cerrada = true,
          child: const Scaffold(body: Text('Taller')),
        ),
      ));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('¿Sigues ahí?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(cerrada, isTrue);
    });

    testWidgets('"Sigo aquí" mantiene la sesión', (tester) async {
      var cerrada = false;
      await tester.pumpWidget(MaterialApp(
        home: GuardiaInactividad(
          inactividad: const Duration(seconds: 5),
          alCerrarSesion: () async => cerrada = true,
          child: const Scaffold(body: Text('Taller')),
        ),
      ));
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.text('Sigo aquí'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('¿Sigues ahí?'), findsNothing);
      expect(cerrada, isFalse);
    });
  });
}
