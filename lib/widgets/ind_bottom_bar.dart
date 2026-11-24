import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';

/// Barra inferior de 5 pestañas: ícono + etiqueta; la activa en azul con una
/// píldora clara detrás del ícono.
class IndBottomBar extends StatelessWidget {
  const IndBottomBar({super.key, required this.actual, required this.onSelect});

  final AppTab actual;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Ind.card,
        boxShadow: [BoxShadow(color: Color(0x14101828), offset: Offset(0, -4), blurRadius: 16)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final tab in AppTab.values)
                  Expanded(child: _TabItem(tab: tab, activa: tab == actual, onTap: () => onSelect(tab))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono normal y relleno (activo) de cada pestaña.
(IconData, IconData) iconosDeTab(AppTab tab) => switch (tab) {
      AppTab.inicio => (Icons.home_outlined, Icons.home_rounded),
      AppTab.ordenes => (Icons.assignment_outlined, Icons.assignment_rounded),
      AppTab.citas => (Icons.event_outlined, Icons.event_rounded),
      AppTab.stock => (Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      AppTab.mas => (Icons.grid_view_outlined, Icons.grid_view_rounded),
    };

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.activa, required this.onTap});

  final AppTab tab;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? Ind.accent : Ind.n500;
    final (normal, relleno) = iconosDeTab(tab);
    return Semantics(
      selected: activa,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: FocusRing(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ind.radiusMd),
          overlayColor: WidgetStatePropertyAll(Ind.accent.withValues(alpha: 0.06)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: activa ? Ind.a100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(activa ? relleno : normal, size: 23, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  maxLines: 1,
                  style: (activa ? Ind.heading(12, height: 1.2) : Ind.body(12, height: 1.2)).copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
