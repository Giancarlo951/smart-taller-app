import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../state/app_state.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_page.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_fila.dart';
import 'orden_detalle_screen.dart';

/// Facturación (Módulo 06): cobros pendientes, Yape/Plin por verificar e
/// historial de comprobantes electrónicos.
class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({super.key});

  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  late final Stream<List<Orden>> _porCobrar = OrdenService.instancia.porCobrar();
  late final Stream<List<Orden>> _historial = OrdenService.instancia.conComprobante();

  void _abrir(Orden o) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdenDetalleScreen(ordenId: o.id)));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return StreamBuilder<List<Orden>>(
      stream: _porCobrar,
      builder: (context, pendientes) => StreamBuilder<List<Orden>>(
        stream: _historial,
        builder: (context, historial) {
          final cobrar = pendientes.data ?? const <Orden>[];
          final verificar = cobrar.where((o) => o.pagoPorVerificar).toList();
          final porCobrar = cobrar.where((o) => !o.pagoPorVerificar).toList();
          final comprobantes = historial.data ?? const <Orden>[];
          return IndPage(
            kicker: 'Comprobantes SUNAT',
            titulo: 'Facturación',
            gap: 14,
            children: [
              if (verificar.isNotEmpty)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SeccionTitulo('Pagos por verificar (${verificar.length})'),
                  for (final o in verificar) ...[
                    TarjetaFila(
                      onTap: () => _abrir(o),
                      semanticLabel: 'Verificar pago ${o.codigo}',
                      icono: iconoMetodoPago(o.metodoPago ?? ''),
                      titulo: '${o.codigo} · ${o.clienteNombre}',
                      subtitulo: '${o.etiquetaMetodo} · Op. ${o.referenciaPago}',
                      trailing: Text(formatoCentimos(o.totalCentimos), style: Ind.heading(15, color: Ind.accent)),
                      debajo: Permisos.puedeAprobarPago(app.rol)
                          ? Row(children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: () => ejecutar(context, () => OrdenService.instancia.rechazarPago(o, actor: app.actor),
                                        exito: 'Pago rechazado'),
                                    child: const Text('Rechazar'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: FilledButton(
                                    onPressed: () => ejecutar(context, () => OrdenService.instancia.aprobarPago(o, actor: app.actor),
                                        exito: 'Pago de ${o.codigo} aprobado'),
                                    child: const Text('Aprobar'),
                                  ),
                                ),
                              ),
                            ])
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ]),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SeccionTitulo('Listas por cobrar (${porCobrar.length})'),
                if (porCobrar.isEmpty) const EstadoVacio(titulo: 'No hay órdenes por cobrar'),
                for (final o in porCobrar) ...[
                  TarjetaFila(
                    onTap: () => _abrir(o),
                    semanticLabel: 'Cobrar ${o.codigo}',
                    icono: iconoVehiculo(o.tipoVehiculo),
                    titulo: '${o.codigo} · ${o.placa}',
                    subtitulo: '${o.clienteNombre} · ${o.etiquetaPago}',
                    trailing: Text(formatoCentimos(o.totalCentimos), style: Ind.heading(15, color: Ind.accent)),
                  ),
                  const SizedBox(height: 10),
                ],
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SeccionTitulo('Historial de facturación (${comprobantes.length})'),
                if (comprobantes.isEmpty) const EstadoVacio(titulo: 'Todavía no hay comprobantes'),
                for (final o in comprobantes) ...[
                  TarjetaFila(
                    onTap: () => _abrir(o),
                    semanticLabel: 'Comprobante ${o.comprobante!.codigo}',
                    icono: Icons.receipt_long_rounded,
                    colorIcono: Ind.exito,
                    fondoIcono: Ind.exitoFondo,
                    titulo: o.comprobante!.codigo,
                    subtitulo: '${o.comprobante!.razonSocial.isEmpty ? o.clienteNombre : o.comprobante!.razonSocial} · '
                        '${formatoFechaHora(o.comprobante!.emitidoEn)}',
                    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatoCentimos(o.comprobante!.totalCentimos), style: Ind.heading(14)),
                      const SizedBox(height: 4),
                      const EstadoTag('Aceptado', variant: TagVariant.exito),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
              ]),
            ],
          );
        },
      ),
    );
  }
}
