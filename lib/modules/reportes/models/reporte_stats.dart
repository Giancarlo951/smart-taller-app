import '../../../core/utils/formatos.dart';
import '../../ordenes/models/orden.dart';

enum Periodo {
  hoy('Hoy'),
  semana('Semana'),
  mes('Mes'),
  anio('Año');

  const Periodo(this.etiqueta);
  final String etiqueta;

  String get tituloIngresos => switch (this) {
    Periodo.hoy => 'Ingresos de hoy',
    Periodo.semana => 'Ingresos de la semana',
    Periodo.mes => 'Ingresos del mes',
    Periodo.anio => 'Ingresos del año',
  };

  String get comparacion => switch (this) {
    Periodo.hoy => 'ayer',
    Periodo.semana => 'sem. pasada',
    Periodo.mes => 'mes pasado',
    Periodo.anio => 'año pasado',
  };

  String get tituloGrafico => switch (this) {
    Periodo.hoy => 'Ingresos por hora',
    Periodo.semana => 'Ingresos por día',
    Periodo.mes => 'Ingresos por semana',
    Periodo.anio => 'Ingresos por mes',
  };

  String get tituloMasPedidos => switch (this) {
    Periodo.hoy => 'Servicios más pedidos hoy',
    Periodo.semana => 'Servicios más pedidos de la semana',
    Periodo.mes => 'Servicios más pedidos del mes',
    Periodo.anio => 'Servicios más pedidos del año',
  };
}

/// Variación en % respecto al periodo anterior (100 si antes era 0).
double variacionPorcentual(num actual, num anterior) {
  if (anterior == 0) return actual > 0 ? 100 : 0;
  return (actual - anterior) / anterior * 100;
}

class BarraIngreso {
  const BarraIngreso(this.etiqueta, this.centimos);
  final String etiqueta;
  final int centimos;
}

class TopItem {
  const TopItem({required this.refId, required this.nombre, required this.unidades, required this.centimos});

  final String refId;
  final String nombre;
  final int unidades;
  final int centimos;
}

/// Indicadores de Reportes (equivale a DashboardStats del panel admin).
class ReporteStats {
  const ReporteStats({
    required this.periodo,
    required this.ingresosCentimos,
    required this.ingresosAnteriorCentimos,
    required this.ordenes,
    required this.ordenesAnterior,
    required this.cobradas,
    required this.cobradasAnterior,
    required this.clientesNuevos,
    required this.clientesNuevosAnterior,
    required this.clientesRecurrentes,
    required this.horasServicio,
    required this.horasServicioAnterior,
    required this.metaHoras,
    required this.barras,
    required this.indiceEnCurso,
    required this.porEstado,
    required this.masPedidos,
    required this.repuestosMasUsados,
    required this.recientes,
    this.horaApertura = 8,
  });

  final Periodo periodo;

  /// Cobrado en el periodo (órdenes pagadas, por fecha de pago).
  final int ingresosCentimos;
  final int ingresosAnteriorCentimos;

  /// Órdenes abiertas en el periodo (sin anuladas).
  final int ordenes;
  final int ordenesAnterior;
  final int cobradas;
  final int cobradasAnterior;
  final int clientesNuevos;
  final int clientesNuevosAnterior;
  final int clientesRecurrentes;

  /// Promedio recepción → listo, en horas (null sin órdenes listas).
  final double? horasServicio;
  final double? horasServicioAnterior;
  final int metaHoras;
  final List<BarraIngreso> barras;

  /// Barra del momento actual (-1 si no aplica).
  final int indiceEnCurso;
  final Map<EstadoOrden, int> porEstado;
  final List<TopItem> masPedidos;
  final List<TopItem> repuestosMasUsados;
  final List<Orden> recientes;
  final int horaApertura;

  int get ticketPromedioCentimos => cobradas == 0 ? 0 : (ingresosCentimos / cobradas).round();
  int get ticketAnteriorCentimos =>
      cobradasAnterior == 0 ? 0 : (ingresosAnteriorCentimos / cobradasAnterior).round();

  double get variacionIngresos => variacionPorcentual(ingresosCentimos, ingresosAnteriorCentimos);
  double get variacionOrdenes => variacionPorcentual(ordenes, ordenesAnterior);
  double get variacionTicket => variacionPorcentual(ticketPromedioCentimos, ticketAnteriorCentimos);

  int get totalPorEstado => porEstado.values.fold(0, (a, b) => a + b);

  /// Dentro de la meta de tiempo de servicio.
  bool? get dentroDeMeta => horasServicio == null ? null : horasServicio! <= metaHoras;

  /// Índice de la barra más alta (-1 si todas son 0).
  int get indicePico {
    var idx = -1;
    var max = 0;
    for (var i = 0; i < barras.length; i++) {
      if (barras[i].centimos > max) {
        max = barras[i].centimos;
        idx = i;
      }
    }
    return idx;
  }

  /// Valores para una mini línea de tendencia (hasta la barra en curso).
  List<int> get tendencia {
    final fin = indiceEnCurso >= 0 ? indiceEnCurso + 1 : barras.length;
    final valores = barras.take(fin).map((b) => b.centimos).toList();
    while (valores.length < 2) {
      valores.insert(0, 0);
    }
    return valores;
  }

  /// "Pico a las 16:00 · S/ 690.00"
  String get descripcionPico {
    final i = indicePico;
    if (i < 0) return 'Aún no hay cobros en este periodo';
    final monto = formatoCentimos(barras[i].centimos);
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final cuando = switch (periodo) {
      Periodo.hoy => 'a las ${(horaApertura + i).toString().padLeft(2, '0')}:00',
      Periodo.semana => 'el ${dias[i % 7]}',
      Periodo.mes => 'en la semana ${i + 1}',
      Periodo.anio => 'en ${meses[i % 12]}',
    };
    return 'Pico $cuando · $monto';
  }
}
