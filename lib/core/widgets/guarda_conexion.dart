import 'package:flutter/material.dart';

import '../../theme/blueprint.dart';
import '../../theme/industry_theme.dart';
import '../services/conexion.dart';

/// Cubre la app mientras no hay internet. Al volver la red, desaparece sola.
class PantallaSinConexion extends StatefulWidget {
  const PantallaSinConexion({super.key});

  @override
  State<PantallaSinConexion> createState() => _PantallaSinConexionState();
}

class _PantallaSinConexionState extends State<PantallaSinConexion> {
  bool _reintentando = false;

  Future<void> _reintentar() async {
    if (_reintentando) return;
    setState(() => _reintentando = true);
    await Conexion.instancia.comprobar();
    if (mounted) setState(() => _reintentando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sin conexión', style: Ind.kicker()),
              const SizedBox(height: 6),
              Text('Sin conexión a Internet', style: Ind.heading(25)),
              const SizedBox(height: 6),
              Text(
                'Las órdenes y el inventario se sincronizan con Supabase. '
                'Revisa el Wi-Fi o los datos del equipo.',
                style: Ind.body(13, color: Ind.muted),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _reintentando ? 'Un momento…' : 'Reintentar',
                onPressed: _reintentando ? null : _reintentar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mantiene la app montada y tapa la pantalla si no hay internet.
/// Con [activa] en false (modo local, sin Supabase) no hace nada.
class GuardaConexion extends StatefulWidget {
  const GuardaConexion({super.key, required this.child, this.activa = true});

  final Widget child;
  final bool activa;

  @override
  State<GuardaConexion> createState() => _GuardaConexionState();
}

class _GuardaConexionState extends State<GuardaConexion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (!widget.activa) return;
    WidgetsBinding.instance.addObserver(this);
    Conexion.instancia.iniciar();
  }

  @override
  void dispose() {
    if (widget.activa) {
      WidgetsBinding.instance.removeObserver(this);
      Conexion.instancia.detener();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) Conexion.instancia.comprobar();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activa) return widget.child;
    return ListenableBuilder(
      listenable: Conexion.instancia,
      builder: (context, _) {
        final conexion = Conexion.instancia;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (!conexion.comprobado)
              const Positioned.fill(child: ColoredBox(color: Ind.bg)),
            if (conexion.comprobado && !conexion.enLinea)
              const Positioned.fill(child: PantallaSinConexion()),
          ],
        );
      },
    );
  }
}
