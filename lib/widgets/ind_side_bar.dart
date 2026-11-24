import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import 'ind_bottom_bar.dart';
import 'logo.dart';
import 'tarjeta_fila.dart';

/// Barra lateral para pantallas anchas (PC): marca arriba, las 5 secciones
/// y la cuenta abajo. Reemplaza a la barra inferior.
class IndSideBar extends StatelessWidget {
  const IndSideBar({super.key, required this.actual, required this.onSelect});

  final AppTab actual;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nombre = (app.cuenta.perfil?.nombre ?? '').trim();
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: Ind.card,
        border: Border(right: BorderSide(color: Ind.n200)),
      ),
      child: SafeArea(
        right: false,
        // En ventanas bajas la barra se desplaza en vez de desbordarse; si
        // sobra alto, la cuenta queda abajo (SliverFillRemaining + Spacer).
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // — Logotipo —
              Semantics(
                header: true,
                child: const Center(child: LogoSmartTaller(ancho: 172)),
              ),
              const SizedBox(height: 24),
              for (final tab in AppTab.values) ...[
                _ItemLateral(tab: tab, activa: tab == actual, onTap: () => onSelect(tab)),
                const SizedBox(height: 4),
              ],
              const Spacer(),
              // — Cuenta —
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Ind.bg, borderRadius: BorderRadius.circular(Ind.radiusMd)),
                child: Row(children: [
                  AvatarIniciales(nombre.isEmpty ? app.rol.label : nombre, tamano: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre.isEmpty ? app.rol.label : nombre,
                          style: Ind.heading(13.5, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(app.rol.label, style: Ind.body(12, color: Ind.muted, height: 1.25), maxLines: 1),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemLateral extends StatelessWidget {
  const _ItemLateral({required this.tab, required this.activa, required this.onTap});

  final AppTab tab;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (normal, relleno) = iconosDeTab(tab);
    final color = activa ? Ind.accent : Ind.n600;
    return Semantics(
      selected: activa,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: FocusRing(
        child: Material(
          color: activa ? Ind.a100 : Colors.transparent,
          borderRadius: BorderRadius.circular(Ind.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            overlayColor: WidgetStatePropertyAll(Ind.accent.withValues(alpha: 0.06)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(activa ? relleno : normal, size: 22, color: color),
                const SizedBox(width: 12),
                Text(tab.label, style: (activa ? Ind.heading(14.5) : Ind.body(14.5)).copyWith(color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
