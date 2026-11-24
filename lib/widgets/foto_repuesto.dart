import 'package:flutter/material.dart';

import '../modules/catalogo/models/repuesto.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import 'iconos_taller.dart';

/// Ruta de la foto de un repuesto: `assets/repuestos/<código>.png`.
String rutaFotoRepuesto(String codigo) => 'assets/repuestos/${codigo.trim().toUpperCase()}.png';

/// Foto del repuesto en un recuadro blanco redondeado. Si el repuesto no
/// tiene foto (código nuevo), muestra el ícono de su categoría.
class FotoRepuesto extends StatelessWidget {
  const FotoRepuesto(this.repuesto, {super.key, this.tamano = 44, this.alerta = false});

  final Repuesto repuesto;
  final double tamano;

  /// Stock crítico: el ícono de respaldo sale en rojo.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final respaldo = IconoMosaico(
      iconoRepuesto(repuesto),
      tamano: tamano,
      color: alerta ? Ind.peligro : Ind.colorInventario,
      fondo: alerta ? Ind.peligroFondo : Ind.fondoIcono,
    );
    final pixeles = (tamano * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      image: true,
      label: repuesto.nombre,
      excludeSemantics: true,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(tamano * 0.3),
          border: Border.all(color: Ind.n200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          rutaFotoRepuesto(repuesto.codigo),
          fit: BoxFit.contain,
          // Decodifica al tamaño en pantalla, no a 512 px.
          cacheWidth: pixeles,
          cacheHeight: pixeles,
          errorBuilder: (_, _, _) => respaldo,
        ),
      ),
    );
  }
}
