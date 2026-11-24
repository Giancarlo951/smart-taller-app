import 'package:flutter/material.dart';

import '../core/services/supabase_servicio.dart';
import '../core/utils/formatos.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/clientes/services/cliente_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/services/pago_service.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/ind_page.dart';
import '../widgets/tarjeta_fila.dart';

/// Cuenta y ajustes (equivale al Perfil + Ajustes del panel de referencia).
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _sembrar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Cargar datos de ejemplo',
      mensaje: 'Se subirán categorías, servicios, repuestos, adicionales, códigos promocionales, '
          'config del taller y clientes de ejemplo a Supabase. Las filas con la misma clave se sobrescriben.',
      accion: 'Cargar',
    );
    if (!ok || !context.mounted) return;
    await ejecutar(context, () async {
      await CatalogoService.instancia.sembrar();
      await ClienteService.instancia.sembrar();
    }, exito: 'Datos de ejemplo cargados en Supabase');
  }

  // Escucha el catálogo para que "Datos" cambie solo cuando llegan las filas
  // de Supabase (por ejemplo, justo después de cargar los datos de ejemplo).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: CatalogoService.instancia,
        builder: (context, _) => _contenido(context),
      );

  Widget _contenido(BuildContext context) {
    final app = AppScope.of(context);
    final perfil = app.cuenta.perfil;
    final config = CatalogoService.instancia.catalogo.config;
    final enLinea = haySupabase && CatalogoService.instancia.desdeServidor;
    final ajustes = <(IconData, String, String)>[
      (Icons.badge_outlined, 'Rol y permisos', app.rol.label),
      (Icons.storefront_outlined, 'Taller asignado', perfil?.taller ?? '${config.nombre} · ${config.ciudad}'),
      (enLinea ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, 'Datos', haySupabase
          ? (CatalogoService.instancia.desdeServidor ? 'Supabase en tiempo real' : 'Supabase vacío · catálogo de ejemplo')
          : 'Modo local (sin Supabase)'),
      (Icons.credit_card_outlined, 'Pagos con tarjeta', kPagosDemo ? 'Modo demo' : 'Mercado Pago'),
      (Icons.timer_outlined, 'Cierre de sesión', '5 min sin uso · 1 min minimizada'),
      (Icons.info_outline_rounded, 'Versión del aplicativo', '1.1 (piloto)'),
      (Icons.shield_outlined, 'Protección de datos', 'Ley N° 29733'),
    ];
    final nombre = perfil?.nombre ?? '';

    return IndPage(
      kicker: 'Cuenta',
      titulo: 'Perfil',
      gap: 16,
      children: [
        BlueprintBox(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AvatarIniciales(nombre.isEmpty ? app.rol.label : nombre, tamano: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: Ind.heading(19, height: 1.25)),
                    Text('${app.rol.label} · ${config.nombre}', style: Ind.body(13, color: Ind.n700, height: 1.4)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (perfil != null && perfil.correo.isNotEmpty) perfil.correo,
                        if (perfil?.inicioSesion != null) 'Sesión iniciada ${formatoFechaHora(perfil!.inicioSesion!)}',
                      ].join(' · '),
                      style: Ind.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BlueprintBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, (icono, label, valor)) in ajustes.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: i == ajustes.length - 1 ? null : const Border(bottom: BorderSide(color: Ind.n100)),
                  ),
                  child: Row(
                    children: [
                      IconoMosaico(icono, tamano: 34),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label, style: Ind.body(13.5, height: 1.3))),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(valor, textAlign: TextAlign.right, style: Ind.body(13, color: Ind.muted, height: 1.3)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (haySupabase && Permisos.puedeCargarDatosEjemplo(app.rol))
          SecondaryButton(label: 'Cargar datos de ejemplo', onPressed: () => _sembrar(context)),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: app.cerrarSesion,
            style: OutlinedButton.styleFrom(
              foregroundColor: Ind.peligro,
              side: const BorderSide(color: Color(0xFFFDA29B)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}
