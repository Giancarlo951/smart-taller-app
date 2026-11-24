import '../../../core/utils/formatos.dart';

/// Categoría del catálogo (tabla categorias): agrupa servicios o repuestos.
/// Equivale a las categorías del menú de la app de referencia.
class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    this.tipo = tipoServicio,
    this.orden = 0,
    this.activa = true,
  });

  static const idTodas = 'todas';
  static const tipoServicio = 'servicio';
  static const tipoRepuesto = 'repuesto';

  /// Filtro "Todos" (no se guarda en la base).
  static const todas = Categoria(id: idTodas, nombre: 'Todos', orden: -1);

  final String id;
  final String nombre;

  /// servicio o repuesto.
  final String tipo;
  final int orden;
  final bool activa;

  bool get esTodas => id == idTodas;

  factory Categoria.desdeMapa(Map<String, dynamic> fila) => Categoria(
    id: '${fila['id']}',
    nombre: fila['nombre'] ?? '',
    tipo: fila['tipo'] ?? tipoServicio,
    orden: leerInt(fila['orden']),
    activa: fila['activa'] != false,
  );

  Map<String, dynamic> aMapa() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'orden': orden,
    'activa': activa,
  };
}
