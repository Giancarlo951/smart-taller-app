import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/reportes/models/reporte_stats.dart';
import '../modules/reportes/services/reportes_service.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/ind_page.dart';
import '../widgets/kpi_card.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/stock_bar.dart';

String _variacion(double v, String comparacion) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}% vs. $comparacion';

/// Reportes (Módulo 07): indicadores del periodo calculados con las órdenes.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  Periodo _periodo = Periodo.mes;
  late Stream<ReporteStats> _stats = ReportesService.instancia.escuchar(_periodo);

  void _elegir(Periodo p) => setState(() {
    _periodo = p;
    _stats = ReportesService.instancia.escuchar(p);
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReporteStats>(
      stream: _stats,
      builder: (context, snapshot) {
        final s = snapshot.data;
        return IndPage(
          kicker: 'Indicadores',
          titulo: 'Reportes',
          gap: 16,
          children: [
            Segmentos<Periodo>(
              opciones: [for (final p in Periodo.values) (p, p.etiqueta)],
              valor: _periodo,
              alCambiar: _elegir,
            ),
            if (snapshot.hasError)
              EstadoVacio(titulo: 'No se pudieron cargar los datos', ayuda: '${snapshot.error}')
            else if (s == null)
              const LinearProgressIndicator()
            else ...[
              KpiGrid(valorSize: 24, items: [
                (formatoCentimos(s.ingresosCentimos).replaceFirst('S/ ', ''), s.periodo.tituloIngresos),
                ('${s.ordenes}', 'Órdenes'),
                (formatoCentimos(s.ticketPromedioCentimos).replaceFirst('S/ ', ''), 'Ticket promedio S/'),
                (s.horasServicio == null ? '—' : '${s.horasServicio!.toStringAsFixed(1)} h', 'Tiempo medio (meta ${s.metaHoras} h)'),
              ]),
              Text(
                '${_variacion(s.variacionIngresos, s.periodo.comparacion)} en ingresos · '
                '${_variacion(s.variacionOrdenes, s.periodo.comparacion)} en órdenes · '
                '${s.clientesNuevos} clientes nuevos, ${s.clientesRecurrentes} recurrentes',
                style: Ind.meta,
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SeccionTitulo(s.periodo.tituloGrafico),
                BlueprintBox(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Barras(stats: s),
                    const SizedBox(height: 10),
                    Text(s.descripcionPico, style: Ind.meta),
                  ]),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SeccionTitulo('Órdenes por estado'),
                if (s.totalPorEstado == 0)
                  const EstadoVacio(titulo: 'Todavía no hay órdenes en este periodo')
                else
                  BlueprintBox(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final e in EstadoOrden.flujo)
                        if ((s.porEstado[e] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              FilaMonto(e.etiqueta, '${s.porEstado[e]}'),
                              const SizedBox(height: 4),
                              NivelBar(valor: s.porEstado[e]! / s.totalPorEstado),
                            ]),
                          ),
                    ]),
                  ),
              ]),
              _Top(titulo: s.periodo.tituloMasPedidos, items: s.masPedidos),
              _Top(titulo: 'Repuestos más usados', items: s.repuestosMasUsados),
              BlueprintBox(
                color: Ind.a100,
                borderColor: Ind.a200,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.insights_rounded, color: Ind.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El tablero completo (tendencias, mecánicos y márgenes) vive en Power BI, conectado a la base de Supabase (vistas del esquema reportes).',
                      style: Ind.body(12.5, color: Ind.a800, height: 1.45),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Barras extends StatelessWidget {
  const _Barras({required this.stats});

  final ReporteStats stats;

  @override
  Widget build(BuildContext context) {
    final maximo = stats.barras.fold(0, (m, b) => b.centimos > m ? b.centimos : m);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, b) in stats.barras.indexed)
            Expanded(
              child: Semantics(
                label: '${b.etiqueta}: ${formatoCentimos(b.centimos)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: maximo == 0 ? 3 : 3 + 90 * b.centimos / maximo,
                        decoration: BoxDecoration(
                          color: i == stats.indiceEnCurso ? Ind.accent : Ind.a200,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(b.etiqueta, style: Ind.body(9, color: Ind.muted, height: 1)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.titulo, required this.items});

  final String titulo;
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SeccionTitulo(titulo),
      if (items.isEmpty)
        const EstadoVacio(titulo: 'Sin datos en este periodo')
      else
        BlueprintBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            for (final (i, t) in items.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: Ind.n100)),
                ),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == 0 ? Ind.accent : Ind.a100, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: Ind.heading(12.5, height: 1, color: i == 0 ? Colors.white : Ind.a800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.nombre, style: Ind.body(13.5, height: 1.3))),
                  Text('${t.unidades} · ${formatoCentimos(t.centimos)}', style: Ind.meta),
                ]),
              ),
          ]),
        ),
    ]);
  }
}
