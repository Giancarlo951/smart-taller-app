import '../../catalogo/models/servicio.dart';
import '../models/calculadora_precios.dart';
import '../models/linea_cotizacion.dart';
import '../models/orden.dart';

/// Órdenes de ejemplo del modo local (sin Firebase). Los montos son los del
/// prototipo: OT-1042 S/ 285, OT-1041 S/ 520, OT-1040 S/ 430, OT-1039 S/ 690.
/// Datos de ejemplo, no reales.
abstract final class OrdenesLocal {
  static const ultimoNumero = 1042;
  static const ultimaBoleta = 247;
  static const ultimaFactura = 0;

  static LineaOrden _servicio(String id, String nombre, int soles, {String tipo = TiposVehiculo.auto}) =>
      LineaOrden(
        tipo: LineaCotizacion.tipoServicio,
        refId: id,
        nombre: nombre,
        variante: tipo,
        precioUnitarioCentimos: soles * 100,
        cantidad: 1,
      );

  static LineaOrden _repuesto(String codigo, String nombre, int soles, int cantidad) => LineaOrden(
    tipo: LineaCotizacion.tipoRepuesto,
    refId: codigo,
    nombre: nombre,
    precioUnitarioCentimos: soles * 100,
    cantidad: cantidad,
  );

  static List<CambioEstado> _historial(List<(EstadoOrden, DateTime)> pasos) => [
    for (final (estado, fecha) in pasos) CambioEstado(estado: estado, fecha: fecha, por: 'Recepción'),
  ];

  static Orden _orden({
    required int numero,
    required String cliente,
    required String clienteId,
    required String documento,
    required String telefono,
    required String placa,
    required String vehiculo,
    required int km,
    required String motivo,
    required String mecanico,
    required List<LineaOrden> lineas,
    required List<(EstadoOrden, DateTime)> pasos,
    DateTime? entrega,
    String estadoPago = EstadosPago.porCobrar,
    String? metodoPago,
    DateTime? pagadoEn,
    Comprobante? comprobante,
  }) {
    final total = lineas.fold(0, (s, l) => s + l.totalLineaCentimos);
    final estado = pasos.last.$1;
    return Orden(
      id: 'local-$numero',
      codigo: Orden.generarCodigo(numero),
      clienteId: clienteId,
      clienteNombre: cliente,
      documentoCliente: documento,
      telefono: telefono,
      placa: placa,
      vehiculo: vehiculo,
      km: km,
      motivo: motivo,
      mecanico: mecanico,
      entregaEstimada: entrega,
      lineas: lineas,
      subtotalCentimos: total,
      descuentoCentimos: 0,
      totalCentimos: total,
      estadoPago: estadoPago,
      metodoPago: metodoPago,
      pagadoEn: pagadoEn,
      estado: estado,
      historial: _historial(pasos),
      stockDescontado: estado.descuentaStock,
      comprobante: comprobante,
      creadoPorNombre: 'Recepción',
      creadoEn: pasos.first.$2,
      actualizadoEn: pasos.last.$2,
    );
  }

  static List<Orden> ejemplo({DateTime? ahora}) {
    final t = ahora ?? DateTime.now();
    DateTime hace({int dias = 0, int horas = 0, int minutos = 0}) =>
        t.subtract(Duration(days: dias, hours: horas, minutes: minutos));
    final ayer = hace(dias: 1);

    return [
      _orden(
        numero: 1042,
        cliente: 'Rosa Paucar Lazo',
        clienteId: 'local-c5',
        documento: '45120884',
        telefono: '964112480',
        placa: 'V2K-841',
        vehiculo: 'Toyota Yaris 2019',
        km: 78420,
        motivo: 'Cambio de aceite y filtros',
        mecanico: 'J. Quispe',
        entrega: t.add(const Duration(hours: 3)),
        lineas: [
          _repuesto('LUB-1040', 'Aceite 10W-40 sintético 1L', 37, 4),
          _repuesto('FIL-TY02', 'Filtro de aceite Toyota', 42, 1),
          _repuesto('FIL-AI03', 'Filtro de aire', 55, 1),
          _servicio('cambio-aceite', 'Cambio de aceite y filtros', 40),
        ],
        pasos: [
          (EstadoOrden.recepcion, hace(horas: 3)),
          (EstadoOrden.diagnostico, hace(horas: 2, minutos: 40)),
          (EstadoOrden.repuestos, hace(horas: 1)),
        ],
      ),
      _orden(
        numero: 1041,
        cliente: 'Marco Ríos Anco',
        clienteId: 'local-c3',
        documento: '70884213',
        telefono: '951640227',
        placa: 'W7B-320',
        vehiculo: 'Hyundai Accent 2021',
        km: 41150,
        motivo: 'Frenos: pastillas y rectificado de discos',
        mecanico: 'L. Veliz',
        entrega: DateTime(t.year, t.month, t.day + 1, 10),
        lineas: [
          _repuesto('FRE-HY11', 'Pastillas de freno Accent', 260, 1),
          _servicio('rectificado-discos', 'Rectificado de discos', 140),
          _repuesto('FRE-DOT4', 'Líquido de frenos DOT4', 60, 1),
          _servicio('pastillas-freno', 'Cambio de pastillas de freno', 60),
        ],
        pasos: [
          (EstadoOrden.recepcion, hace(horas: 26)),
          (EstadoOrden.diagnostico, hace(horas: 25)),
          (EstadoOrden.repuestos, hace(horas: 24)),
          (EstadoOrden.reparacion, hace(minutos: 35)),
        ],
      ),
      _orden(
        numero: 1040,
        cliente: 'Elena Chávez Rojas',
        clienteId: 'local-c1',
        documento: '41887520',
        telefono: '987003514',
        placa: 'A4R-119',
        vehiculo: 'Nissan Sentra 2017',
        km: 112900,
        motivo: 'Diagnóstico electrónico y batería',
        mecanico: 'C. Mayta',
        entrega: t.add(const Duration(hours: 5)),
        lineas: [
          _repuesto('BAT-7500', 'Batería 12V 75Ah', 350, 1),
          _servicio('diagnostico-escaner', 'Diagnóstico electrónico con escáner', 50),
          _servicio('cambio-bateria', 'Cambio de batería', 30),
        ],
        pasos: [
          (EstadoOrden.recepcion, hace(horas: 2)),
          (EstadoOrden.diagnostico, hace(horas: 1, minutos: 30)),
        ],
      ),
      _orden(
        numero: 1039,
        cliente: 'Julio Ramos Quispe',
        clienteId: 'local-c2',
        documento: '46220931',
        telefono: '976884301',
        placa: 'B9M-772',
        vehiculo: 'Kia Rio 2020',
        km: 55300,
        motivo: 'Mantenimiento preventivo 50,000 km',
        mecanico: 'J. Gabriel',
        entrega: ayer,
        lineas: [
          _repuesto('KIT-MP50', 'Kit de mantenimiento 50,000 km', 480, 1),
          _servicio('alineamiento-balanceo', 'Alineamiento y balanceo', 120),
          _servicio('mantenimiento-preventivo', 'Mantenimiento preventivo', 90),
        ],
        pasos: [
          (EstadoOrden.recepcion, hace(dias: 2, horas: 2)),
          (EstadoOrden.diagnostico, hace(dias: 2, horas: 1)),
          (EstadoOrden.repuestos, hace(dias: 2)),
          (EstadoOrden.reparacion, hace(dias: 1, horas: 6)),
          (EstadoOrden.listo, hace(dias: 1, horas: 3)),
          (EstadoOrden.entregado, hace(dias: 1, horas: 1)),
        ],
        estadoPago: EstadosPago.pagado,
        metodoPago: MetodosPago.efectivo,
        pagadoEn: hace(dias: 1, horas: 2),
        comprobante: Comprobante(
          tipo: Comprobante.boleta,
          serie: 'B001',
          numero: ultimaBoleta,
          documento: '46220931',
          opGravadaCentimos: 69000 - DesgloseOrden.igvDe(69000),
          igvCentimos: DesgloseOrden.igvDe(69000),
          totalCentimos: 69000,
          emitidoEn: hace(dias: 1, horas: 2),
        ),
      ),
    ];
  }
}
