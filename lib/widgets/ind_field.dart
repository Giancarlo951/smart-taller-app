import 'package:flutter/material.dart';

import '../theme/industry_theme.dart';

/// Campo de formulario: etiqueta de 13 px sobre el control.
class IndField extends StatelessWidget {
  const IndField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Ind.kicker(size: 13, color: Ind.n700)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
