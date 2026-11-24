import 'package:flutter/material.dart';

import '../theme/industry_theme.dart';

/// Logotipo de Smart Taller ("st" + "smart taller · automotriz") con fondo
/// transparente. [soloMarca] muestra solo el símbolo "st".
class LogoSmartTaller extends StatelessWidget {
  const LogoSmartTaller({super.key, required this.ancho, this.soloMarca = false});

  final double ancho;
  final bool soloMarca;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      soloMarca ? 'assets/marca/marca_st.png' : 'assets/marca/logo.png',
      width: ancho,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Smart Taller',
      // Sin el archivo (no debería pasar), el nombre en texto.
      errorBuilder: (_, _, _) => SizedBox(
        width: ancho,
        child: Text('Smart Taller', textAlign: TextAlign.center, style: Ind.heading(ancho * 0.14, color: Ind.a900)),
      ),
    );
  }
}
