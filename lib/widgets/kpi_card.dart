import 'package:flutter/material.dart';

import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';

/// Indicador: valor grande y etiqueta; con [icono], el ícono va a la
/// izquierda en un mosaico azul claro.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.valor, required this.label, this.valorSize = 28, this.icono});

  final String valor;
  final String label;
  final double valorSize;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(valor, style: Ind.heading(valorSize, height: 1.05), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(label, style: Ind.body(12.5, color: Ind.muted, height: 1.25)),
      ],
    );
    return BlueprintBox(
      padding: const EdgeInsets.all(14),
      child: Semantics(
        container: true,
        label: '$label: $valor',
        excludeSemantics: true,
        child: icono == null
            ? textos
            : Row(
                children: [
                  IconoMosaico(icono!, tamano: 40),
                  const SizedBox(width: 12),
                  Expanded(child: textos),
                ],
              ),
      ),
    );
  }
}

/// Rejilla de KPIs con 12 px de separación: dos columnas en celular y, con
/// espacio de sobra (≥ 640 px) y 4 o más indicadores, cuatro columnas.
/// [iconos], si se da, va en el mismo orden que [items].
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items, this.valorSize = 28, this.iconos});

  final List<(String, String)> items;
  final double valorSize;
  final List<IconData>? iconos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 640 && items.length >= 4 ? 4 : 2;
      final filas = <Widget>[];
      for (var i = 0; i < items.length; i += columnas) {
        if (i > 0) filas.add(const SizedBox(height: 12));
        filas.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columnas; j++) ...[
                if (j > i) const SizedBox(width: 12),
                Expanded(
                  child: j < items.length
                      ? KpiCard(
                          valor: items[j].$1,
                          label: items[j].$2,
                          valorSize: valorSize,
                          icono: iconos != null && j < iconos!.length ? iconos![j] : null,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ));
      }
      return Column(children: filas);
    });
  }
}
