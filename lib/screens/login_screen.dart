import 'package:flutter/material.dart';

import '../core/services/supabase_servicio.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/cuentas/models/rol.dart';
import '../modules/cuentas/services/cuenta_service.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/estado_tag.dart';
import '../widgets/ind_field.dart';
import '../widgets/logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Sin Supabase: usuario de demo. Con Supabase: el correo de la cuenta.
  final _usuario = TextEditingController(text: haySupabase ? '' : CuentaService.usuarioDemo);
  final _clave = TextEditingController();
  bool _ingresando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_ingresando || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _ingresando = true;
      _error = null;
    });
    try {
      await AppScope.read(context).iniciarSesion(usuario: _usuario.text, contrasena: _clave.text);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _ingresando = false);
    }
  }

  /// Envía el código de recuperación y pide el código y la contraseña nueva.
  Future<void> _recuperar() async {
    final error = Validadores.correo(_usuario.text);
    final mensajero = ScaffoldMessenger.of(context);
    if (error != null) {
      mostrarMensaje(mensajero, 'Escribe tu correo arriba para enviarte el código', error: true);
      return;
    }
    try {
      await CuentaService.instancia.recuperarContrasena(_usuario.text);
    } catch (e) {
      mostrarMensaje(mensajero, mensajeError(e), error: true);
      return;
    }
    if (!mounted) return;
    mostrarMensaje(mensajero, 'Te enviamos un código a ${_usuario.text.trim()}');
    await showDialog<void>(
      context: context,
      builder: (_) => _DialogoNuevaContrasena(correo: _usuario.text.trim()),
    );
  }

  String? _requerido(String? v, String campo) =>
      (v == null || v.trim().isEmpty) ? 'Ingrese su $campo' : null;

  @override
  Widget build(BuildContext context) {
    // PC: panel azul con la marca a la izquierda y el formulario a la derecha.
    if (MediaQuery.sizeOf(context).width >= Ind.anchoEscritorio) {
      return Scaffold(
        backgroundColor: Ind.card,
        body: Row(children: [
          const Expanded(child: _PanelMarca()),
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _formulario(context, [
                      Text('Bienvenido', style: Ind.heading(28, height: 1.2)),
                      const SizedBox(height: 4),
                      Text('Ingresa con tu cuenta del taller', style: Ind.body(14.5, color: Ind.muted)),
                      const SizedBox(height: 28),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    }

    // Celular o tablet vertical: todo en una columna (hasta 440 px de ancho).
    return Scaffold(
      backgroundColor: Ind.card,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _formulario(context, [
                    // — Solo el logotipo sobre el formulario —
                    const Center(child: LogoSmartTaller(ancho: 200)),
                    const SizedBox(height: 36),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formulario de ingreso con [encabezado] arriba (marca en celular,
  /// saludo en PC).
  Widget _formulario(BuildContext context, List<Widget> encabezado) {
    final app = AppScope.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...encabezado,

          // — Formulario —
          IndField(
            label: haySupabase ? 'Correo' : 'Usuario',
            child: TextFormField(
              controller: _usuario,
              style: Ind.body(14, height: 1.3),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              keyboardType: haySupabase ? TextInputType.emailAddress : TextInputType.text,
              autofillHints: const [AutofillHints.username],
              validator: (v) => haySupabase ? Validadores.correo(v) : _requerido(v, 'usuario'),
            ),
          ),
          const SizedBox(height: 14),
          IndField(
            label: 'Contraseña',
            child: TextFormField(
              controller: _clave,
              style: Ind.body(14, height: 1.3),
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _ingresar(),
              validator: (v) => haySupabase ? Validadores.contrasena(v) : _requerido(v, 'contraseña'),
            ),
          ),
          // Con Supabase el rol viene de la tabla personal; sin
          // Supabase se elige aquí (modo demo).
          if (!haySupabase) ...[
            const SizedBox(height: 14),
            IndField(
              label: 'Rol',
              child: Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final r in Rol.values)
                    TagChip(label: r.label, selected: app.rol == r, onTap: () => app.seleccionarRol(r)),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: Ind.body(12.5, color: Ind.peligro, height: 1.4)),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: _ingresando ? 'Ingresando…' : 'Ingresar',
            onPressed: _ingresando ? null : _ingresar,
          ),
          if (haySupabase) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(onPressed: _recuperar, child: const Text('¿Olvidaste tu contraseña?')),
            ),
          ],
          const SizedBox(height: 22),

          // — Nota legal —
          Text(
            haySupabase
                ? 'Acceso solo para el personal registrado. Sus datos se tratan '
                      'conforme a la Ley N° 29733 de protección de datos personales.'
                : 'Modo demo (sin Supabase): datos de ejemplo en este equipo. Sus datos '
                      'se tratan conforme a la Ley N° 29733 de protección de datos personales.',
            textAlign: TextAlign.center,
            style: Ind.body(11.5, color: Ind.n400, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Panel azul de la izquierda en PC: el logotipo grande, en una tarjeta
/// blanca para que se lean sus colores (sobre el azul no se distinguiría).
class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Ind.a900, Ind.a700, Ind.a600],
        ),
      ),
      padding: const EdgeInsets.all(44),
      child: LayoutBuilder(
        builder: (context, c) {
          // El logo crece con el panel, hasta 380 px de ancho.
          final ancho = (c.maxWidth * 0.62).clamp(220.0, 380.0);
          return Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ancho * 0.16, vertical: ancho * 0.14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: Ind.shadowLg,
              ),
              child: Semantics(header: true, child: LogoSmartTaller(ancho: ancho)),
            ),
          );
        },
      ),
    );
  }
}

/// Código del correo de recuperación + contraseña nueva. Al confirmar entra
/// directo a la app.
class _DialogoNuevaContrasena extends StatefulWidget {
  const _DialogoNuevaContrasena({required this.correo});

  final String correo;

  @override
  State<_DialogoNuevaContrasena> createState() => _DialogoNuevaContrasenaState();
}

class _DialogoNuevaContrasenaState extends State<_DialogoNuevaContrasena> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    try {
      await CuentaService.instancia.cambiarContrasenaConCodigo(
        correo: widget.correo,
        codigo: _codigo.text,
        nueva: _nueva.text,
      );
      navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Escribe el código que llegó a ${widget.correo}.', style: Ind.body(13)),
            const SizedBox(height: 12),
            IndField(
              label: 'Código',
              child: TextFormField(
                controller: _codigo,
                keyboardType: TextInputType.number,
                validator: (v) => RegExp(r'^\d{6,10}$').hasMatch((v ?? '').trim()) ? null : 'Ingrese el código del correo',
              ),
            ),
            const SizedBox(height: 10),
            IndField(
              label: 'Contraseña nueva',
              child: TextFormField(controller: _nueva, obscureText: true, validator: Validadores.contrasena),
            ),
            const SizedBox(height: 10),
            IndField(
              label: 'Repite la contraseña',
              child: TextFormField(
                controller: _repetida,
                obscureText: true,
                validator: (v) => v == _nueva.text ? null : 'Las contraseñas no coinciden',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: Ind.body(12, color: const Color(0xFFB3261E), height: 1.4)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardando ? null : _guardar, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
      ],
    );
  }
}
