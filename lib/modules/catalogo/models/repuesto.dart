import '../../../core/utils/formatos.dart';

/// Repuesto o insumo del almacén (tabla repuestos, clave = código).
class Repuesto {
  const Repuesto({
    required this.codigo,
    required this.nombre,
    this.categoriaId = '',
    this.marca = '',
    required this.precioCentimos,
    required this.stock,
    required this.minimo,
    this.activo = true,
  });

  /// LUB-1040, FIL-TY02... (también es el id del documento).
  final String codigo;
  final String nombre;
  final String categoriaId;
  final String marca;
  final int precioCentimos;
  final int stock;
  final int minimo;

  /// false = descontinuado: no se puede agregar a una orden.
  final bool activo;

  String get id => codigo;

  /// Stock crítico: por debajo del mínimo.
  bool get critico => stock < minimo;

  bool get agotado => stock <= 0;

  /// Se puede agregar a una orden.
  bool get disponible => activo && !agotado;

  /// Nivel para la barra: 100 % equivale a tres veces el mínimo.
  double get nivel =>
      minimo <= 0 ? 1 : (stock / (minimo * 3)).clamp(0.0, 1.0);

  /// Unidades que faltan para volver a tres veces el mínimo.
  int get sugeridoReponer => critico ? minimo * 3 - stock : 0;

  /// Precio en soles (para la UI).
  double get precio => precioCentimos / 100;

  Repuesto copyWith({
    String? codigo,
    String? nombre,
    String? categoriaId,
    String? marca,
    int? precioCentimos,
    int? stock,
    int? minimo,
    bool? activo,
  }) => Repuesto(
    codigo: codigo ?? this.codigo,
    nombre: nombre ?? this.nombre,
    categoriaId: categoriaId ?? this.categoriaId,
    marca: marca ?? this.marca,
    precioCentimos: precioCentimos ?? this.precioCentimos,
    stock: stock ?? this.stock,
    minimo: minimo ?? this.minimo,
    activo: activo ?? this.activo,
  );

  /// Fila de la tabla repuestos.
  factory Repuesto.desdeMapa(Map<String, dynamic> fila) => Repuesto(
    codigo: '${fila['codigo']}',
    nombre: fila['nombre'] ?? '',
    categoriaId: fila['categoria_id'] ?? '',
    marca: fila['marca'] ?? '',
    precioCentimos: leerInt(fila['precio_centimos']),
    stock: leerInt(fila['stock']),
    minimo: leerInt(fila['minimo']),
    activo: fila['activo'] != false,
  );

  Map<String, dynamic> aMapa() => {
    'codigo': codigo,
    'nombre': nombre,
    'categoria_id': categoriaId,
    'marca': marca,
    'precio_centimos': precioCentimos,
    'stock': stock,
    'minimo': minimo,
    'activo': activo,
  };
}
