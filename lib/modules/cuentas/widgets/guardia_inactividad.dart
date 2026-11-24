import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/sesion_service.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../theme/industry_theme.dart';
import '../services/limites_sesion.dart';

/// Guía 12: cierre automático de la sesión del personal.
///
/// - 12.4 Inactividad: cada toque reinicia el reloj. A los 5 minutos sin
///   tocar sale "¿Sigues ahí?" y, si nadie responde en 30 s, se cierra.
/// - 12.2 Al minimizar: escucha el ciclo de vida con
///   `WidgetsBindingObserver`. Si la app vuelve después de 1 minuto, la
///   sesión ya está cerrada.
class GuardiaInactividad extends StatefulWidget {
  const GuardiaInactividad({
    super.key,
    required this.alCerrarSesion,
    required this.child,
    this.inactividad = LimitesSesion.inactividad,
    this.aviso = LimitesSesion.aviso,
    this.enSegundoPlano = LimitesSesion.enSegundoPlano,
    this.ahora = DateTime.now,
  });

  final Future<void> Function() alCerrarSesion;
  final Widget child;
  final Duration inactividad;
  final Duration aviso;
  final Duration enSegundoPlano;

  /// Hora actual (los tests la adelantan sin esperar).
  final DateTime Function() ahora;

  @override
  State<GuardiaInactividad> createState() => _GuardiaInactividadState();
}

class _GuardiaInactividadState extends State<GuardiaInactividad> with WidgetsBindingObserver {
  Timer? _reloj;
  DateTime? _enFondoDesde;
  bool _avisando = false;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reiniciarReloj();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    // Cerrar sesión a mano: ya no hay minimizado pendiente.
    LimitesSesion.limpiarSegundoPlano(SesionService.instancia.preferencias);
    super.dispose();
  }

  void _reiniciarReloj() {
    if (_avisando || _cerrando) return;
    _reloj?.cancel();
    _reloj = Timer(widget.inactividad, _avisar);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // En la web, cambiar de pestaña cuenta como "minimizar": ahí solo vale
    // la inactividad.
    if (kIsWeb) return;
    final preferencias = SesionService.instancia.preferencias;
    switch (estado) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_enFondoDesde != null) return;
        _enFondoDesde = widget.ahora();
        _reloj?.cancel();
        LimitesSesion.marcarSegundoPlano(preferencias, _enFondoDesde!);
      case AppLifecycleState.resumed:
        final desde = _enFondoDesde;
        _enFondoDesde = null;
        LimitesSesion.limpiarSegundoPlano(preferencias);
        if (desde != null && widget.ahora().difference(desde) >= widget.enSegundoPlano) {
          _cerrar('Por seguridad cerramos la sesión: la app quedó minimizada');
        } else {
          _reiniciarReloj();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _avisar() async {
    if (!mounted || _cerrando) return;
    _avisando = true;
    HapticFeedback.heavyImpact();
    final seguir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AvisoInactividad(aviso: widget.aviso),
    );
    _avisando = false;
    if (!mounted) return;
    if (seguir ?? false) {
      _reiniciarReloj();
    } else {
      _cerrar('Cerramos la sesión por inactividad');
    }
  }

  Future<void> _cerrar(String motivo) async {
    if (_cerrando || !mounted) return;
    _cerrando = true;
    _reloj?.cancel();
    final mensajero = ScaffoldMessenger.maybeOf(context);
    // Hojas o diálogos abiertos encima también se cierran.
    Navigator.of(context, rootNavigator: true).popUntil((ruta) => ruta.isFirst);
    await widget.alCerrarSesion();
    mostrarMensaje(mensajero, motivo);
  }

  @override
  Widget build(BuildContext context) {
    // translucent: el toque sigue llegando a los botones.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciarReloj(),
      child: widget.child,
    );
  }
}

/// "¿Sigues ahí?" con la cuenta regresiva. true = sigue en la app.
class _AvisoInactividad extends StatefulWidget {
  const _AvisoInactividad({required this.aviso});

  final Duration aviso;

  @override
  State<_AvisoInactividad> createState() => _AvisoInactividadState();
}

class _AvisoInactividadState extends State<_AvisoInactividad> {
  late int _restantes = widget.aviso.inSeconds;
  Timer? _cuenta;

  @override
  void initState() {
    super.initState();
    _cuenta = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restantes <= 1) {
        t.cancel();
        Navigator.pop(context, false);
        return;
      }
      setState(() => _restantes--);
    });
  }

  @override
  void dispose() {
    _cuenta?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Sigues ahí?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Por seguridad cerraremos la sesión en $_restantes s.'),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: _restantes / widget.aviso.inSeconds, color: Ind.accent),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar sesión')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sigo aquí')),
      ],
    );
  }
}
