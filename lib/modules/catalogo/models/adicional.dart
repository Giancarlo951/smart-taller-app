import '../../../core/utils/formatos.dart';

/// Adicional que se suma a un servicio (lavado de motor, revisión de 21
/// puntos...). Equivale a los extras de la app de referencia.
class Adicional {
  const Adicional({
    required this.id,
    required this.nombre,
    required this.precioCentimos,
    this.disponible = true,
  });

  final String id;
  final String nombre;
  final int precioCentimos;
  final bool disponible;

  factory Adicional.desdeMapa(Map<String, dynamic> fila) => Adicional(
    id: '${fila['id']}',
    nombre: fila['nombre'] ?? '',
    precioCentimos: leerInt(fila['precio_centimos']),
    disponible: fila['disponible'] != false,
  );

  Map<String, dynamic> aMapa() => {
    'id': id,
    'nombre': nombre,
    'precio_centimos': precioCentimos,
    'disponible': disponible,
  };
}
