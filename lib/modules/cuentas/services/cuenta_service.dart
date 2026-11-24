import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, OtpType, PostgrestException, User, UserAttributes;

import '../../../core/services/sesion_service.dart';
import '../../../core/services/supabase_servicio.dart';
import '../../avisos/services/aviso_service.dart';
import '../../catalogo/services/catalogo_service.dart';
import '../../catalogo/services/favoritos_service.dart';
import '../../clientes/services/cliente_service.dart';
import '../../ordenes/services/cotizacion_service.dart';
import '../models/perfil_personal.dart';
import '../models/rol.dart';
import 'limites_sesion.dart';

/// Mensajes de Supabase Auth en español (código o texto del error).
String mensajeCuenta(AuthException e) {
  final codigo = e.code ?? '';
  final texto = e.message.toLowerCase();
  if (codigo == 'invalid_credentials' || texto.contains('invalid login credentials')) {
    return 'Usuario o contraseña incorrectos';
  }
  if (codigo == 'email_not_confirmed') return 'Confirma el correo de la cuenta (o créala con "Auto confirm")';
  if (codigo == 'user_banned') return 'Esta cuenta está deshabilitada';
  if (codigo == 'over_request_rate_limit' || codigo == 'over_email_send_rate_limit') {
    return 'Demasiados intentos. Espera un momento y vuelve a intentarlo';
  }
  if (codigo == 'otp_expired' || texto.contains('expired') || texto.contains('invalid')) {
    return 'El código no es válido o ya venció';
  }
  if (codigo == 'weak_password' || texto.contains('password should be')) {
    return 'La contraseña debe tener al menos 6 caracteres';
  }
  if (codigo == 'same_password') return 'La contraseña nueva debe ser distinta';
  if (texto.contains('network') || texto.contains('socket') || texto.contains('failed host lookup')) {
    return 'Sin conexión a internet';
  }
  return 'No se pudo iniciar sesión (${e.message})';
}

/// Sesión del personal del taller.
///
/// Con Supabase (como el login del panel en la app de referencia): correo y
/// contraseña de Supabase Auth y la fila personal/{uid} con el rol; las
/// políticas RLS y las funciones SQL usan esa misma fila. La sesión queda
/// guardada y al abrir la app se vuelve a leer el rol.
/// Sin Supabase (modo local): modo demo con el rol elegido en el login.
class CuentaService extends ChangeNotifier {
  CuentaService._();

  static final instancia = CuentaService._();

  /// Usuario del modo demo (datos de ejemplo del prototipo).
  static const usuarioDemo = 'g.guerreros';
  static const nombreDemo = 'Giancarlo Guerreros';

  static const _claveSesion = 'sesionPersonal';
  static const _espera = Duration(seconds: 15);

  PerfilPersonal? _perfil;

  PerfilPersonal? get perfil => _perfil;

  bool get sesionIniciada => _perfil != null;

  Rol get rol => _perfil?.rol ?? Rol.jefeTaller;

  /// Sin Supabase: entra en modo demo y no hay cuentas.
  bool get modoLocal => !haySupabase;

  User? get usuario => haySupabase ? supabase.auth.currentUser : null;

  /// Al abrir la app: si la cuenta sigue con sesión (y no venció al estar
  /// minimizada), vuelve a leer su fila en personal y entra directo.
  Future<void> restaurar() async {
    final cuenta = usuario;
    final preferencias = SesionService.instancia.preferencias;
    if (cuenta == null || preferencias?.getBool(_claveSesion) != true) return;
    // Guía 12: Android cerró la app minimizada más tiempo del permitido.
    if (LimitesSesion.vencioEnSegundoPlano(preferencias, DateTime.now())) {
      await cerrarSesion();
      return;
    }
    try {
      final perfil = await _leerPerfil(cuenta);
      if (perfil == null) {
        await cerrarSesion();
        return;
      }
      await _abrir(perfil);
    } catch (_) {
      // sin conexión: se vuelve a pedir el login
    }
  }

  /// Ingresa con [usuario] (correo con Supabase) y [contrasena]. En modo
  /// local entra como demo con [rolDemo].
  Future<PerfilPersonal> ingresar({
    required String usuario,
    required String contrasena,
    Rol rolDemo = Rol.jefeTaller,
  }) async {
    if (usuario.trim().isEmpty) throw StateError('Ingrese su usuario');
    if (contrasena.isEmpty) throw StateError('Ingrese su contraseña');
    if (!haySupabase) {
      final nombre = usuario.trim() == usuarioDemo ? nombreDemo : usuario.trim();
      final perfil = PerfilPersonal(
        uid: SesionService.instancia.usuarioId,
        nombre: nombre,
        correo: '',
        rol: rolDemo,
        inicioSesion: DateTime.now(),
      );
      await _abrir(perfil, guardar: false);
      return perfil;
    }
    try {
      final respuesta = await supabase.auth
          .signInWithPassword(email: usuario.trim(), password: contrasena)
          .timeout(_espera);
      return await _entrarConCuenta(respuesta.user);
    } on AuthException catch (e) {
      throw StateError(mensajeCuenta(e));
    } on TimeoutException {
      throw StateError('Sin conexión a internet');
    }
  }

  /// "¿Olvidaste tu contraseña?": Supabase envía un correo con un código de
  /// 6 dígitos (plantilla "Reset Password" con {{ .Token }}, ver README).
  Future<void> recuperarContrasena(String correo) async {
    if (!haySupabase) {
      throw StateError('Sin Supabase no hay cuentas: pide la contraseña al administrador');
    }
    try {
      await supabase.auth.resetPasswordForEmail(correo.trim()).timeout(_espera);
    } on AuthException catch (e) {
      throw StateError(mensajeCuenta(e));
    } on TimeoutException {
      throw StateError('Sin conexión a internet');
    }
  }

  /// Con el código del correo cambia la contraseña y entra a la app.
  Future<PerfilPersonal> cambiarContrasenaConCodigo({
    required String correo,
    required String codigo,
    required String nueva,
  }) async {
    if (!haySupabase) throw StateError('Supabase no está configurado');
    try {
      final respuesta = await supabase.auth
          .verifyOTP(email: correo.trim(), token: codigo.trim(), type: OtpType.recovery)
          .timeout(_espera);
      await supabase.auth.updateUser(UserAttributes(password: nueva)).timeout(_espera);
      return await _entrarConCuenta(respuesta.user ?? supabase.auth.currentUser);
    } on AuthException catch (e) {
      throw StateError(mensajeCuenta(e));
    } on TimeoutException {
      throw StateError('Sin conexión a internet');
    }
  }

  Future<PerfilPersonal> _entrarConCuenta(User? cuenta) async {
    if (cuenta == null) throw StateError('No se pudo iniciar sesión');
    try {
      final perfil = await _leerPerfil(cuenta);
      if (perfil == null) {
        await supabase.auth.signOut();
        throw StateError('Esta cuenta no pertenece al personal del taller o está inactiva');
      }
      await _abrir(perfil);
      return perfil;
    } on PostgrestException catch (e) {
      await supabase.auth.signOut();
      throw StateError('No se pudo leer tu perfil: ${mensajePostgrest(e)}');
    }
  }

  /// Cierra la sesión: borra el borrador, favoritos y datos del dispositivo.
  Future<void> cerrarSesion() async {
    if (haySupabase) {
      // Sin sesión las políticas RLS no devuelven nada: las suscripciones se
      // vuelven a abrir al iniciar sesión. (En modo local los datos siguen en
      // memoria.)
      CatalogoService.instancia.reiniciarLocal();
      AvisoService.instancia.reiniciarLocal();
      ClienteService.instancia.detener();
      try {
        await supabase.auth.signOut();
      } catch (_) {
        // sin conexión: la sesión local se borra igual
      }
    }
    CotizacionService.instancia.vaciar(remoto: false);
    FavoritosService.instancia.reiniciar();
    await LimitesSesion.limpiarSegundoPlano(SesionService.instancia.preferencias);
    await SesionService.instancia.cerrarSesion();
    _perfil = null;
    notifyListeners();
  }

  Future<PerfilPersonal?> _leerPerfil(User cuenta) async {
    final fila = await supabase.from('personal').select().eq('id', cuenta.id).maybeSingle().timeout(_espera);
    if (fila == null) return null;
    return PerfilPersonal.desdeMapa(fila, correo: cuenta.email ?? '');
  }

  Future<void> _abrir(PerfilPersonal perfil, {bool guardar = true}) async {
    if (haySupabase) SesionService.instancia.usarCuenta(perfil.uid);
    _perfil = perfil;
    // Datos en tiempo real del taller (sin Supabase no hacen nada).
    CatalogoService.instancia.iniciar();
    AvisoService.instancia.iniciar();
    ClienteService.instancia.iniciar();
    // Primero la pantalla, después el disco.
    notifyListeners();
    unawaited(CotizacionService.instancia.cargar());
    unawaited(FavoritosService.instancia.cargar());
    if (guardar) await SesionService.instancia.preferencias?.setBool(_claveSesion, true);
  }

  /// Solo para pruebas: entra sin pasar por el login.
  @visibleForTesting
  void entrarDemo(Rol rol, {String nombre = nombreDemo}) {
    _perfil = PerfilPersonal(uid: SesionService.instancia.usuarioId, nombre: nombre, correo: '', rol: rol);
    notifyListeners();
  }
}
