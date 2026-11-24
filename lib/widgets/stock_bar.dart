import 'package:flutter/material.dart';

import '../theme/industry_theme.dart';

/// Barra de nivel redondeada de 6 px (avance de orden, stock).
class NivelBar extends StatelessWidget {
  const NivelBar({super.key, required this.valor, this.color = Ind.accent});

  /// De 0 a 1.
  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(3);
    return Container(
      height: 6,
      decoration: BoxDecoration(color: Ind.n200, borderRadius: esquinas),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: valor.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: esquinas)),
      ),
    );
  }
}
