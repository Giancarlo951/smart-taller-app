import '../../../core/utils/formatos.dart';

/// Fila config 'taller': datos del local, cobros, comprobantes y metas.
/// Equivale a config/store de la app de referencia.
class ConfigTaller {
  const ConfigTaller({
    required this.nombre,
    this.razonSocial = '',
    this.ruc = '',
    this.ciudad = '',
    this.direccion = '',
    this.horario = '',
    this.abierto = true,
    this.recargoDomicilioCentimos = 0,
    this.minimoOrdenCentimos = 0,
    this.whatsapp = '',
    this.numeroYape = '',
    this.numeroPlin = '',
    this.serieBoleta = 'B001',
    this.serieFactura = 'F001',
    this.metaHorasServicio = 4,
    this.bahias = 3,
    this.mecanicos = const [],
  });

  final String nombre;
  final String razonSocial;
  final String ruc;
  final String ciudad;
  final String direccion;

  /// "Lun a Sáb · 08:00 – 19:00" (el gráfico por hora usa este rango).
  final String horario;
  final bool abierto;

  /// Servicio a domicilio / recojo del vehículo (equivale al delivery).
  final int recargoDomicilioCentimos;
  final int minimoOrdenCentimos;
  final String whatsapp;
  final String numeroYape;
  final String numeroPlin;
  final String serieBoleta;
  final String serieFactura;

  /// Meta de tiempo de servicio (recepción → listo), en horas.
  final int metaHorasServicio;

  /// Citas que se pueden atender a la misma hora.
  final int bahias;
  final List<String> mecanicos;

  /// Hora de apertura y última hora de atención según [horario]
  /// ("08:00 – 19:00" → 8 a 18). Sin horario: 8 a 18.
  (int, int) get rangoHoras {
    final hora = RegExp(
      r'(\d{1,2}):(\d{2})\D+(\d{1,2}):(\d{2})',
    ).firstMatch(horario);
    if (hora == null) return (8, 18);
    final apertura = int.parse(hora[1]!);
    final cierre = int.parse(hora[3]!);
    final ultima = int.parse(hora[4]!) > 0 ? cierre : cierre - 1;
    if (ultima < apertura) return (8, 18);
    return (apertura, ultima);
  }

  /// Columna `datos` de la fila config 'taller'.
  factory ConfigTaller.desdeMapa(Map<String, dynamic> datos) => ConfigTaller(
    nombre: datos['nombre'] ?? 'Taller',
    razonSocial: datos['razon_social'] ?? '',
    ruc: datos['ruc'] ?? '',
    ciudad: datos['ciudad'] ?? '',
    direccion: datos['direccion'] ?? '',
    horario: datos['horario'] ?? '',
    abierto: datos['abierto'] != false,
    recargoDomicilioCentimos: leerInt(datos['recargo_domicilio_centimos']),
    minimoOrdenCentimos: leerInt(datos['minimo_orden_centimos']),
    whatsapp: datos['whatsapp'] ?? '',
    numeroYape: datos['numero_yape'] ?? '',
    numeroPlin: datos['numero_plin'] ?? '',
    serieBoleta: datos['serie_boleta'] ?? 'B001',
    serieFactura: datos['serie_factura'] ?? 'F001',
    metaHorasServicio: datos['meta_horas_servicio'] == null ? 4 : leerInt(datos['meta_horas_servicio']),
    bahias: datos['bahias'] == null ? 3 : leerInt(datos['bahias']),
    mecanicos: leerListaTextos(datos['mecanicos']),
  );

  Map<String, dynamic> aMapa() => {
    'nombre': nombre,
    'razon_social': razonSocial,
    'ruc': ruc,
    'ciudad': ciudad,
    'direccion': direccion,
    'horario': horario,
    'abierto': abierto,
    'recargo_domicilio_centimos': recargoDomicilioCentimos,
    'minimo_orden_centimos': minimoOrdenCentimos,
    'whatsapp': whatsapp,
    'numero_yape': numeroYape,
    'numero_plin': numeroPlin,
    // emitir_comprobante (SQL) lee las series de aquí.
    'serie_boleta': serieBoleta,
    'serie_factura': serieFactura,
    'meta_horas_servicio': metaHorasServicio,
    'bahias': bahias,
    'mecanicos': mecanicos,
  };
}
