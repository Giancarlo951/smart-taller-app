import 'package:flutter/material.dart';

import 'industry_theme.dart';

/// Anillo de foco de teclado: contorno azul de 2 px con 3 px de separación,
/// con las mismas esquinas redondeadas del control. Solo aparece al navegar
/// con teclado.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child, this.radius = Ind.radiusMd});

  final Widget child;
  final double radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final visible = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (visible)
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Ind.a500, width: 2),
                    borderRadius: BorderRadius.circular(widget.radius + 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta del sistema: blanca, esquinas de 16 px, borde gris muy suave y
/// sombra ligera. Si recibe [onTap] se vuelve pulsable.
/// (Conserva el nombre de la versión anterior para no tocar cada pantalla.)
class BlueprintBox extends StatelessWidget {
  const BlueprintBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.semanticLabel,
    this.radius = Ind.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Relleno; por defecto blanco.
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(radius);
    final decoracion = BoxDecoration(
      color: color ?? Ind.card,
      borderRadius: esquinas,
      border: Border.all(color: borderColor ?? Ind.n200),
      boxShadow: Ind.shadowSm,
    );
    final contenido = Padding(padding: padding, child: child);
    // Material transparente: los ListTile/Switch de adentro dibujan su
    // efecto de toque sobre el fondo de la tarjeta, no detrás.
    if (onTap == null) {
      return DecoratedBox(
        decoration: decoracion,
        child: Material(type: MaterialType.transparency, borderRadius: esquinas, child: contenido),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: FocusRing(
        radius: radius,
        child: DecoratedBox(
          decoration: decoracion,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: esquinas,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: esquinas,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) return Ind.accent.withValues(alpha: 0.08);
                if (states.contains(WidgetState.hovered)) return Ind.accent.withValues(alpha: 0.04);
                return Colors.transparent;
              }),
              child: contenido,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón principal de ancho completo: azul sólido y redondeado.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.icono,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final texto = Text(label, textAlign: TextAlign.center);
    return FocusRing(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: icono == null
            ? FilledButton(onPressed: onPressed, child: texto)
            : FilledButton.icon(onPressed: onPressed, icon: Icon(icono, size: 20), label: texto),
      ),
    );
  }
}

/// Botón secundario de ancho completo: fondo azul claro y texto azul.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.height = 46});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? Ind.n400 : Ind.a800),
            backgroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.disabled)) return Ind.n100;
              if (s.contains(WidgetState.pressed)) return Ind.a300;
              if (s.contains(WidgetState.hovered)) return Ind.a200;
              return Ind.a100;
            }),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Botón cuadrado azul con "+" para agregar a la orden (como en los bocetos).
class BotonAgregar extends StatelessWidget {
  const BotonAgregar({super.key, required this.onPressed, this.etiqueta = 'Agregar'});

  final VoidCallback? onPressed;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 36,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: etiqueta,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Ind.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Ind.n200,
            disabledForegroundColor: Ind.n400,
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
        ),
      ),
    );
  }
}

/// Ícono dentro de un mosaico redondeado de color suave (accesos, módulos,
/// indicadores y estados vacíos).
class IconoMosaico extends StatelessWidget {
  const IconoMosaico(
    this.icono, {
    super.key,
    this.tamano = 44,
    this.color = Ind.accent,
    this.fondo = Ind.fondoIcono,
  });

  final IconData icono;
  final double tamano;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(tamano * 0.3)),
      child: Icon(icono, color: color, size: tamano * 0.52),
    );
  }
}
