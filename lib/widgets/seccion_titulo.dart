import 'package:flutter/material.dart';

import '../theme/industry_theme.dart';

/// Título de sección (17 px) con acción opcional "Ver todo ›" a la derecha.
class SeccionTitulo extends StatelessWidget {
  const SeccionTitulo(this.titulo, {super.key, this.accion, this.onAccion});

  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Semantics(header: true, child: Text(titulo, style: Ind.heading(17)))),
          if (accion != null)
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(textStyle: Ind.heading(13, height: 1.2)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(accion!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
