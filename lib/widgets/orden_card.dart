import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../modules/ordenes/models/orden.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import 'estado_tag.dart';
import 'stock_bar.dart';

/// Etiqueta según el estado: en curso = azul, listo = verde, anulada = rojo,
/// recepción o entregada = gris.
TagVariant tagDeEstado(EstadoOrden estado) => switch (estado) {
  EstadoOrden.listo => TagVariant.exito,
  EstadoOrden.cancelado => TagVariant.peligro,
  EstadoOrden.recepcion || EstadoOrden.entregado => TagVariant.neutral,
  _ => TagVariant.accent,
};

/// Tarjeta de orden de trabajo.
/// [compacta] = versión de inicio (vehículo, barra de avance y entrega);
/// si no, versión de listado (cliente, total y cobro).
class OrdenCard extends StatelessWidget {
  const OrdenCard({super.key, required this.orden, required this.onTap, this.compacta = false});

  final Orden orden;
  final VoidCallback onTap;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final estado = orden.estado.etiqueta;

    return BlueprintBox(
      onTap: onTap,
      semanticLabel: 'Orden ${orden.codigo}, ${orden.placa}, $estado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoMosaico(Icons.directions_car_filled_rounded, tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orden.placa, style: Ind.heading(16)),
                    Text(
                      compacta ? orden.vehiculo : orden.clienteNombre,
                      style: Ind.body(12.5, color: Ind.muted, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EstadoTag(estado, variant: tagDeEstado(orden.estado)),
            ],
          ),
          const SizedBox(height: 10),
          Text(orden.servicioPrincipal, style: Ind.body(14, height: 1.35)),
          if (compacta) ...[
            const SizedBox(height: 10),
            NivelBar(valor: orden.avance),
          ],
          const SizedBox(height: 8),
          Text(
            compacta
                ? '${orden.codigo} · ${orden.mecanico} · entrega ${orden.entregaTexto()}'
                : '${orden.codigo} · ${formatoCentimos(orden.totalCentimos)} · ${orden.etiquetaPago}'
                      '${orden.mecanico.isEmpty ? '' : ' · ${orden.mecanico}'}',
            style: Ind.meta,
          ),
        ],
      ),
    );
  }
}
