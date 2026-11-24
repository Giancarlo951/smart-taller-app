import 'package:flutter/material.dart';

import '../screens/notificaciones_screen.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';

/// Barra superior común: volver (en detalle), texto pequeño + título y la
/// campana de avisos con su contador.
class IndTopBar extends StatelessWidget implements PreferredSizeWidget {
  const IndTopBar({super.key, required this.kicker, required this.titulo});

  final String kicker;
  final String titulo;

  // 12 + 10 de padding, texto pequeño (≈16) y título 22/1.15 (≈26).
  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    final puedeVolver = ModalRoute.of(context)?.canPop ?? false;
    final enAvisos = ModalRoute.of(context)?.settings.name == NotificacionesScreen.routeName;
    final pendientes = AppScope.of(context).notificacionesPendientes;

    final fila = Row(
      children: [
        if (puedeVolver) ...[
          BotonCuadrado(
            icono: Icons.arrow_back_rounded,
            etiqueta: 'Volver',
            onTap: () => nav.maybePop(),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kicker.isNotEmpty) Text(kicker, style: Ind.kicker(), maxLines: 1, overflow: TextOverflow.ellipsis),
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  style: Ind.heading(22, height: 1.15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        BotonCuadrado(
          icono: enAvisos ? Icons.notifications_rounded : Icons.notifications_none_rounded,
          etiqueta: 'Notificaciones, $pendientes sin leer',
          contador: pendientes,
          activo: enAvisos,
          onTap: enAvisos
              ? null
              : () => nav.push(MaterialPageRoute(
                    settings: const RouteSettings(name: NotificacionesScreen.routeName),
                    builder: (_) => const NotificacionesScreen(),
                  )),
        ),
      ],
    );

    return Material(
      color: Ind.bg,
      child: SafeArea(
        bottom: false,
        // En pantallas anchas se alinea con el contenido centrado de la página.
        child: LayoutBuilder(
          builder: (context, c) {
            final margen = Ind.margenLateral(c.maxWidth);
            return Padding(padding: EdgeInsets.fromLTRB(margen, 12, margen, 10), child: fila);
          },
        ),
      ),
    );
  }
}

/// Botón cuadrado de 42 px con ícono (volver, avisos) y contador opcional.
class BotonCuadrado extends StatelessWidget {
  const BotonCuadrado({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.contador = 0,
    this.activo = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;
  final int contador;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(Ind.radiusMd);
    return Semantics(
      label: etiqueta,
      button: true,
      excludeSemantics: true,
      child: FocusRing(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: activo ? Ind.a100 : Ind.card,
              shape: RoundedRectangleBorder(borderRadius: esquinas, side: const BorderSide(color: Ind.n200)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(icono, size: 22, color: activo ? Ind.accent : Ind.n800),
                ),
              ),
            ),
            if (contador > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Ind.peligro,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Ind.bg, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    contador > 99 ? '99+' : '$contador',
                    style: Ind.heading(10.5, height: 1, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Página estándar dentro del shell: barra superior + cuerpo desplazable.
class IndPage extends StatelessWidget {
  const IndPage({
    super.key,
    required this.kicker,
    required this.titulo,
    required this.children,
    this.gap = 18,
    this.pie,
  });

  final String kicker;
  final String titulo;
  final List<Widget> children;

  /// Separación vertical entre bloques.
  final double gap;

  /// Acción fija bajo la lista (p. ej. "Nueva orden de trabajo").
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IndTopBar(kicker: kicker, titulo: titulo),
      // En PC el contenido se centra con un ancho máximo (Ind.anchoContenido).
      body: LayoutBuilder(
        builder: (context, c) {
          final margen = Ind.margenLateral(c.maxWidth);
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(margen, 8, margen, 24),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (_, i) => children[i],
          );
        },
      ),
      bottomNavigationBar: pie == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: Ind.card,
                boxShadow: [BoxShadow(color: Color(0x14101828), offset: Offset(0, -4), blurRadius: 16)],
              ),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, c) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: Ind.margenLateral(c.maxWidth), vertical: 12),
                    child: pie,
                  ),
                ),
              ),
            ),
    );
  }
}
