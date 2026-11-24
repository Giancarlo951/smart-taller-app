import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/citas/models/cita.dart';
import '../modules/citas/services/cita_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../modules/reportes/services/calculadora_reportes.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/ind_page.dart';
import '../widgets/kpi_card.dart';
import '../widgets/orden_card.dart';
import '../widgets/seccion_titulo.dart';
import 'clientes_screen.dart';
import 'orden_detalle_screen.dart';
import 'reportes_screen.dart';

/// Saludo según la hora del día.
String saludoDelDia(DateTime ahora) => switch (ahora.hour) {
      >= 5 && < 12 => '¡Buenos días!',
      >= 12 && < 19 => '¡Buenas tardes!',
      _ => '¡Buenas noches!',
    };

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  late final Stream<List<Orden>> _ordenes = OrdenService.instancia.todas(limite: 200);
  late final Stream<List<Cita>> _citas = CitaService.instancia.delDia(DateTime.now());

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nombre = (app.cuenta.perfil?.nombre ?? '').trim();
    final primerNombre = nombre.isEmpty ? app.rol.label : nombre.split(RegExp(r'\s+')).first;

    final accesos = <(IconData, String, VoidCallback)>[
      (Icons.person_add_alt_1_rounded, 'Registrar cliente', () => abrirFormularioCliente(context)),
      (Icons.event_available_rounded, 'Nueva cita', () => app.irATab(AppTab.citas)),
      (Icons.inventory_2_rounded, 'Salida de almacén', () => app.irATab(AppTab.stock)),
      if (Permisos.puedeVerReportes(app.rol))
        (Icons.bar_chart_rounded, 'Ver reportes', () => _push(const ReportesScreen()))
      else
        (Icons.groups_rounded, 'Clientes', () => _push(const ClientesScreen())),
    ];

    return StreamBuilder<List<Orden>>(
      stream: _ordenes,
      builder: (context, ordenes) => StreamBuilder<List<Cita>>(
        stream: _citas,
        builder: (context, citas) => ListenableBuilder(
          listenable: CatalogoService.instancia,
          builder: (context, _) {
            final ahora = DateTime.now();
            final lista = ordenes.data ?? const <Orden>[];
            final kpis = KpisInicio.calcular(
              ordenes: lista,
              citasHoy: (citas.data ?? const <Cita>[]).where((c) => c.estado.ocupaBahia).length,
              stockCritico: CatalogoService.instancia.catalogo.stockCritico.length,
              ahora: ahora,
            );
            final enProceso = lista.where((o) => o.estado.activa).take(3).toList();
            return IndPage(
              kicker: 'Hola, $primerNombre',
              titulo: saludoDelDia(ahora),
              children: [
                _Banner(
                  fecha: fechaLarga(ahora),
                  enTaller: kpis.ordenesAbiertas,
                  citasHoy: kpis.citasHoy,
                  onVerOrdenes: () => app.irATab(AppTab.ordenes),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SeccionTitulo('Accesos rápidos'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, (icono, label, accion)) in accesos.indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: _Acceso(icono: icono, label: label, onTap: accion)),
                        ],
                      ],
                    ),
                  ],
                ),
                KpiGrid(
                  valorSize: 22,
                  items: [
                    ('${kpis.ordenesAbiertas}', 'Órdenes abiertas'),
                    ('${kpis.citasHoy}', 'Citas de hoy'),
                    ('${kpis.stockCritico}', 'Stock crítico'),
                    (formatoCentimos(kpis.ingresosHoyCentimos).replaceFirst('.00', ''), 'Ingresos de hoy'),
                  ],
                  iconos: const [
                    Icons.assignment_rounded,
                    Icons.event_rounded,
                    Icons.warning_amber_rounded,
                    Icons.payments_rounded,
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SeccionTitulo('Órdenes en proceso', accion: 'Ver todas', onAccion: () => app.irATab(AppTab.ordenes)),
                    if (ordenes.hasData && enProceso.isEmpty)
                      const EstadoVacio(titulo: 'No hay vehículos en el taller'),
                    for (final (i, o) in enProceso.indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      OrdenCard(orden: o, compacta: true, onTap: () => _push(OrdenDetalleScreen(ordenId: o.id))),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta azul destacada: resumen del día y acceso a las órdenes.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.fecha,
    required this.enTaller,
    required this.citasHoy,
    required this.onVerOrdenes,
  });

  final String fecha;
  final int enTaller;
  final int citasHoy;
  final VoidCallback onVerOrdenes;

  @override
  Widget build(BuildContext context) {
    final blanco = Colors.white.withValues(alpha: 0.82);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Ind.radiusXl - 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Ind.a800, Ind.a600],
        ),
        boxShadow: Ind.shadowMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen del taller', style: Ind.heading(19, color: Colors.white)),
                const SizedBox(height: 2),
                Text(fecha, style: Ind.body(12.5, color: blanco, height: 1.3)),
                const SizedBox(height: 10),
                Text(
                  '${plural(enTaller, 'vehículo', 'vehículos')} en el taller · '
                  '${plural(citasHoy, 'cita', 'citas')} hoy',
                  style: Ind.body(13.5, color: Colors.white, height: 1.35),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onVerOrdenes,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ver órdenes', style: Ind.heading(13, color: Ind.accent)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Ind.accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Icons.car_repair_rounded, size: 38, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso rápido: ícono en mosaico blanco con la etiqueta debajo.
class _Acceso extends StatelessWidget {
  const _Acceso({required this.icono, required this.label, required this.onTap});

  final IconData icono;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: FocusRing(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ind.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: Ind.card,
                    borderRadius: BorderRadius.circular(Ind.radiusLg),
                    border: Border.all(color: Ind.n200),
                    boxShadow: Ind.shadowSm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icono, color: Ind.accent, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Ind.body(12.5, height: 1.25).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
