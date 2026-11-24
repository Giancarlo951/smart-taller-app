import 'dart:async';

import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';
import '../../../core/utils/validadores.dart';
import '../../avisos/models/aviso.dart';
import '../../avisos/services/aviso_service.dart';
import '../../catalogo/models/config_taller.dart';
import '../../catalogo/services/catalogo_service.dart';
import '../models/cita.dart';

/// Agenda de citas (tabla citas), con modo local en memoria.
class CitaService extends RepositorioSupabase<Cita> {
  CitaService._() : super('citas');

  static final instancia = CitaService._();

  /// Las citas van cada 30 minutos.
  static const intervaloMinutos = 30;

  @override
  Cita desdeMapa(Map<String, dynamic> fila) => Cita.desdeMapa(fila);

  @override
  Map<String, dynamic> aMapa(Cita item) => item.aMapa();

  // ---- Modo local ----
  List<Cita> _locales = citasDeEjemplo();
  final _cambiosLocales = StreamController<List<Cita>>.broadcast();

  void _emitirLocal() => _cambiosLocales.add(List.of(_locales));

  /// Vuelve a las citas de ejemplo. Solo para pruebas.
  void reiniciarLocal({DateTime? hoy}) {
    _locales = citasDeEjemplo(hoy: hoy);
    _emitirLocal();
  }

  static List<Cita> _porHora(Iterable<Cita> citas) =>
      citas.toList()..sort((a, b) => a.fecha.compareTo(b.fecha));

  /// Citas de [desde, hasta) ordenadas por hora.
  Stream<List<Cita>> entre(DateTime desde, DateTime hasta) {
    bool enRango(Cita c) => !c.fecha.isBefore(desde) && c.fecha.isBefore(hasta);
    if (!haySupabase) {
      return (() async* {
        yield _porHora(_locales.where(enRango));
        yield* _cambiosLocales.stream.map((l) => _porHora(l.where(enRango)));
      })();
    }
    // El tiempo real admite un solo filtro: el fin del rango va en el cliente.
    return supabase
        .from(tabla)
        .stream(primaryKey: ['id'])
        .gte('fecha', fechaIso(desde))
        .map((filas) => _porHora(filas.map(Cita.desdeMapa).where(enRango)));
  }

  /// Citas de un día.
  Stream<List<Cita>> delDia(DateTime dia) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    return entre(inicio, DateTime(inicio.year, inicio.month, inicio.day + 1));
  }

  /// Días del selector de la agenda: [antes] días previos, hoy y [despues].
  static List<DateTime> diasAgenda(DateTime hoy, {int antes = 2, int despues = 1}) => [
    for (var i = -antes; i <= despues; i++) DateTime(hoy.year, hoy.month, hoy.day + i),
  ];

  /// Horarios del día con las bahías libres en cada uno.
  static List<(DateTime, int)> horarios(DateTime dia, List<Cita> delDia, ConfigTaller config) {
    final (apertura, ultima) = config.rangoHoras;
    final resultado = <(DateTime, int)>[];
    for (var minutos = apertura * 60; minutos <= ultima * 60 + 30; minutos += intervaloMinutos) {
      final hora = DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);
      final ocupadas = delDia.where((c) => c.estado.ocupaBahia && c.fecha == hora).length;
      resultado.add((hora, config.bahias - ocupadas));
    }
    return resultado;
  }

  /// Mensaje de error o null si la cita se puede agendar (función pura).
  static String? validar(
    Cita cita,
    List<Cita> delMismoDia,
    ConfigTaller config, {
    DateTime? ahora,
  }) {
    final errorPlaca = Validadores.placa(cita.placa);
    if (errorPlaca != null) return errorPlaca;
    if (cita.cliente.trim().isEmpty) return 'Ingrese el nombre del cliente';
    if (cita.servicio.trim().isEmpty) return 'Ingrese el servicio';
    final errorTelefono = Validadores.telefonoContacto(cita.telefono);
    if (errorTelefono != null) return errorTelefono;
    if (cita.fecha.isBefore(ahora ?? DateTime.now())) return 'La cita no puede ser en el pasado';
    if (cita.fecha.minute % intervaloMinutos != 0) return 'Las citas van cada 30 minutos';
    final (apertura, ultima) = config.rangoHoras;
    final minutos = cita.fecha.hour * 60 + cita.fecha.minute;
    if (minutos < apertura * 60 || minutos > ultima * 60 + 30) {
      return 'Fuera del horario de atención (${config.horario})';
    }
    // Al editar se excluye la misma cita; una nueva (sin id) cuenta todas.
    final otras = delMismoDia.where(
      (c) => (cita.id.isEmpty || c.id != cita.id) && c.estado.ocupaBahia,
    );
    final placa = normalizarPlaca(cita.placa);
    if (otras.any((c) => c.placa == placa)) return 'La placa $placa ya tiene una cita ese día';
    if (otras.where((c) => c.fecha == cita.fecha).length >= config.bahias) {
      return 'No hay bahías libres a las ${formatoHora(cita.fecha)}';
    }
    return null;
  }

  Future<List<Cita>> _delDia(DateTime dia) => delDia(dia).first.timeout(
    const Duration(seconds: 8),
    onTimeout: () => throw StateError('Sin conexión, inténtalo de nuevo'),
  );

  /// Agenda la cita después de validar horario, bahías y placa.
  Future<Cita> agendar(Cita cita, {ConfigTaller? config}) async {
    final ajustes = config ?? CatalogoService.instancia.catalogo.config;
    final limpia = Cita(
      fecha: cita.fecha,
      servicio: cita.servicio.trim(),
      placa: normalizarPlaca(cita.placa),
      cliente: cita.cliente.trim(),
      telefono: cita.telefono.replaceAll(RegExp(r'[\s-]'), ''),
      nota: cita.nota.trim(),
    );
    final error = validar(limpia, await _delDia(limpia.fecha), ajustes);
    if (error != null) throw StateError(error);
    final Cita guardada;
    if (!haySupabase) {
      guardada = limpia.copyWith(id: 'local-${DateTime.now().microsecondsSinceEpoch}');
      _locales = [..._locales, guardada];
      _emitirLocal();
    } else {
      guardada = limpia.copyWith(id: await enSupabase(() => crear(limpia)));
    }
    await AvisoService.instancia.registrar(
      TipoAviso.cita,
      'Cita agendada: ${guardada.cliente} (${guardada.placa}) el '
      '${formatoFecha(guardada.fecha).substring(0, 5)} a las ${guardada.hora}.',
    );
    return guardada;
  }

  /// Cambia el estado si el flujo lo permite (confirmada → en taller → atendida).
  Future<Cita> cambiarEstado(Cita cita, EstadoCita estado, {String? ordenId}) async {
    if (!cita.estado.siguientes.contains(estado)) {
      throw StateError('Una cita ${cita.estado.label.toLowerCase()} no puede pasar a ${estado.label.toLowerCase()}');
    }
    final actualizada = cita.copyWith(estado: estado, ordenId: ordenId);
    if (!haySupabase) {
      _locales = [for (final c in _locales) c.id == cita.id ? actualizada : c];
      _emitirLocal();
    } else {
      await enSupabase(() => supabase.from(tabla).update({
        'estado': estado.valor,
        'orden_id': ?ordenId,
      }).eq('id', cita.id));
    }
    if (estado == EstadoCita.cancelada) {
      await AvisoService.instancia.registrar(
        TipoAviso.cita,
        'Se canceló la cita de ${cita.cliente} (${cita.placa}) de las ${cita.hora}.',
      );
    }
    return actualizada;
  }

  /// Datos de ejemplo, no reales.
  static List<Cita> citasDeEjemplo({DateTime? hoy}) {
    final d = hoy ?? DateTime.now();
    DateTime a(int h, int m) => DateTime(d.year, d.month, d.day, h, m);
    return [
      Cita(id: 'local-ci1', fecha: a(8, 30), servicio: 'Cambio de aceite', placa: 'V2K-841', cliente: 'Rosa Paucar', telefono: '964112480', estado: EstadoCita.atendida, ordenId: 'local-1042'),
      Cita(id: 'local-ci2', fecha: a(10, 0), servicio: 'Alineamiento y balanceo', placa: 'C1T-509', cliente: 'Pedro Loayza', telefono: '964225870', estado: EstadoCita.enTaller),
      Cita(id: 'local-ci3', fecha: a(11, 30), servicio: 'Revisión de frenos', placa: 'W7B-320', cliente: 'Marco Ríos', telefono: '951640227', estado: EstadoCita.enTaller, ordenId: 'local-1041'),
      Cita(id: 'local-ci4', fecha: a(15, 0), servicio: 'Diagnóstico electrónico', placa: 'A4R-119', cliente: 'Elena Chávez', telefono: '987003514'),
      Cita(id: 'local-ci5', fecha: a(17, 0), servicio: 'Mantenimiento 20,000 km', placa: 'D8F-644', cliente: 'Sara Huamán', telefono: '943551190'),
    ];
  }
}
