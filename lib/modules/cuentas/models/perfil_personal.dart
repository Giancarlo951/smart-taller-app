import 'rol.dart';

/// Personal con la sesión abierta. Su fila en la tabla `personal` (id = uid
/// de Supabase Auth) se crea desde el SQL Editor (como admins/{uid} en la app
/// de referencia) con `rol` = jefe_taller, mecanico o administracion y,
/// opcionales, `nombre`, `taller` y `activo`.
class PerfilPersonal {
  const PerfilPersonal({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.taller = tallerPorDefecto,
    this.inicioSesion,
  });

  static const tallerPorDefecto = 'Auto Siglo · Huancayo';

  final String uid;
  final String nombre;
  final String correo;
  final Rol rol;
  final String taller;
  final DateTime? inicioSesion;

  /// null si la fila no tiene un rol válido o la cuenta está inactiva.
  static PerfilPersonal? desdeMapa(Map<String, dynamic> fila, {required String correo}) {
    final rol = Rol.desde(fila['rol'] as String?);
    if (rol == null || fila['activo'] == false) return null;
    final nombre = (fila['nombre'] as String?)?.trim();
    final taller = (fila['taller'] as String?)?.trim();
    return PerfilPersonal(
      uid: '${fila['id']}',
      nombre: (nombre != null && nombre.isNotEmpty) ? nombre : correo.split('@').first,
      correo: correo,
      rol: rol,
      taller: (taller != null && taller.isNotEmpty) ? taller : tallerPorDefecto,
      inicioSesion: DateTime.now(),
    );
  }
}
