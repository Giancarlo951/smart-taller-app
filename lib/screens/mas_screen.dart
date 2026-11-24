import 'package:flutter/material.dart';

import '../modules/cuentas/services/permisos.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/ind_page.dart';
import 'catalogo_servicios_screen.dart';
import 'clientes_screen.dart';
import 'facturacion_screen.dart';
import 'notificaciones_screen.dart';
import 'perfil_screen.dart';
import 'reportes_screen.dart';

class _Modulo {
  const _Modulo(this.icono, this.color, this.label, this.nota, this.builder, {this.ruta});

  final IconData icono;
  final Color color;
  final String label;
  final String nota;
  final Widget Function() builder;
  final String? ruta;
}

/// Todos los módulos en una cuadrícula de tarjetas con ícono.
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rol = AppScope.of(context).rol;
    final modulos = [
      _Modulo(Icons.groups_rounded, Ind.colorClientes, 'Clientes', 'Registro e historial', () => const ClientesScreen()),
      _Modulo(Icons.directions_car_rounded, Ind.colorClientes, 'Vehículos', 'Placas y mantenimiento', () => const ClientesScreen()),
      _Modulo(Icons.handyman_rounded, Ind.colorCatalogo, 'Catálogo', 'Servicios y precios', () => const CatalogoServiciosScreen()),
      _Modulo(Icons.receipt_long_rounded, Ind.colorFacturacion, 'Facturación', 'Comprobantes SUNAT', () => const FacturacionScreen()),
      if (Permisos.puedeVerReportes(rol))
        _Modulo(Icons.bar_chart_rounded, Ind.colorReportes, 'Reportes', 'Indicadores Power BI', () => const ReportesScreen()),
      _Modulo(Icons.notifications_rounded, Ind.colorAvisos, 'Notificaciones', 'Avisos del taller', () => const NotificacionesScreen(),
          ruta: NotificacionesScreen.routeName),
      _Modulo(Icons.person_rounded, Ind.colorPerfil, 'Perfil', 'Cuenta y accesos', () => const PerfilScreen()),
    ];

    Widget celda(_Modulo m) => BlueprintBox(
      semanticLabel: '${m.label}, ${m.nota}',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        settings: RouteSettings(name: m.ruta),
        builder: (_) => m.builder(),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoMosaico(m.icono, color: m.color),
          const SizedBox(height: 12),
          Text(m.label, style: Ind.heading(16)),
          const SizedBox(height: 2),
          Text(m.nota, style: Ind.body(12.5, color: Ind.muted, height: 1.35)),
        ],
      ),
    );

    // Dos columnas en celular; tres en PC o tablet.
    return IndPage(
      kicker: 'Módulos del taller',
      titulo: 'Más',
      children: [
        LayoutBuilder(builder: (context, c) {
          final columnas = c.maxWidth >= 640 ? 3 : 2;
          return Column(children: [
            for (var i = 0; i < modulos.length; i += columnas) ...[
              if (i > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columnas; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(child: j < modulos.length ? celda(modulos[j]) : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ]);
        }),
      ],
    );
  }
}
