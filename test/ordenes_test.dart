import 'package:flutter_test/flutter_test.dart';
import 'package:tallersmart/modules/avisos/models/aviso.dart';
import 'package:tallersmart/modules/avisos/services/aviso_service.dart';
import 'package:tallersmart/modules/catalogo/models/servicio.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_service.dart';
import 'package:tallersmart/modules/clientes/services/cliente_service.dart';
import 'package:tallersmart/modules/ordenes/models/linea_cotizacion.dart';
import 'package:tallersmart/modules/ordenes/models/orden.dart';
import 'package:tallersmart/modules/ordenes/services/cotizacion_service.dart';
import 'package:tallersmart/modules/ordenes/services/orden_service.dart';
import 'package:tallersmart/modules/ordenes/services/reglas_orden.dart';

import 'ayuda.dart';

OrdenService get _ordenes => OrdenService.instancia;
Catalogo get _catalogo => CatalogoService.instancia.catalogo;

Orden _orden(String codigo) => _ordenes.locales.firstWhere((o) => o.codigo == codigo);

int _stock(String codigo) => _catalogo.repuesto(codigo)!.stock;

/// Crea una orden local para V2K-841 con las líneas del borrador.
Future<Orden> _crear(CotizacionService cot, {int km = 80000}) => _ordenes.crearOrden(
  lineas: cot.lineas,
  catalogo: _catalogo,
  promo: cot.promo,
  clienteId: 'local-c5',
  clienteNombre: 'Rosa Paucar Lazo',
  telefono: '964112480',
  placa: 'v2k841',
  vehiculo: 'Toyota Yaris 2019',
  tipoVehiculo: cot.tipoVehiculo,
  km: km,
  kmAnterior: 78420,
  motivo: 'Mantenimiento',
  actor: jefe,
);

Future<Orden> _llevarALista(Orden o) async {
  var actual = o;
  while (actual.estado != EstadoOrden.listo) {
    actual = await _ordenes.avanzar(actual, actor: jefe);
  }
  return actual;
}

void main() {
  late CotizacionService cot;
  setUp(() async {
    await reiniciarTodo();
    cot = CotizacionService(sincronizar: false);
  });

  group('Crear orden (transacción local)', () {
    test('OT-1043 con precios del catálogo, promo y km del vehículo', () async {
      cot.agregarServicio(servicio: _catalogo.servicio('cambio-aceite')!);
      cot.agregarRepuesto(repuesto: _catalogo.repuesto('LUB-1040')!, cantidad: 4);
      expect(cot.aplicarPromo((await CatalogoService.instancia.buscarPromo('autosiglo10'))!), isNull);

      final orden = await _crear(cot);
      expect(orden.codigo, 'OT-1043');
      expect(orden.placa, 'V2K-841');
      expect(orden.estado, EstadoOrden.recepcion);
      expect(orden.subtotalCentimos, 4000 + 4 * 3700);
      expect(orden.descuentoCentimos, 1880);
      expect(orden.totalCentimos, 18800 - 1880);
      expect(orden.codigoPromo, 'AUTOSIGLO10');
      expect(_catalogo.promociones.firstWhere((p) => p.codigo == 'AUTOSIGLO10').usados, 1);
      expect(ClienteService.instancia.porPlaca('V2K-841')!.$2.km, 80000);
      expect(AvisoService.instancia.avisos.first.texto, contains('OT-1043 registrada'));
      // Crear no saca stock: eso pasa en la etapa Repuestos.
      expect(_stock('LUB-1040'), 48);
    });

    test('recalcula los precios aunque el borrador traiga otros', () async {
      final trucada = LineaCotizacion(
        id: 'x',
        tipo: LineaCotizacion.tipoServicio,
        refId: 'alineamiento-balanceo',
        nombre: 'Alineamiento',
        variante: TiposVehiculo.suv,
        precioUnitarioCentimos: 1,
        cantidad: 1,
        agregadoEn: DateTime.now(),
      );
      final orden = await _ordenes.crearOrden(
        lineas: [trucada],
        catalogo: _catalogo,
        clienteNombre: 'Pedro Loayza',
        telefono: '964225870',
        placa: 'C1T-509',
        vehiculo: 'Toyota RAV4 2018',
        tipoVehiculo: TiposVehiculo.suv,
        km: 90000,
        actor: mecanico,
      );
      expect(orden.totalCentimos, 14000);
    });

    test('valida km, placa y que haya algo que hacer', () async {
      cot.agregarServicio(servicio: _catalogo.servicio('cambio-aceite')!);
      await expectLater(() => _crear(cot, km: 70000), throwsA(isA<StateError>()));
      await expectLater(
        () => _ordenes.crearOrden(
          lineas: const [],
          catalogo: _catalogo,
          clienteNombre: 'X',
          telefono: '964112480',
          placa: 'V2K-841',
          vehiculo: 'Y',
          tipoVehiculo: TiposVehiculo.auto,
          km: 1,
          actor: jefe,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Etapas y permisos', () {
    test('solo el jefe de taller marca "Listo"', () async {
      final ot1041 = _orden('OT-1041'); // en reparación
      await expectLater(() => _ordenes.avanzar(ot1041, actor: mecanico), throwsA(isA<StateError>()));
      final lista = await _ordenes.avanzar(ot1041, actor: jefe);
      expect(lista.estado, EstadoOrden.listo);
      expect(lista.historial.last.por, 'Jefe');
      await expectLater(() => _ordenes.avanzar(lista, actor: jefe), throwsA(isA<StateError>()));
    });

    test('saltar etapas registra las intermedias', () {
      expect(
        EstadoOrden.listo.pasosDesde(EstadoOrden.recepcion),
        [EstadoOrden.diagnostico, EstadoOrden.repuestos, EstadoOrden.reparacion, EstadoOrden.listo],
      );
      expect(EstadoOrden.cancelado.pasosDesde(EstadoOrden.diagnostico), [EstadoOrden.cancelado]);
    });

    test('Repuestos descuenta stock y anular lo devuelve', () async {
      final ot1040 = _orden('OT-1040'); // diagnóstico, batería sin salir
      expect(_stock('BAT-7500'), 11);
      final enRepuestos = await _ordenes.avanzar(ot1040, actor: mecanico);
      expect(enRepuestos.stockDescontado, isTrue);
      expect(_stock('BAT-7500'), 10);
      await expectLater(() => _ordenes.anular(enRepuestos, actor: mecanico, motivo: 'El cliente desistió'), throwsA(isA<StateError>()));
      final anulada = await _ordenes.anular(enRepuestos, actor: jefe, motivo: 'El cliente desistió');
      expect(anulada.estado, EstadoOrden.cancelado);
      expect(_stock('BAT-7500'), 11);
    });

    test('avisa el stock crítico y frena si no alcanza', () async {
      cot.agregarRepuesto(repuesto: _catalogo.repuesto('LUB-1040')!, cantidad: 30);
      var orden = await _crear(cot);
      orden = await _ordenes.avanzar(orden, actor: mecanico);
      orden = await _ordenes.avanzar(orden, actor: mecanico);
      expect(_stock('LUB-1040'), 18);
      expect(
        AvisoService.instancia.avisos.any((a) => a.tipo == TipoAviso.stock && a.texto.contains('Aceite 10W-40')),
        isTrue,
      );

      cot.vaciar(remoto: false);
      cot.agregarRepuesto(repuesto: _catalogo.repuesto('BAT-7500')!, cantidad: 10);
      final otra = await _crear(cot);
      await CatalogoService.instancia.ajustarStock('BAT-7500', 5);
      final enDiagnostico = await _ordenes.avanzar(otra, actor: jefe);
      await expectLater(() => _ordenes.avanzar(enDiagnostico, actor: jefe), throwsA(isA<StateError>()));
      expect(_stock('BAT-7500'), 5);
    });

    test('agregar repuestos con el stock ya descontado mueve la diferencia', () async {
      final ot1042 = _orden('OT-1042'); // en Repuestos
      final lineas = [for (final l in ot1042.lineas) l.aLineaCotizacion()];
      final filtro = lineas.indexWhere((l) => l.refId == 'FIL-TY02');
      lineas[filtro] = lineas[filtro].copyWith(cantidad: 2);
      final actualizada = await _ordenes.actualizarLineas(ot1042, lineas, actor: mecanico);
      expect(_stock('FIL-TY02'), 5);
      expect(actualizada.totalCentimos, ot1042.totalCentimos + 4200);
    });
  });

  group('Cobro, verificación y comprobante', () {
    test('efectivo queda pagado; boleta B001-00248; luego se entrega', () async {
      final lista = await _llevarALista(_orden('OT-1041'));
      await expectLater(() => _ordenes.entregar(lista, actor: jefe), throwsA(isA<StateError>()));
      await expectLater(
        () => _ordenes.registrarCobro(lista, metodo: MetodosPago.efectivo, actor: mecanico),
        throwsA(isA<StateError>()),
      );
      final pagada = await _ordenes.registrarCobro(lista, metodo: MetodosPago.efectivo, actor: jefe);
      expect(pagada.estaPagada, isTrue);
      expect(pagada.pagadoEn, isNotNull);

      final conBoleta = await _ordenes.emitirComprobante(pagada, tipo: 'boleta', actor: administracion);
      expect(conBoleta.comprobante!.codigo, 'B001-00248');
      expect(conBoleta.comprobante!.igvCentimos + conBoleta.comprobante!.opGravadaCentimos, 52000);
      await expectLater(() => _ordenes.emitirComprobante(conBoleta, tipo: 'boleta', actor: jefe), throwsA(isA<StateError>()));

      final entregada = await _ordenes.entregar(conBoleta, actor: administracion);
      expect(entregada.estado, EstadoOrden.entregado);
    });

    test('Yape queda por verificar y solo administración lo aprueba', () async {
      final lista = await _llevarALista(_orden('OT-1042'));
      await expectLater(() => _ordenes.registrarCobro(lista, metodo: MetodosPago.yape, actor: jefe), throwsA(isA<StateError>()));
      final yape = await _ordenes.registrarCobro(lista, metodo: MetodosPago.yape, referencia: '123456', actor: jefe);
      expect(yape.estadoPago, EstadosPago.verificando);
      await expectLater(() => _ordenes.aprobarPago(yape, actor: jefe), throwsA(isA<StateError>()));
      final aprobada = await _ordenes.aprobarPago(yape, actor: administracion);
      expect(aprobada.estaPagada, isTrue);

      final factura = await _ordenes.emitirComprobante(
        aprobada,
        tipo: 'factura',
        documento: '20486112094',
        razonSocial: 'Transportes Mantaro S.A.C.',
        actor: administracion,
      );
      expect(factura.comprobante!.codigo, 'F001-00001');
    });

    test('boletas desde S/ 700 piden DNI; facturas, RUC válido', () async {
      final pagada = (await _llevarALista(_orden('OT-1041'))).copyWith(estadoPago: EstadosPago.pagado);
      final grande = pagada.copyWith(totalCentimos: 80000);
      expect(ReglasOrden.validarComprobante(grande, jefe.rol, tipo: 'boleta'), contains('requieren el DNI'));
      expect(ReglasOrden.validarComprobante(grande, jefe.rol, tipo: 'boleta', documento: '45120884'), isNull);
      expect(ReglasOrden.validarComprobante(pagada, jefe.rol, tipo: 'factura', documento: '20486112095', razonSocial: 'X S.A.'),
          'El RUC no es válido');
      expect(ReglasOrden.validarComprobante(pagada, mecanico.rol, tipo: 'boleta'), contains('Solo'));
    });

    test('una orden lista ya no se edita', () async {
      final lista = await _llevarALista(_orden('OT-1040'));
      expect(ReglasOrden.validarEdicionLineas(lista), isNotNull);
    });
  });
}
