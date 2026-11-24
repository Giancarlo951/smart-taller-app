import 'package:flutter/material.dart';

import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';

/// Variantes de etiqueta: azul, gris, contorno azul, verde (logrado) y rojo
/// (alerta).
enum TagVariant { accent, neutral, outline, exito, peligro }

/// Etiqueta de estado en forma de píldora: alto 24, 11.5 px.
class EstadoTag extends StatelessWidget {
  const EstadoTag(this.label, {super.key, this.variant = TagVariant.accent, this.border});

  final String label;
  final TagVariant variant;

  /// Borde extra opcional.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? line) = switch (variant) {
      TagVariant.accent => (Ind.a100, Ind.a800, border),
      TagVariant.neutral => (Ind.n100, Ind.n700, border),
      TagVariant.outline => (Ind.card, Ind.accent, Ind.a300),
      TagVariant.exito => (Ind.exitoFondo, Ind.exito, border),
      TagVariant.peligro => (Ind.peligroFondo, Ind.peligro, border),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: line != null ? Border.all(color: line) : null,
      ),
      // widthFactor: 1 → la etiqueta se ajusta al texto en lugar de expandirse.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: Ind.heading(11.5, color: fg, height: 1).copyWith(letterSpacing: 0),
        ),
      ),
    );
  }
}

/// Chip de selección única (roles, filtros): azul sólido si está activo,
/// blanco con borde si no.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      child: FocusRing(
        radius: 18,
        child: Padding(
          // Área táctil mínima de 40 px sin agrandar el chip.
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: selected ? Ind.accent : Ind.card,
            shape: RoundedRectangleBorder(
              borderRadius: esquinas,
              side: BorderSide(color: selected ? Ind.accent : Ind.n300),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                // widthFactor: 1 → el chip mide lo que su texto, no todo el ancho.
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: (selected ? Ind.heading(13, height: 1) : Ind.body(13, height: 1))
                        .copyWith(color: selected ? Colors.white : Ind.n700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
