import '../../../core/utils/formatos.dart';

enum EstadoCita {
  confirmada('confirmada', 'Confirmada'),
  enTaller('enTaller', 'En taller'),
  atendida('atendida', 'Atendida'),
  cancelada('cancelada', 'Cancelada'),
  noAsistio('noAsistio', 'No asistió');

  const EstadoCita(this.valor, this.label);
  final String valor;
  final String label;

  static EstadoCita desde(String? valor) => EstadoCita.values.firstWhere(
    (e) => e.valor == valor || e.name == valor,
    orElse: () => EstadoCita.confirmada,
  );

  /// Ocupa una bahía a su hora.
  bool get ocupaBahia => this != cancelada && this != noAsistio;

  /// Cambios permitidos desde este estado.
  List<EstadoCita> get siguientes => switch (this) {
    confirmada => const [enTaller, cancelada, noAsistio],
    enTaller => const [atendida],
    atendida || cancelada || noAsistio => const [],
  };
}

/// Cita agendada (tabla citas).
class Cita {
  const Cita({
    this.id = '',
    required this.fecha,
    required this.servicio,
    required this.placa,
    required this.cliente,
    this.telefono = '',
    this.estado = EstadoCita.confirmada,
    this.ordenId,
    this.nota = '',
  });

  final String id;

  /// Día y hora de la cita.
  final DateTime fecha;
  final String servicio;
  final String placa;
  final String cliente;
  final String telefono;
  final EstadoCita estado;

  /// Orden de trabajo abierta al llegar el vehículo.
  final String? ordenId;
  final String nota;

  /// "08:30"
  String get hora => formatoHora(fecha);

  Cita copyWith({String? id, EstadoCita? estado, String? ordenId, DateTime? fecha}) => Cita(
    id: id ?? this.id,
    fecha: fecha ?? this.fecha,
    servicio: servicio,
    placa: placa,
    cliente: cliente,
    telefono: telefono,
    estado: estado ?? this.estado,
    ordenId: ordenId ?? this.ordenId,
    nota: nota,
  );

  /// Fila de la tabla citas.
  factory Cita.desdeMapa(Map<String, dynamic> fila) => Cita(
    id: '${fila['id'] ?? ''}',
    fecha: leerFecha(fila['fecha']),
    servicio: fila['servicio'] ?? '',
    placa: fila['placa'] ?? '',
    cliente: fila['cliente'] ?? '',
    telefono: fila['telefono'] ?? '',
    estado: EstadoCita.desde(fila['estado']),
    ordenId: fila['orden_id'],
    nota: fila['nota'] ?? '',
  );

  /// Columnas a guardar (el id lo genera la base).
  Map<String, dynamic> aMapa() => {
    'fecha': fechaIso(fecha),
    'servicio': servicio,
    'placa': placa,
    'cliente': cliente,
    'telefono': telefono,
    'estado': estado.valor,
    'orden_id': ordenId,
    'nota': nota,
  };
}
