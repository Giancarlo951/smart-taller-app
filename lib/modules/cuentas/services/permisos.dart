import '../models/rol.dart';

/// Qué puede hacer cada rol. Las mismas reglas están en firestore.rules
/// (tieneRol), así que la app y el servidor coinciden.
abstract final class Permisos {
  static bool _es(Rol rol, Set<Rol> roles) => roles.contains(rol);

  /// Solo el jefe de taller marca una orden como "Listo para entrega".
  static bool puedeCompletarOrden(Rol rol) => rol == Rol.jefeTaller;

  static bool puedeEntregarVehiculo(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  static bool puedeAnularOrden(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  static bool puedeCobrar(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  /// Confirmar un Yape/Plin con su N.° de operación.
  static bool puedeAprobarPago(Rol rol) => rol == Rol.administracion;

  static bool puedeFacturar(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  /// Precios, servicios y repuestos del catálogo.
  static bool puedeEditarCatalogo(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  /// Ingreso de mercadería e inventario físico.
  static bool puedeMoverStock(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  static bool puedeVerReportes(Rol rol) =>
      _es(rol, {Rol.jefeTaller, Rol.administracion});

  static bool puedeEliminarClientes(Rol rol) => rol == Rol.administracion;

  /// Subir el catálogo de ejemplo a Supabase.
  static bool puedeCargarDatosEjemplo(Rol rol) => rol == Rol.administracion;
}
