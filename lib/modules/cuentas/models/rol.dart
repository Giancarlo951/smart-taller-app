/// Roles del personal. [valor] es el campo `rol` de personal/{uid}.
enum Rol {
  jefeTaller('jefe_taller', 'Jefe de taller'),
  mecanico('mecanico', 'Mecánico'),
  administracion('administracion', 'Administración');

  const Rol(this.valor, this.label);

  final String valor;
  final String label;

  static Rol? desde(String? valor) {
    for (final r in Rol.values) {
      if (r.valor == valor || r.name == valor) return r;
    }
    return null;
  }
}
