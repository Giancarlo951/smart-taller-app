import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/industry_theme.dart';
import '../widgets/ind_bottom_bar.dart';
import '../widgets/ind_side_bar.dart';
import 'citas_screen.dart';
import 'inicio_screen.dart';
import 'inventario_screen.dart';
import 'mas_screen.dart';
import 'ordenes_screen.dart';

/// Shell de la app: 5 pestañas, cada una con su propio [Navigator] para que
/// las pantallas de detalle se apilen sobre la pestaña activa y conserven
/// su pila al cambiar de pestaña.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navKeys = {for (final t in AppTab.values) t: GlobalKey<NavigatorState>()};

  Widget _raiz(AppTab tab) => switch (tab) {
        AppTab.inicio => const InicioScreen(),
        AppTab.ordenes => const OrdenesScreen(),
        AppTab.citas => const CitasScreen(),
        AppTab.stock => const InventarioScreen(),
        AppTab.mas => const MasScreen(),
      };

  void _seleccionar(AppState app, AppTab tab) {
    if (tab == app.tab) {
      // Tocar la pestaña activa vuelve a su pantalla raíz.
      _navKeys[tab]!.currentState?.popUntil((r) => r.isFirst);
    } else {
      app.irATab(tab);
    }
  }

  /// Atrás de Android: primero la pila de la pestaña, luego Inicio, luego salir.
  void _atras(AppState app) {
    final nav = _navKeys[app.tab]!.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (app.tab != AppTab.inicio) {
      app.irATab(AppTab.inicio);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    final pestanas = IndexedStack(
      index: app.tab.index,
      children: [
        for (final tab in AppTab.values)
          // Solo la pestaña visible participa en el recorrido de foco.
          ExcludeFocus(
            excluding: tab != app.tab,
            child: Navigator(
              key: _navKeys[tab],
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => _raiz(tab),
              ),
            ),
          ),
      ],
    );
    // PC o tablet horizontal: barra lateral; celular: barra inferior.
    final escritorio = MediaQuery.sizeOf(context).width >= Ind.anchoEscritorio;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras(app);
      },
      child: Scaffold(
        body: escritorio
            ? Row(children: [
                IndSideBar(actual: app.tab, onSelect: (t) => _seleccionar(app, t)),
                Expanded(child: pestanas),
              ])
            : pestanas,
        bottomNavigationBar: escritorio
            ? null
            : IndBottomBar(
                actual: app.tab,
                onSelect: (t) => _seleccionar(app, t),
              ),
      ),
    );
  }
}
