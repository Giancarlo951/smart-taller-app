import '../../../core/utils/formatos.dart';
import '../../catalogo/models/servicio.dart';
import 'calculadora_precios.dart';
import 'linea_cotizacion.dart';

/// Estados de una orden de trabajo. [valor] es lo que se guarda en la columna
/// ordenes.estado. Las 5 primeras son las etapas de la línea de tiempo;
/// "Entregado" cierra la orden y "Anulada" la cancela.
enum EstadoOrden {
  recepcion('recepcion', 'Recepción', 'Recepción', 'Ingreso y check-list del vehículo'),
  diagnostico('diagnostico', 'Diagnóstico', 'Diagnóstico', 'Revisión del técnico asignado'),
  repuestos('repuestos', 'Repuestos', 'Repuestos', 'Salida de almacén, stock descontado'),
  reparacion('reparacion', 'En reparación', 'Reparación', 'Trabajo en bahía'),
  listo('listo', 'Listo', 'Listo para entrega', 'Aviso al cliente y facturación'),
  entregado('entregado', 'Entregado', 'Entregado', 'Vehículo entregado al cliente'),
  cancelado('cancelado', 'Anulada', 'Anulada', 'Orden anulada');

  const EstadoOrden(this.valor, this.etiqueta, this.titulo, this.nota);

  /// Valor guardado en la base.
  final String valor;

  /// Texto corto de etiquetas y filtros ("En reparación").
  final String etiqueta;

  /// Título de la etapa en la línea de tiempo ("Reparación").
  final String titulo;
  final String nota;

  /// Etapas de la línea de tiempo (Registrar avance llega hasta "Listo").
  static const etapas = [recepcion, diagnostico, repuestos, reparacion, listo];

  /// Flujo completo hasta la entrega (sin la anulación).
  static const flujo = [...etapas, entregado];

  static EstadoOrden desde(String? valor) {
    for (final e in EstadoOrden.values) {
      if (e.valor == valor || e.name == valor) return e;
    }
    return EstadoOrden.recepcion;
  }

  /// Posición en el flujo (-1 si está anulada).
  int get indice => flujo.indexOf(this);

  /// Siguiente etapa de "Registrar avance" (null desde "Listo").
  EstadoOrden? get siguienteEtapa {
    final i = etapas.indexOf(this);
    if (i < 0 || i >= etapas.length - 1) return null;
    return etapas[i + 1];
  }

  /// En el taller: todavía no se entrega ni se anuló.
  bool get activa => this != entregado && this != cancelado;

  /// Desde la etapa Repuestos ya salieron del almacén.
  bool get descuentaStock => indice >= repuestos.indice;

  /// Estados que se agregan al historial al pasar de [actual] a este.
  /// Saltar etapas registra también las intermedias, para que la línea de
  /// tiempo no tenga huecos (igual que confirmed en la app de referencia).
  List<EstadoOrden> pasosDesde(EstadoOrden actual) {
    if (this == cancelado) return [this];
    final desde = actual.indice;
    final hasta = indice;
    if (desde < 0 || hasta <= desde) return [this];
    return flujo.sublist(desde + 1, hasta + 1);
  }
}

/// Estados del cobro (columna estado_pago).
abstract final class EstadosPago {
  static const porCobrar = 'por_cobrar';
  static const verificando = 'verificando';
  static const pagado = 'pagado';
  static const rechazado = 'rechazado';

  static const etiquetas = {
    porCobrar: 'Por cobrar',
    verificando: 'Verificando pago',
    pagado: 'Pagado',
    rechazado: 'Pago rechazado',
  };
}

/// Medios de pago (columna metodo_pago).
abstract final class MetodosPago {
  static const efectivo = 'efectivo';
  static const yape = 'yape';
  static const plin = 'plin';
  static const tarjeta = 'tarjeta';

  static const todos = [efectivo, yape, plin, tarjeta];

  static const etiquetas = {
    efectivo: 'Efectivo',
    yape: 'Yape',
    plin: 'Plin',
    tarjeta: 'Tarjeta',
  };

  static bool esBilletera(String? metodo) => metodo == yape || metodo == plin;
}

/// Adicional guardado dentro de la orden (snapshot con su precio).
class AdicionalOrden {
  const AdicionalOrden({required this.id, required this.nombre, required this.precioCentimos});

  final String id;
  final String nombre;
  final int precioCentimos;

  factory AdicionalOrden.desdeMapa(Map<String, dynamic> datos) => AdicionalOrden(
    id: datos['id'] ?? '',
    nombre: datos['nombre'] ?? '',
    precioCentimos: leerInt(datos['precio_centimos']),
  );

  Map<String, dynamic> aMapa() => {'id': id, 'nombre': nombre, 'precio_centimos': precioCentimos};
}

/// Línea de la orden: servicio o repuesto con el precio del momento.
class LineaOrden {
  const LineaOrden({
    required this.tipo,
    required this.refId,
    required this.nombre,
    this.variante = '',
    this.adicionales = const [],
    required this.precioUnitarioCentimos,
    required this.cantidad,
  });

  final String tipo;
  final String refId;
  final String nombre;
  final String variante;
  final List<AdicionalOrden> adicionales;
  final int precioUnitarioCentimos;
  final int cantidad;

  bool get esRepuesto => tipo == LineaCotizacion.tipoRepuesto;
  bool get esServicio => tipo == LineaCotizacion.tipoServicio;

  int get totalLineaCentimos => precioUnitarioCentimos * cantidad;

  /// "x4 · LUB-1040" o "x1 · Auto / sedán · Lavado de motor"
  String get detalle => [
    'x$cantidad',
    esServicio ? TiposVehiculo.etiqueta(variante) : refId,
    if (adicionales.isNotEmpty) adicionales.map((a) => a.nombre).join(', '),
  ].join(' · ');

  /// Para "Repetir servicio": la misma línea en un borrador nuevo.
  LineaCotizacion aLineaCotizacion({int? precioUnitarioCentimos}) {
    final ids = adicionales.map((a) => a.id).toList();
    return LineaCotizacion(
      id: LineaCotizacion.generarId(tipo, refId, variante: variante, adicionales: ids),
      tipo: tipo,
      refId: refId,
      nombre: nombre,
      variante: variante,
      adicionalIds: ids,
      precioUnitarioCentimos: precioUnitarioCentimos ?? this.precioUnitarioCentimos,
      cantidad: cantidad,
      agregadoEn: DateTime.now(),
    );
  }

  /// Elemento de ordenes.lineas (JSON). Las funciones SQL leen tipo, ref_id,
  /// cantidad y precio_unitario_centimos.
  factory LineaOrden.desdeMapa(Map<String, dynamic> datos) => LineaOrden(
    tipo: datos['tipo'] ?? LineaCotizacion.tipoServicio,
    refId: datos['ref_id'] ?? '',
    nombre: datos['nombre'] ?? '',
    variante: datos['variante'] ?? '',
    adicionales: leerListaMapas(datos['adicionales']).map(AdicionalOrden.desdeMapa).toList(),
    precioUnitarioCentimos: leerInt(datos['precio_unitario_centimos']),
    cantidad: leerInt(datos['cantidad']),
  );

  Map<String, dynamic> aMapa() => {
    'tipo': tipo,
    'ref_id': refId,
    'nombre': nombre,
    'variante': variante,
    'adicionales': adicionales.map((a) => a.aMapa()).toList(),
    'precio_unitario_centimos': precioUnitarioCentimos,
    'cantidad': cantidad,
    'total_centimos': totalLineaCentimos,
  };
}

/// Un cambio de estado guardado en ordenes.historial (con quién lo hizo).
class CambioEstado {
  const CambioEstado({required this.estado, required this.fecha, this.por = '', this.nota = ''});

  final EstadoOrden estado;
  final DateTime fecha;

  /// Nombre del personal que registró el cambio.
  final String por;
  final String nota;

  factory CambioEstado.desdeMapa(Map<String, dynamic> datos) => CambioEstado(
    estado: EstadoOrden.desde(datos['estado']),
    fecha: leerFecha(datos['fecha']),
    por: datos['por'] ?? '',
    nota: datos['nota'] ?? '',
  );

  Map<String, dynamic> aMapa() => {
    'estado': estado.valor,
    'fecha': fechaIso(fecha),
    'por': por,
    'nota': nota,
  };
}

/// Comprobante electrónico emitido para la orden (SUNAT).
class Comprobante {
  const Comprobante({
    required this.tipo,
    required this.serie,
    required this.numero,
    this.documento = '',
    this.razonSocial = '',
    required this.opGravadaCentimos,
    required this.igvCentimos,
    required this.totalCentimos,
    required this.emitidoEn,
    this.estadoSunat = aceptado,
  });

  static const boleta = 'boleta';
  static const factura = 'factura';
  static const aceptado = 'aceptado';
  static const pendiente = 'pendiente';

  final String tipo;
  final String serie;
  final int numero;

  /// DNI o RUC del cliente ('' en boletas menores sin DNI).
  final String documento;
  final String razonSocial;
  final int opGravadaCentimos;
  final int igvCentimos;
  final int totalCentimos;
  final DateTime emitidoEn;
  final String estadoSunat;

  bool get esFactura => tipo == factura;

  /// B001-00248
  String get codigo => '$serie-${correlativo(numero)}';

  String get etiquetaTipo => esFactura ? 'Factura electrónica' : 'Boleta electrónica';

  /// Columna ordenes.comprobante (JSON que arma emitir_comprobante).
  factory Comprobante.desdeMapa(Map<String, dynamic> datos) => Comprobante(
    tipo: datos['tipo'] ?? boleta,
    serie: datos['serie'] ?? 'B001',
    numero: leerInt(datos['numero']),
    documento: datos['documento'] ?? '',
    razonSocial: datos['razon_social'] ?? '',
    opGravadaCentimos: leerInt(datos['op_gravada_centimos']),
    igvCentimos: leerInt(datos['igv_centimos']),
    totalCentimos: leerInt(datos['total_centimos']),
    emitidoEn: leerFecha(datos['emitido_en']),
    estadoSunat: datos['estado_sunat'] ?? aceptado,
  );

  Map<String, dynamic> aMapa() => {
    'tipo': tipo,
    'serie': serie,
    'numero': numero,
    'codigo': codigo,
    'documento': documento,
    'razon_social': razonSocial,
    'op_gravada_centimos': opGravadaCentimos,
    'igv_centimos': igvCentimos,
    'total_centimos': totalCentimos,
    'emitido_en': fechaIso(emitidoEn),
    'estado_sunat': estadoSunat,
  };
}

/// Orden de trabajo (tabla ordenes). Equivale al pedido de la app de
/// referencia: líneas con precio del momento, montos en céntimos, historial
/// de estados, pago y comprobante.
class Orden {
  const Orden({
    this.id = '',
    required this.codigo,
    this.clienteId = '',
    required this.clienteNombre,
    this.documentoCliente = '',
    required this.telefono,
    required this.placa,
    required this.vehiculo,
    this.tipoVehiculo = TiposVehiculo.auto,
    required this.km,
    this.motivo = '',
    this.diagnostico = '',
    this.mecanico = '',
    this.entregaEstimada,
    required this.lineas,
    required this.subtotalCentimos,
    required this.descuentoCentimos,
    this.recargoCentimos = 0,
    required this.totalCentimos,
    this.moneda = 'PEN',
    this.codigoPromo,
    this.aDomicilio = false,
    this.metodoPago,
    this.estadoPago = EstadosPago.porCobrar,
    this.referenciaPago,
    this.pagadoEn,
    required this.estado,
    required this.historial,
    this.stockDescontado = false,
    this.comprobante,
    this.creadoPor = '',
    this.creadoPorNombre = '',
    required this.creadoEn,
    required this.actualizadoEn,
  });

  static const prefijo = 'OT';

  static String generarCodigo(int numero) => '$prefijo-$numero';

  final String id;

  /// OT-1042
  final String codigo;
  final String clienteId;
  final String clienteNombre;
  final String documentoCliente;
  final String telefono;
  final String placa;

  /// "Toyota Yaris 2019"
  final String vehiculo;
  final String tipoVehiculo;
  final int km;

  /// Motivo de ingreso / trabajo solicitado.
  final String motivo;

  /// Lo que encontró el mecánico al revisar el vehículo (se escribe en el taller).
  final String diagnostico;
  final String mecanico;
  final DateTime? entregaEstimada;
  final List<LineaOrden> lineas;
  final int subtotalCentimos;
  final int descuentoCentimos;
  final int recargoCentimos;
  final int totalCentimos;
  final String moneda;
  final String? codigoPromo;

  /// Servicio a domicilio o recojo del vehículo (equivale al delivery).
  final bool aDomicilio;
  final String? metodoPago;
  final String estadoPago;

  /// N.° de operación Yape/Plin.
  final String? referenciaPago;
  final DateTime? pagadoEn;
  final EstadoOrden estado;
  final List<CambioEstado> historial;

  /// true cuando ya salieron los repuestos del almacén.
  final bool stockDescontado;
  final Comprobante? comprobante;
  final String creadoPor;
  final String creadoPorNombre;
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  bool get estaPagada => estadoPago == EstadosPago.pagado;
  bool get pagoPorVerificar => estadoPago == EstadosPago.verificando;
  bool get tieneComprobante => comprobante != null;

  String get etiquetaPago => EstadosPago.etiquetas[estadoPago] ?? estadoPago;

  String? get etiquetaMetodo =>
      metodoPago == null ? null : MetodosPago.etiquetas[metodoPago] ?? metodoPago;

  DesgloseOrden get desglose => DesgloseOrden(
    subtotal: subtotalCentimos,
    descuento: descuentoCentimos,
    recargo: recargoCentimos,
  );

  /// Texto principal de la tarjeta: el motivo o el primer servicio.
  String get servicioPrincipal {
    if (motivo.trim().isNotEmpty) return motivo;
    for (final l in lineas) {
      if (l.esServicio) return l.nombre;
    }
    return lineas.isEmpty ? 'Orden de trabajo' : lineas.first.nombre;
  }

  int get cantidadItems => lineas.fold(0, (s, l) => s + l.cantidad);

  /// Repuestos que la orden saca del almacén: código → unidades.
  Map<String, int> get repuestosRequeridos {
    final mapa = <String, int>{};
    for (final l in lineas.where((l) => l.esRepuesto)) {
      mapa[l.refId] = (mapa[l.refId] ?? 0) + l.cantidad;
    }
    return mapa;
  }

  /// Última etapa alcanzada (también para órdenes anuladas o entregadas).
  EstadoOrden get etapaAlcanzada {
    if (EstadoOrden.etapas.contains(estado)) return estado;
    if (estado == EstadoOrden.entregado) return EstadoOrden.listo;
    for (final cambio in historial.reversed) {
      if (EstadoOrden.etapas.contains(cambio.estado)) return cambio.estado;
    }
    return EstadoOrden.recepcion;
  }

  /// Índice 0–4 para la línea de tiempo.
  int get etapa => EstadoOrden.etapas.indexOf(etapaAlcanzada);

  /// Avance de 0 a 1 para la barra de progreso.
  double get avance => (etapa + 1) / EstadoOrden.etapas.length;

  /// Fecha en que la orden llegó a [buscado] (si ya pasó por él).
  DateTime? fechaDeEstado(EstadoOrden buscado) {
    for (final cambio in historial.reversed) {
      if (cambio.estado == buscado) return cambio.fecha;
    }
    return null;
  }

  /// Horas desde la recepción hasta "Listo" (null si todavía no llega).
  double? get horasDeServicio {
    final listo = fechaDeEstado(EstadoOrden.listo);
    if (listo == null) return null;
    final minutos = listo.difference(creadoEn).inMinutes;
    return minutos <= 0 ? null : minutos / 60;
  }

  /// "hoy 17:00", "mañana 10:00", "15/09 09:30" o "entregado".
  String entregaTexto({DateTime? ahora}) {
    if (estado == EstadoOrden.entregado) return 'entregado';
    if (estado == EstadoOrden.cancelado) return 'anulada';
    final fecha = entregaEstimada;
    if (fecha == null) return 'por definir';
    final hoy = ahora ?? DateTime.now();
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = dia.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final hora = formatoHora(fecha);
    if (diferencia == 0) return 'hoy $hora';
    if (diferencia == 1) return 'mañana $hora';
    return '${formatoFecha(fecha).substring(0, 5)} $hora';
  }

  /// La orden pasó la hora de entrega estimada y sigue en el taller.
  bool atrasada({DateTime? ahora}) =>
      estado.activa &&
      estado != EstadoOrden.listo &&
      entregaEstimada != null &&
      (ahora ?? DateTime.now()).isAfter(entregaEstimada!);

  /// Fila de la tabla ordenes (o el JSON que devuelven las funciones SQL).
  factory Orden.desdeMapa(Map<String, dynamic> fila) {
    final comprobante = fila['comprobante'];
    return Orden(
      id: '${fila['id'] ?? ''}',
      codigo: fila['codigo'] ?? '',
      clienteId: fila['cliente_id'] ?? '',
      clienteNombre: fila['cliente_nombre'] ?? '',
      documentoCliente: fila['documento_cliente'] ?? '',
      telefono: fila['telefono'] ?? '',
      placa: fila['placa'] ?? '',
      vehiculo: fila['vehiculo'] ?? '',
      tipoVehiculo: fila['tipo_vehiculo'] ?? TiposVehiculo.auto,
      km: leerInt(fila['km']),
      motivo: fila['motivo'] ?? '',
      diagnostico: fila['diagnostico'] ?? '',
      mecanico: fila['mecanico'] ?? '',
      entregaEstimada: leerFechaOpcional(fila['entrega_estimada']),
      lineas: leerListaMapas(fila['lineas']).map(LineaOrden.desdeMapa).toList(),
      subtotalCentimos: leerInt(fila['subtotal_centimos']),
      descuentoCentimos: leerInt(fila['descuento_centimos']),
      recargoCentimos: leerInt(fila['recargo_centimos']),
      totalCentimos: leerInt(fila['total_centimos']),
      moneda: fila['moneda'] ?? 'PEN',
      codigoPromo: fila['codigo_promo'],
      aDomicilio: fila['a_domicilio'] == true,
      metodoPago: fila['metodo_pago'],
      estadoPago: fila['estado_pago'] ?? EstadosPago.porCobrar,
      referenciaPago: fila['referencia_pago'],
      pagadoEn: leerFechaOpcional(fila['pagado_en']),
      estado: EstadoOrden.desde(fila['estado']),
      historial: leerListaMapas(fila['historial']).map(CambioEstado.desdeMapa).toList(),
      stockDescontado: fila['stock_descontado'] == true,
      comprobante: comprobante is Map ? Comprobante.desdeMapa(Map<String, dynamic>.from(comprobante)) : null,
      creadoPor: '${fila['creado_por'] ?? ''}',
      creadoPorNombre: fila['creado_por_nombre'] ?? '',
      creadoEn: leerFecha(fila['created_at']),
      actualizadoEn: leerFecha(fila['updated_at']),
    );
  }

  /// Datos que recibe la función crear_orden (el código, el estado, el
  /// historial y las fechas los pone el servidor).
  Map<String, dynamic> aMapaNueva() => {
    'cliente_id': clienteId,
    'cliente_nombre': clienteNombre,
    'documento_cliente': documentoCliente,
    'telefono': telefono,
    'placa': placa,
    'vehiculo': vehiculo,
    'tipo_vehiculo': tipoVehiculo,
    'km': km,
    'motivo': motivo,
    'mecanico': mecanico,
    'entrega_estimada': entregaEstimada == null ? null : fechaIso(entregaEstimada!),
    'lineas': lineas.map((l) => l.aMapa()).toList(),
    'subtotal_centimos': subtotalCentimos,
    'descuento_centimos': descuentoCentimos,
    'recargo_centimos': recargoCentimos,
    'total_centimos': totalCentimos,
    'codigo_promo': codigoPromo,
    'a_domicilio': aDomicilio,
    'creado_por_nombre': creadoPorNombre,
  };

  Orden copyWith({
    String? diagnostico,
    String? id,
    String? codigo,
    String? mecanico,
    DateTime? entregaEstimada,
    List<LineaOrden>? lineas,
    int? subtotalCentimos,
    int? descuentoCentimos,
    int? totalCentimos,
    String? codigoPromo,
    bool quitarPromo = false,
    String? metodoPago,
    String? estadoPago,
    String? referenciaPago,
    DateTime? pagadoEn,
    EstadoOrden? estado,
    List<CambioEstado>? historial,
    bool? stockDescontado,
    Comprobante? comprobante,
    DateTime? actualizadoEn,
  }) => Orden(
    id: id ?? this.id,
    codigo: codigo ?? this.codigo,
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    documentoCliente: documentoCliente,
    telefono: telefono,
    placa: placa,
    vehiculo: vehiculo,
    tipoVehiculo: tipoVehiculo,
    km: km,
    motivo: motivo,
    diagnostico: diagnostico ?? this.diagnostico,
    mecanico: mecanico ?? this.mecanico,
    entregaEstimada: entregaEstimada ?? this.entregaEstimada,
    lineas: lineas ?? this.lineas,
    subtotalCentimos: subtotalCentimos ?? this.subtotalCentimos,
    descuentoCentimos: descuentoCentimos ?? this.descuentoCentimos,
    recargoCentimos: recargoCentimos,
    totalCentimos: totalCentimos ?? this.totalCentimos,
    moneda: moneda,
    codigoPromo: quitarPromo ? null : codigoPromo ?? this.codigoPromo,
    aDomicilio: aDomicilio,
    metodoPago: metodoPago ?? this.metodoPago,
    estadoPago: estadoPago ?? this.estadoPago,
    referenciaPago: referenciaPago ?? this.referenciaPago,
    pagadoEn: pagadoEn ?? this.pagadoEn,
    estado: estado ?? this.estado,
    historial: historial ?? this.historial,
    stockDescontado: stockDescontado ?? this.stockDescontado,
    comprobante: comprobante ?? this.comprobante,
    creadoPor: creadoPor,
    creadoPorNombre: creadoPorNombre,
    creadoEn: creadoEn,
    actualizadoEn: actualizadoEn ?? this.actualizadoEn,
  );
}
