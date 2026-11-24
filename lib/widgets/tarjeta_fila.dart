import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';

/// Fila de lista dentro de una tarjeta: ícono (o avatar) a la izquierda,
/// título y subtítulo, algo a la derecha y, opcionalmente, contenido a lo
/// ancho debajo (barra de stock, vehículos, acciones).
class TarjetaFila extends StatelessWidget {
  const TarjetaFila({
    super.key,
    required this.titulo,
    this.icono,
    this.inicio,
    this.subtitulo,
    this.pie,
    this.trailing,
    this.debajo,
    this.onTap,
    this.semanticLabel,
    this.colorIcono = Ind.accent,
    this.fondoIcono = Ind.fondoIcono,
  });

  final String titulo;
  final IconData? icono;

  /// Reemplaza al ícono (p. ej. [AvatarIniciales]).
  final Widget? inicio;
  final String? subtitulo;

  /// Debajo del subtítulo, dentro de la columna de texto (precio, etiquetas).
  final Widget? pie;
  final Widget? trailing;
  final Widget? debajo;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color colorIcono;
  final Color fondoIcono;

  @override
  Widget build(BuildContext context) {
    final lead = inicio ?? (icono == null ? null : IconoMosaico(icono!, tamano: 44, color: colorIcono, fondo: fondoIcono));
    return BlueprintBox(
      onTap: onTap,
      semanticLabel: semanticLabel ?? titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Ind.heading(15.5, height: 1.25)),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitulo!, style: Ind.body(12.5, color: Ind.muted, height: 1.35)),
                      ),
                    if (pie != null) Padding(padding: const EdgeInsets.only(top: 6), child: pie),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (debajo != null) ...[const SizedBox(height: 12), debajo!],
        ],
      ),
    );
  }
}

/// Círculo azul claro con las iniciales del nombre.
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales(this.nombre, {super.key, this.tamano = 44, this.color = Ind.accent});

  final String nombre;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: const BoxDecoration(color: Ind.fondoIcono, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(iniciales(nombre), style: Ind.heading(tamano * 0.36, height: 1, color: color)),
    );
  }
}

/// Dato con ícono pequeño a la izquierda (teléfono, km, mecánico, entrega).
class DatoIcono extends StatelessWidget {
  const DatoIcono(this.icono, this.texto, {super.key, this.color});

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: color ?? Ind.n500),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: Ind.body(13.5, height: 1.3, color: color ?? Ind.n800))),
        ],
      ),
    );
  }
}
