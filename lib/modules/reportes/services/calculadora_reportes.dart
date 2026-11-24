import '../../ordenes/models/orden.dart';
import '../models/reporte_stats.dart';

/// Rango semiabierto [inicio, fin).
class Rango {
  const Rango(this.inicio, this.fin);
  final DateTime inicio;
  final DateTime fin;

  bool contiene(DateTime fecha) => !fecha.isBefore(inicio) && fecha.isBefore(fin);
}

Rango rangoActual(Periodo periodo, DateTime ahora) {
  switch (periodo) {
    case Periodo.hoy:
      final inicio = DateTime(ahora.year, ahora.month, ahora.day);
      return Rango(inicio, DateTime(ahora.year, ahora.month, ahora.day + 1));
    case Periodo.semana:
      // Semana de lunes a domingo.
      final inicio = DateTime(ahora.year, ahora.month, ahora.day - (ahora.weekday - 1));
      return Rango(inicio, DateTime(inicio.year, inicio.month, inicio.day + 7));
    case Periodo.mes:
      return Rango(DateTime(ahora.year, ahora.month), DateTime(ahora.year, ahora.month + 1));
    case Periodo.anio:
      return Rango(DateTime(ahora.year), DateTime(ahora.year + 1));
  }
}

Rango rangoAnterior(Periodo periodo, DateTime ahora) {
  final i = rangoActual(periodo, ahora).inicio;
  switch (periodo) {
    case Periodo.hoy:
      return Rango(DateTime(i.year, i.month, i.day - 1), i);
    case Periodo.semana:
      return Rango(DateTime(i.year, i.month, i.day - 7), i);
    case Periodo.mes:
      return Rango(DateTime(i.year, i.month - 1), i);
    case Periodo.anio:
      return Rango(DateTime(i.year - 1), i);
  }
}

List<String> _etiquetasBarras(Periodo periodo, Rango rango, int apertura, int cierre) {
  switch (periodo) {
    case Periodo.hoy:
      return [for (var h = apertura; h <= cierre; h++) '$h'];
    case Periodo.semana:
      return const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    case Periodo.mes:
      final diasMes = DateTime(rango.inicio.year, rango.inicio.month + 1, 0).day;
      final semanas = (diasMes - 1) ~/ 7 + 1;
      return [for (var s = 1; s <= semanas; s++) 'S$s'];
    case Periodo.anio:
      return const ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  }
}

int _indiceBarra(Periodo periodo, DateTime fecha, int apertura, int cierre) => switch (periodo) {
  Periodo.hoy => fecha.hour.clamp(apertura, cierre) - apertura,
  Periodo.semana => fecha.weekday - 1,
  Periodo.mes => (fecha.day - 1) ~/ 7,
  Periodo.anio => fecha.month - 1,
};

double? _promedioHoras(Iterable<Orden> ordenes, Rango rango) {
  final horas = [
    for (final o in ordenes)
      if (o.fechaDeEstado(EstadoOrden.listo) case final listo? when rango.contiene(listo))
        ?o.horasDeServicio,
  ];
  if (horas.isEmpty) return null;
  return horas.reduce((a, b) => a + b) / horas.length;
}

List<TopItem> _top(Iterable<Orden> ordenes, bool Function(LineaOrden) incluir, {int maximo = 5}) {
  final unidades = <String, int>{};
  final montos = <String, int>{};
  final nombres = <String, String>{};
  for (final o in ordenes) {
    for (final l in o.lineas.where(incluir)) {
      unidades[l.refId] = (unidades[l.refId] ?? 0) + l.cantidad;
      montos[l.refId] = (montos[l.refId] ?? 0) + l.totalLineaCentimos;
      nombres[l.refId] = l.nombre;
    }
  }
  final ids = unidades.keys.toList()
    ..sort((a, b) {
      final porUnidades = unidades[b]!.compareTo(unidades[a]!);
      return porUnidades != 0 ? porUnidades : montos[b]!.compareTo(montos[a]!);
    });
  return [
    for (final id in ids.take(maximo))
      TopItem(refId: id, nombre: nombres[id]!, unidades: unidades[id]!, centimos: montos[id]!),
  ];
}

/// Calcula los indicadores de Reportes con las órdenes del periodo actual y
/// del anterior (función pura, fácil de testear). Igual que calcularDashboard
/// de la app de referencia, pero los ingresos se cuentan por fecha de cobro.
ReporteStats calcularReporte({
  required Periodo periodo,
  required List<Orden> ordenes,
  required DateTime ahora,
  int clientesNuevos = 0,
  int clientesNuevosAnterior = 0,
  int horaApertura = 8,
  int horaCierre = 18,
  int metaHoras = 4,
}) {
  final actual = rangoActual(periodo, ahora);
  final anterior = rangoAnterior(periodo, ahora);

  final validas = ordenes.where((o) => o.estado != EstadoOrden.cancelado).toList();
  final creadas = validas.where((o) => actual.contiene(o.creadoEn)).toList();
  final creadasAntes = validas.where((o) => anterior.contiene(o.creadoEn)).toList();
  bool pagadaEn(Orden o, Rango r) => o.estaPagada && o.pagadoEn != null && r.contiene(o.pagadoEn!);
  final pagadas = validas.where((o) => pagadaEn(o, actual)).toList();
  final pagadasAntes = validas.where((o) => pagadaEn(o, anterior)).toList();

  int sumar(List<Orden> lista) => lista.fold(0, (a, o) => a + o.totalCentimos);

  // Gráfico de barras (por fecha de cobro).
  final etiquetas = _etiquetasBarras(periodo, actual, horaApertura, horaCierre);
  final montos = List<int>.filled(etiquetas.length, 0);
  for (final o in pagadas) {
    final i = _indiceBarra(periodo, o.pagadoEn!, horaApertura, horaCierre);
    if (i >= 0 && i < montos.length) montos[i] += o.totalCentimos;
  }
  final barras = [for (var i = 0; i < etiquetas.length; i++) BarraIngreso(etiquetas[i], montos[i])];
  final indiceEnCurso = actual.contiene(ahora)
      ? _indiceBarra(periodo, ahora, horaApertura, horaCierre).clamp(0, barras.length - 1)
      : -1;

  // Órdenes del periodo por estado.
  final porEstado = <EstadoOrden, int>{for (final e in EstadoOrden.flujo) e: 0};
  for (final o in creadas) {
    porEstado[o.estado] = (porEstado[o.estado] ?? 0) + 1;
  }

  // Clientes recurrentes = vehículos distintos atendidos − clientes nuevos.
  final distintos = creadas.map((o) => o.clienteId.isEmpty ? o.placa : o.clienteId).toSet().length;
  final recurrentes = distintos > clientesNuevos ? distintos - clientesNuevos : 0;

  final recientes = [...creadas]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  return ReporteStats(
    periodo: periodo,
    ingresosCentimos: sumar(pagadas),
    ingresosAnteriorCentimos: sumar(pagadasAntes),
    ordenes: creadas.length,
    ordenesAnterior: creadasAntes.length,
    cobradas: pagadas.length,
    cobradasAnterior: pagadasAntes.length,
    clientesNuevos: clientesNuevos,
    clientesNuevosAnterior: clientesNuevosAnterior,
    clientesRecurrentes: recurrentes,
    horasServicio: _promedioHoras(validas, actual),
    horasServicioAnterior: _promedioHoras(validas, anterior),
    metaHoras: metaHoras,
    barras: barras,
    indiceEnCurso: indiceEnCurso,
    porEstado: porEstado,
    masPedidos: _top(creadas, (l) => l.esServicio),
    repuestosMasUsados: _top(creadas, (l) => l.esRepuesto),
    recientes: recientes.take(4).toList(),
    horaApertura: horaApertura,
  );
}

/// KPIs de la pantalla de inicio.
class KpisInicio {
  const KpisInicio({
    required this.ordenesAbiertas,
    required this.citasHoy,
    required this.stockCritico,
    required this.ingresosHoyCentimos,
  });

  final int ordenesAbiertas;
  final int citasHoy;
  final int stockCritico;
  final int ingresosHoyCentimos;

  static KpisInicio calcular({
    required List<Orden> ordenes,
    required int citasHoy,
    required int stockCritico,
    required DateTime ahora,
  }) {
    final hoy = rangoActual(Periodo.hoy, ahora);
    return KpisInicio(
      ordenesAbiertas: ordenes.where((o) => o.estado.activa).length,
      citasHoy: citasHoy,
      stockCritico: stockCritico,
      ingresosHoyCentimos: ordenes
          .where((o) => o.estaPagada && o.pagadoEn != null && hoy.contiene(o.pagadoEn!))
          .fold(0, (a, o) => a + o.totalCentimos),
    );
  }
}
