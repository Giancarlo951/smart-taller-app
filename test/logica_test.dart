import 'package:flutter_test/flutter_test.dart';
import 'package:tallersmart/core/utils/formatos.dart';
import 'package:tallersmart/core/utils/validadores.dart';
import 'package:tallersmart/modules/catalogo/models/adicional.dart';
import 'package:tallersmart/modules/catalogo/models/codigo_promocional.dart';
import 'package:tallersmart/modules/catalogo/models/config_taller.dart';
import 'package:tallersmart/modules/catalogo/models/repuesto.dart';
import 'package:tallersmart/modules/catalogo/models/servicio.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_local.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_service.dart';
import 'package:tallersmart/modules/catalogo/services/recomendaciones.dart';
import 'package:tallersmart/modules/ordenes/models/calculadora_precios.dart';
import 'package:tallersmart/modules/ordenes/services/cotizacion_service.dart';
import 'package:tallersmart/modules/ordenes/services/orden_service.dart';

import 'ayuda.dart';

const _lavado = Adicional(id: 'lavado', nombre: 'Lavado', precioCentimos: 2500);

Servicio _servicio({int? descuento}) => Servicio(
  id: 'prueba',
  nombre: 'Cambio de aceite',
  categoriaIds: const ['lubricacion'],
  descuentoPorcentaje: descuento,
  precios: const {
    TiposVehiculo.auto: PrecioVehiculo(clave: TiposVehiculo.auto, precioCentimos: 4000, minutos: 45),
    TiposVehiculo.suv: PrecioVehiculo(clave: TiposVehiculo.suv, precioCentimos: 5000, minutos: 60),
  },
  adicionalIds: const ['lavado'],
);

const _aceite = Repuesto(codigo: 'LUB-1', nombre: 'Aceite', precioCentimos: 3700, stock: 5, minimo: 2);

Catalogo _catalogo() => Catalogo(
  categorias: CatalogoLocal.categorias,
  servicios: [_servicio()],
  repuestos: const [_aceite],
  adicionales: const [_lavado],
  config: const ConfigTaller(nombre: 'Prueba', recargoDomicilioCentimos: 3000),
  promociones: const [],
);

void main() {
  group('CalculadoraPrecios', () {
    test('precio = tipo de vehículo × (1 − descuento) + adicionales', () {
      expect(CalculadoraPrecios.precioServicio(servicio: _servicio(), variante: TiposVehiculo.auto), 4000);
      expect(CalculadoraPrecios.precioServicio(servicio: _servicio(), variante: TiposVehiculo.suv), 5000);
      expect(
        CalculadoraPrecios.precioServicio(servicio: _servicio(descuento: 25), variante: TiposVehiculo.auto, adicionales: [_lavado]),
        3000 + 2500,
      );
      // Sin precio para ese tipo: usa el de auto.
      expect(CalculadoraPrecios.precioServicio(servicio: _servicio(), variante: TiposVehiculo.pesado), 4000);
    });

    test('total = subtotal − descuento + recargo; IGV incluido 18 %', () {
      const d = DesgloseOrden(subtotal: 28500, descuento: 0, recargo: 0);
      expect(d.total, 28500);
      expect(d.igvIncluido, 4347); // 285 − 285/1.18
      expect(d.opGravada + d.igvIncluido, d.total);
    });
  });

  group('CodigoPromocional', () {
    const promo = CodigoPromocional(codigo: 'X10', tipo: CodigoPromocional.porcentaje, valor: 10, minimoSubtotalCentimos: 10000, maxUsos: 2, usados: 1);

    test('valida mínimo, usos y vencimiento', () {
      expect(promo.validar(5000), contains('Monto mínimo'));
      expect(promo.validar(20000), isNull);
      expect(promo.copyWith(usados: 2).validar(20000), contains('límite de usos'));
      final vencido = CodigoPromocional(codigo: 'V', tipo: CodigoPromocional.fijo, valor: 500, venceEn: DateTime(2020));
      expect(vencido.validar(1000), contains('venció'));
    });

    test('descuento fijo nunca supera el subtotal', () {
      const fijo = CodigoPromocional(codigo: 'F', tipo: CodigoPromocional.fijo, valor: 5000);
      expect(fijo.descuentoPara(3000), 3000);
      expect(promo.descuentoPara(20000), 2000);
    });
  });

  group('CotizacionService (borrador de la orden)', () {
    late CotizacionService cot;
    setUp(() async {
      await reiniciarTodo();
      cot = CotizacionService(sincronizar: false, catalogo: _catalogo);
    });

    test('la misma combinación suma unidades; otra crea otra línea', () {
      cot.agregarServicio(servicio: _servicio());
      cot.agregarServicio(servicio: _servicio());
      cot.agregarServicio(servicio: _servicio(), adicionales: [_lavado]);
      expect(cot.lineas.length, 2);
      expect(cot.cantidadItems, 3);
    });

    test('los repuestos no pasan del stock', () {
      cot.agregarRepuesto(repuesto: _aceite, cantidad: 4);
      expect(() => cot.agregarRepuesto(repuesto: _aceite, cantidad: 2), throwsStateError);
      cot.cambiarCantidad(cot.lineas.first.id, 5);
      expect(cot.lineas.first.cantidad, 5);
    });

    test('cambiar el tipo de vehículo recalcula la mano de obra', () {
      cot.agregarServicio(servicio: _servicio());
      expect(cot.lineas.first.precioUnitarioCentimos, 4000);
      cot.cambiarTipoVehiculo(TiposVehiculo.suv);
      expect(cot.lineas.first.precioUnitarioCentimos, 5000);
      expect(cot.lineas.first.variante, TiposVehiculo.suv);
    });

    test('eliminar y deshacer vuelve a la misma posición', () {
      cot.agregarServicio(servicio: _servicio());
      cot.agregarRepuesto(repuesto: _aceite);
      final (indice, linea) = cot.eliminar(cot.lineas.last.id)!;
      expect(cot.lineas.length, 1);
      cot.restaurar(indice, linea);
      expect(cot.lineas.last.id, linea.id);
    });

    test('la promo se quita sola si el subtotal baja del mínimo; domicilio suma recargo', () {
      const promo = CodigoPromocional(codigo: 'P', tipo: CodigoPromocional.porcentaje, valor: 10, minimoSubtotalCentimos: 10000);
      cot.agregarRepuesto(repuesto: _aceite, cantidad: 3); // 111.00
      expect(cot.aplicarPromo(promo), isNull);
      expect(cot.desglose(_catalogo().config).descuento, 1110);
      cot.cambiarCantidad(cot.lineas.first.id, -2); // 37.00
      expect(cot.promo, isNull);
      cot.aDomicilio = true;
      expect(cot.desglose(_catalogo().config).total, 3700 + 3000);
    });

    test('entrega sugerida = ahora + tiempo de bahía, redondeada a la media hora', () {
      expect(CotizacionService.entregaSugerida(DateTime(2026, 9, 14, 8, 10), 45), DateTime(2026, 9, 14, 9, 30));
      expect(CotizacionService.entregaSugerida(DateTime(2026, 9, 14, 8, 0), 150), DateTime(2026, 9, 14, 10, 30));
    });

    test('repetir una orden usa los precios de hoy', () {
      final orden = OrdenService.instancia.locales.firstWhere((o) => o.codigo == 'OT-1039');
      final lineas = CotizacionService.lineasParaRepetir(orden, CatalogoService.instancia.catalogo);
      expect(lineas.every((l) => l.disponible), isTrue);
      final otra = CotizacionService(sincronizar: false);
      expect(otra.repetir(lineas, tipoVehiculo: orden.tipoVehiculo), 3);
      expect(CalculadoraPrecios.subtotal(otra.lineas), orden.subtotalCentimos);
    });
  });

  group('Formatos y validaciones', () {
    test('montos en céntimos, km, placa y correlativo', () {
      expect(formatoCentimos(428000), 'S/ 4,280.00');
      expect(formatoKm(78420), '78,420 km');
      expect(normalizarPlaca('v2k 841'), 'V2K-841');
      expect(correlativo(248), '00248');
      expect(tiempoRelativo(DateTime(2026, 1, 1, 10), ahora: DateTime(2026, 1, 1, 10, 35)), 'Hace 35 min');
      expect(iniciales('Rosa Paucar Lazo'), 'RP');
    });

    test('placa, DNI, RUC (dígito verificador), celular y km', () {
      expect(Validadores.placa('V2K-841'), isNull);
      expect(Validadores.placa('AB-12'), isNotNull);
      expect(Validadores.dni('45120884'), isNull);
      expect(Validadores.dni('4512088'), isNotNull);
      expect(Validadores.ruc('20486112094'), isNull);
      expect(Validadores.ruc('20486112095'), 'El RUC no es válido');
      expect(Validadores.telefono('964 112 480'), isNull);
      expect(Validadores.telefono('864112480'), isNotNull);
      expect(Validadores.telefonoContacto('064231447'), isNull);
      expect(Validadores.kilometraje('70000', anterior: 78420), contains('No puede ser menor'));
      expect(Validadores.numeroOperacion('12345'), isNotNull);
      expect(Validadores.numeroOperacion('123456'), isNull);
    });
  });

  group('Recomendaciones (Guía 14)', () {
    test('sugiere servicios parecidos por nombre y categoría', () {
      final catalogo = CatalogoLocal.servicios;
      final pastillas = catalogo.firstWhere((s) => s.id == 'pastillas-freno');
      final parecidos = Recomendaciones.para(pastillas, catalogo);
      expect(parecidos.first.id, 'rectificado-discos');
      expect(parecidos.any((s) => s.id == pastillas.id), isFalse);
    });

    test('mantenimiento pendiente según el km', () {
      final pendientes = Recomendaciones.mantenimientoPendiente(
        CatalogoLocal.servicios,
        kmActual: 84000,
        ultimoKmPorServicio: const {'cambio-aceite': 78420, 'alineamiento-balanceo': 80000},
      );
      expect(pendientes.map((s) => s.id), ['cambio-aceite']);
    });
  });
}
