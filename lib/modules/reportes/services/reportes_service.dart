import '../../catalogo/services/catalogo_service.dart';
import '../../clientes/services/cliente_service.dart';
import '../../ordenes/services/orden_service.dart';
import '../models/reporte_stats.dart';
import 'calculadora_reportes.dart';

/// Reportes en tiempo real: escucha las órdenes del periodo actual y del
/// anterior y recalcula los indicadores con [calcularReporte].
class ReportesService {
  ReportesService._();

  static final instancia = ReportesService._();

  /// Margen para contar cobros de órdenes abiertas antes del periodo.
  static const _margen = Duration(days: 31);

  Stream<ReporteStats> escuchar(Periodo periodo, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    final actual = rangoActual(periodo, momento);
    final anterior = rangoAnterior(periodo, momento);
    final config = CatalogoService.instancia.catalogo.config;
    final (apertura, cierre) = config.rangoHoras;
    final clientes = ClienteService.instancia;

    return OrdenService.instancia
        .entre(anterior.inicio.subtract(_margen), actual.fin)
        .map(
          (ordenes) => calcularReporte(
            periodo: periodo,
            ordenes: ordenes,
            ahora: ahora ?? DateTime.now(),
            clientesNuevos: clientes.nuevosEntre(actual.inicio, actual.fin),
            clientesNuevosAnterior: clientes.nuevosEntre(anterior.inicio, anterior.fin),
            horaApertura: apertura,
            horaCierre: cierre,
            metaHoras: config.metaHorasServicio,
          ),
        );
  }
}
