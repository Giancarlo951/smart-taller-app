// Contrato entre la app y supabase/esquema.sql: test/contrato/orden_supabase.json
// es el JSON real que devolvieron crear_orden y cambiar_estado_orden al correr
// el esquema en Postgres (PGlite). Si cambia una columna, esta prueba falla.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tallersmart/modules/catalogo/services/catalogo_local.dart';
import 'package:tallersmart/modules/clientes/services/cliente_service.dart';
import 'package:tallersmart/modules/ordenes/models/orden.dart';
import 'package:tallersmart/modules/ordenes/services/ordenes_local.dart';

void main() {
  final json = jsonDecode(File('test/contrato/orden_supabase.json').readAsStringSync()) as Map<String, dynamic>;

  test('lee la orden que devuelve Supabase', () {
    final o = Orden.desdeMapa(Map<String, dynamic>.from(json['orden'] as Map));
    expect(o.codigo, 'OT-1043');
    expect(o.estado, EstadoOrden.entregado);
    expect(o.placa, 'V2K-841');
    expect(o.lineas.length, 2);
    expect(o.repuestosRequeridos, {'LUB-1040': 4});
    expect(o.subtotalCentimos, 18800);
    expect(o.descuentoCentimos, 1880);
    expect(o.totalCentimos, 16920);
    expect(o.codigoPromo, 'AUTOSIGLO10');
    expect(o.diagnostico, 'Pastillas gastadas al 80 %');
    expect(o.metodoPago, MetodosPago.yape);
    expect(o.estaPagada, isTrue);
    expect(o.pagadoEn, isNotNull);
    expect(o.stockDescontado, isTrue);
    expect(o.historial.map((c) => c.estado), EstadoOrden.flujo);
    expect(o.historial.first.por, 'Mecánico');
    expect(o.comprobante!.codigo, 'B001-00248');
    expect(o.comprobante!.igvCentimos + o.comprobante!.opGravadaCentimos, 16920);
    expect(o.comprobante!.estadoSunat, Comprobante.aceptado);
    expect(o.creadoEn.isBefore(o.actualizadoEn) || o.creadoEn == o.actualizadoEn, isTrue);
  });

  test('la orden recién creada viene en recepción y por cobrar', () {
    final o = Orden.desdeMapa(Map<String, dynamic>.from(json['crear'] as Map));
    expect(o.estado, EstadoOrden.recepcion);
    expect(o.estadoPago, EstadosPago.porCobrar);
    expect(o.historial.single.estado, EstadoOrden.recepcion);
    expect(o.diagnostico, isEmpty);
    expect(o.comprobante, isNull);
  });

  test('lo que envía la app trae las columnas que lee crear_orden', () {
    final mapa = OrdenesLocal.ejemplo().first.aMapaNueva();
    for (final columna in [
      'cliente_nombre', 'telefono', 'placa', 'tipo_vehiculo', 'km', 'lineas',
      'subtotal_centimos', 'descuento_centimos', 'recargo_centimos', 'total_centimos',
      'codigo_promo', 'a_domicilio', 'creado_por_nombre',
    ]) {
      expect(mapa, contains(columna));
    }
    final linea = (mapa['lineas'] as List).first as Map;
    expect(linea.keys, containsAll(['tipo', 'ref_id', 'cantidad', 'precio_unitario_centimos']));
    expect(['servicio', 'repuesto'], contains(linea['tipo']));
  });

  test('catálogo y clientes de ejemplo usan las columnas del esquema', () {
    final esquema = File('supabase/esquema.sql').readAsStringSync();
    final columnas = {
      ...CatalogoLocal.servicios.first.aMapa().keys,
      ...CatalogoLocal.repuestos.first.aMapa().keys,
      ...CatalogoLocal.promociones.first.aMapa().keys,
      ...CatalogoLocal.categorias.first.aMapa().keys,
      ...CatalogoLocal.adicionales.first.aMapa().keys,
      ...ClienteService.clientesDeEjemplo().first.aMapa().keys,
    };
    for (final c in columnas) {
      expect(RegExp('\\b$c\\b').hasMatch(esquema), isTrue, reason: 'falta la columna $c en esquema.sql');
    }
    // emitir_comprobante lee las series de config.datos.
    expect(CatalogoLocal.config.aMapa(), containsPair('serie_boleta', 'B001'));
  });
}
