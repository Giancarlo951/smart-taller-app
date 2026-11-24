import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/sesion_service.dart';
import 'core/services/supabase_servicio.dart';
import 'core/widgets/guarda_conexion.dart';
import 'modules/cuentas/services/cuenta_service.dart';
import 'modules/cuentas/widgets/guardia_inactividad.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme/industry_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sin SUPABASE_URL / SUPABASE_KEY (o si falla) la app sigue con datos locales.
  final errorSupabase = await iniciarSupabase();
  if (errorSupabase != null) debugPrint('Smart Taller en modo local: $errorSupabase');
  await SesionService.instancia.iniciar();
  // Si la cuenta ya tenía la sesión abierta, entra directo (sin login).
  await CuentaService.instancia.restaurar();
  runApp(SmartTallerApp(state: AppState()));
}

class SmartTallerApp extends StatelessWidget {
  const SmartTallerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Smart Taller',
        debugShowCheckedModeBanner: false,
        theme: industryTheme(),
        // Textos del sistema (selector de fecha, etc.) en español (Perú).
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Sin Supabase no hace falta internet: el aviso solo cubre con Supabase.
        builder: (context, child) =>
            GuardaConexion(activa: haySupabase, child: child ?? const SizedBox.shrink()),
        home: const _Raiz(),
      ),
    );
  }
}

/// Muestra el login o el shell según la sesión.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: app.sesionIniciada
          // Guía 12: la sesión se cierra sola por inactividad o al minimizar.
          ? GuardiaInactividad(
              key: const ValueKey('shell'),
              alCerrarSesion: app.cerrarSesion,
              child: const AppShell(),
            )
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
