import 'package:flutter/material.dart';

import '../modules/avisos/models/aviso.dart';
import '../modules/catalogo/models/repuesto.dart';
import '../modules/catalogo/models/servicio.dart';
import '../modules/ordenes/models/orden.dart';

/// Ícono de una categoría del catálogo (servicios y repuestos).
IconData iconoCategoria(String? categoriaId) => switch (categoriaId) {
      'lubricacion' || 'rep-lubricantes' => Icons.oil_barrel_rounded,
      'frenos' || 'rep-frenos' => Icons.album_rounded,
      'electrico' || 'rep-electrico' => Icons.bolt_rounded,
      'suspension' => Icons.tire_repair_rounded,
      'mantenimiento' => Icons.build_rounded,
      'rep-filtros' => Icons.filter_alt_rounded,
      'rep-kits' => Icons.home_repair_service_rounded,
      _ => Icons.settings_rounded,
    };

IconData iconoServicio(Servicio s) => iconoCategoria(s.categoriaIds.isEmpty ? null : s.categoriaIds.first);

IconData iconoRepuesto(Repuesto r) => iconoCategoria(r.categoriaId);

IconData iconoVehiculo(String tipo) => switch (tipo) {
      TiposVehiculo.suv => Icons.airport_shuttle_rounded,
      TiposVehiculo.pesado => Icons.local_shipping_rounded,
      _ => Icons.directions_car_filled_rounded,
    };

IconData iconoAviso(TipoAviso tipo) => switch (tipo) {
      TipoAviso.stock => Icons.inventory_2_rounded,
      TipoAviso.orden => Icons.assignment_rounded,
      TipoAviso.cita => Icons.event_rounded,
      TipoAviso.pago => Icons.payments_rounded,
      TipoAviso.facturacion => Icons.receipt_long_rounded,
    };

IconData iconoMetodoPago(String metodo) => switch (metodo) {
      MetodosPago.yape || MetodosPago.plin => Icons.phone_iphone_rounded,
      MetodosPago.tarjeta => Icons.credit_card_rounded,
      _ => Icons.payments_rounded,
    };
