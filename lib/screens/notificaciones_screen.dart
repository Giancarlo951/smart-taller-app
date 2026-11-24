import 'package:flutter/material.dart';

import '../core/services/sesion_service.dart';
import '../modules/avisos/models/aviso.dart';
import '../modules/avisos/services/aviso_service.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_page.dart';
import 'orden_detalle_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  static const routeName = '/notificaciones';

  static TagVariant variante(TipoAviso t) => switch (t) {
    TipoAviso.stock => TagVariant.peligro,
    TipoAviso.orden || TipoAviso.cita || TipoAviso.pago => TagVariant.accent,
    TipoAviso.facturacion => TagVariant.neutral,
  };

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();
    // Al abrir la lista los avisos quedan leídos (después del primer frame,
    // para que el contador se actualice sin reconstruir durante el build).
    WidgetsBinding.instance.addPostFrameCallback((_) => AvisoService.instancia.marcarLeidos());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AvisoService.instancia,
      builder: (context, _) {
        final avisos = AvisoService.instancia.avisos;
        final usuario = SesionService.instancia.usuarioId;
        return IndPage(
          kicker: 'Avisos',
          titulo: 'Notificaciones',
          gap: 10,
          children: [
            if (avisos.isEmpty) const EstadoVacio(titulo: 'No tienes avisos por ahora'),
            for (final a in avisos)
              BlueprintBox(
                onTap: a.ordenId == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdenDetalleScreen(ordenId: a.ordenId!))),
                semanticLabel: '${a.tipo.label}: ${a.texto}',
                color: a.leidoPara(usuario) ? null : Ind.a100.withValues(alpha: 0.55),
                borderColor: a.leidoPara(usuario) ? null : Ind.a200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconoMosaico(
                      iconoAviso(a.tipo),
                      tamano: 40,
                      color: a.tipo == TipoAviso.stock ? Ind.peligro : Ind.accent,
                      fondo: a.tipo == TipoAviso.stock ? Ind.peligroFondo : Ind.card,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              EstadoTag(a.tipo.label, variant: NotificacionesScreen.variante(a.tipo)),
                              if (!a.leidoPara(usuario)) ...[
                                const SizedBox(width: 6),
                                const EstadoTag('Nuevo', variant: TagVariant.outline),
                              ],
                              const Spacer(),
                              Text(a.hora(), style: Ind.body(11.5, color: Ind.muted, height: 1.3)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(a.texto, style: Ind.body(13.5, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
