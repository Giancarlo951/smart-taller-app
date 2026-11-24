import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../modules/ordenes/models/orden.dart';
import '../theme/industry_theme.dart';

/// Línea de tiempo de las 5 etapas: círculo de 18 px con ✓ si la etapa se
/// alcanzó y línea de 2 px entre etapas.
/// Muestra la hora y quién registró cada paso (statusHistory).
class AvanceTimeline extends StatelessWidget {
  const AvanceTimeline({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final alcanzada = orden.etapa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, etapa) in EstadoOrden.etapas.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  color: i <= alcanzada ? Ind.a300 : Ind.n200,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          _Fila(etapa: etapa, lograda: i <= alcanzada, cambio: _cambio(etapa)),
        ],
      ],
    );
  }

  CambioEstado? _cambio(EstadoOrden etapa) {
    for (final c in orden.historial.reversed) {
      if (c.estado == etapa) return c;
    }
    return null;
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etapa, required this.lograda, this.cambio});

  final EstadoOrden etapa;
  final bool lograda;
  final CambioEstado? cambio;

  @override
  Widget build(BuildContext context) {
    final opacidad = lograda ? 1.0 : 0.45;
    final cuando = cambio == null
        ? etapa.nota
        : '${etapa.nota} · ${formatoFechaHora(cambio!.fecha)}${cambio!.por.isEmpty ? '' : ' · ${cambio!.por}'}';
    return Semantics(
      label: '${etapa.titulo}${lograda ? ', completada' : ', pendiente'}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: lograda ? Ind.accent : Ind.card,
                shape: BoxShape.circle,
                border: Border.all(color: lograda ? Ind.accent : Ind.n300, width: 1.5),
              ),
              child: lograda ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etapa.titulo, style: Ind.heading(15, color: Ind.textAt(opacidad))),
                Text(cuando, style: Ind.body(12, color: Ind.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
