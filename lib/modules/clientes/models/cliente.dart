import '../../../core/utils/formatos.dart';
import '../../catalogo/models/servicio.dart';

/// Vehículo de un cliente (JSON vehiculos de la tabla clientes).
/// Equivale a las direcciones guardadas del cliente en la app de referencia.
class Vehiculo {
  const Vehiculo({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.tipo = TiposVehiculo.auto,
    this.km = 0,
    this.ultimoServicio,
  });

  /// V2K-841
  final String placa;
  final String marca;
  final String modelo;
  final int anio;

  /// auto, suv o pesado (define el precio de la mano de obra).
  final String tipo;

  /// Último kilometraje registrado.
  final int km;
  final DateTime? ultimoServicio;

  /// "Toyota Yaris 2019"
  String get descripcion => '$marca $modelo $anio'.trim();

  /// "jul 2026" o "sin servicios".
  String get ultimoServicioTexto {
    final fecha = ultimoServicio;
    if (fecha == null) return 'sin servicios';
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  Vehiculo copyWith({
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? tipo,
    int? km,
    DateTime? ultimoServicio,
  }) => Vehiculo(
    placa: placa ?? this.placa,
    marca: marca ?? this.marca,
    modelo: modelo ?? this.modelo,
    anio: anio ?? this.anio,
    tipo: tipo ?? this.tipo,
    km: km ?? this.km,
    ultimoServicio: ultimoServicio ?? this.ultimoServicio,
  );

  /// Elemento de clientes.vehiculos (JSON).
  factory Vehiculo.desdeMapa(Map<String, dynamic> datos) => Vehiculo(
    placa: datos['placa'] ?? '',
    marca: datos['marca'] ?? '',
    modelo: datos['modelo'] ?? '',
    anio: leerInt(datos['anio']),
    tipo: datos['tipo'] ?? TiposVehiculo.auto,
    km: leerInt(datos['km']),
    ultimoServicio: leerFechaOpcional(datos['ultimo_servicio']),
  );

  Map<String, dynamic> aMapa() => {
    'placa': placa,
    'marca': marca,
    'modelo': modelo,
    'anio': anio,
    'tipo': tipo,
    'km': km,
    'ultimo_servicio': ultimoServicio == null ? null : fechaIso(ultimoServicio!),
  };
}

/// Cliente del taller (tabla clientes): persona (DNI) o empresa (RUC).
class Cliente {
  const Cliente({
    this.id = '',
    required this.nombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.telefono,
    this.correo = '',
    this.vehiculos = const [],
    this.servicios = 0,
    required this.creadoEn,
  });

  static const dni = 'DNI';
  static const ruc = 'RUC';

  final String id;

  /// Nombre completo o razón social.
  final String nombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final String telefono;
  final String correo;
  final List<Vehiculo> vehiculos;

  /// Órdenes atendidas.
  final int servicios;
  final DateTime creadoEn;

  bool get esEmpresa => tipoDocumento == ruc;

  /// "DNI 45120884" o "RUC 20486112094".
  String get documento => '$tipoDocumento $numeroDocumento';

  Vehiculo? vehiculo(String placa) {
    for (final v in vehiculos) {
      if (v.placa == placa) return v;
    }
    return null;
  }

  Cliente copyWith({
    String? id,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    String? telefono,
    String? correo,
    List<Vehiculo>? vehiculos,
    int? servicios,
  }) => Cliente(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    tipoDocumento: tipoDocumento ?? this.tipoDocumento,
    numeroDocumento: numeroDocumento ?? this.numeroDocumento,
    telefono: telefono ?? this.telefono,
    correo: correo ?? this.correo,
    vehiculos: vehiculos ?? this.vehiculos,
    servicios: servicios ?? this.servicios,
    creadoEn: creadoEn,
  );

  /// Fila de la tabla clientes.
  factory Cliente.desdeMapa(Map<String, dynamic> fila) => Cliente(
    id: '${fila['id'] ?? ''}',
    nombre: fila['nombre'] ?? '',
    tipoDocumento: fila['tipo_documento'] ?? dni,
    numeroDocumento: fila['numero_documento'] ?? '',
    telefono: fila['telefono'] ?? '',
    correo: fila['correo'] ?? '',
    vehiculos: leerListaMapas(fila['vehiculos']).map(Vehiculo.desdeMapa).toList(),
    servicios: leerInt(fila['servicios']),
    creadoEn: leerFecha(fila['created_at']),
  );

  /// Columnas a guardar. `placas` la llena un trigger (y no deja repetir
  /// una placa entre clientes); el id lo genera la base.
  Map<String, dynamic> aMapa() => {
    'nombre': nombre,
    'tipo_documento': tipoDocumento,
    'numero_documento': numeroDocumento,
    'telefono': telefono,
    'correo': correo,
    'vehiculos': vehiculos.map((v) => v.aMapa()).toList(),
    'servicios': servicios,
  };
}
