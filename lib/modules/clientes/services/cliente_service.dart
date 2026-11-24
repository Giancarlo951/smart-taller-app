import 'dart:async';

import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';
import '../../../core/utils/validadores.dart';
import '../../catalogo/models/servicio.dart';
import '../models/cliente.dart';

/// Clientes y vehículos (tabla clientes). CRUD sobre [RepositorioSupabase],
/// con modo local en memoria sin Supabase. Equivale al perfil y las
/// direcciones de la app de referencia. La base no deja repetir documento
/// (unique) ni placa (trigger).
class ClienteService extends RepositorioSupabase<Cliente> {
  ClienteService._() : super('clientes');

  static final instancia = ClienteService._();

  @override
  Cliente desdeMapa(Map<String, dynamic> fila) => Cliente.desdeMapa(fila);

  @override
  Map<String, dynamic> aMapa(Cliente item) => item.aMapa();

  // ---- Modo local (sin Supabase) ----
  List<Cliente> _locales = clientesDeEjemplo();
  final _cambiosLocales = StreamController<List<Cliente>>.broadcast();

  /// Última lista recibida (para validar duplicados y buscar placas).
  List<Cliente> _actuales = const [];

  List<Cliente> get actuales => haySupabase ? _actuales : List.unmodifiable(_locales);

  void _emitirLocal() => _cambiosLocales.add(List.unmodifiable(_locales));

  StreamSubscription<List<Cliente>>? _suscripcion;

  Stream<List<Cliente>> _remotos() => super
      .listar()
      .map((lista) => _actuales = lista..sort(_porNombre));

  /// Con Supabase: mantiene [actuales] al día aunque no esté abierta la
  /// pantalla de clientes (la orden busca el vehículo por su placa).
  void iniciar() {
    if (!haySupabase || _suscripcion != null) return;
    _suscripcion = _remotos().listen((_) {}, onError: (_) {});
  }

  /// Al cerrar sesión con Supabase: deja de escuchar (sin sesión, las
  /// políticas RLS no devuelven filas).
  void detener() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _actuales = const [];
  }

  /// Vuelve a los clientes de ejemplo. Solo para pruebas.
  void reiniciarLocal() {
    _locales = clientesDeEjemplo();
    _emitirLocal();
  }

  /// Todos los clientes en tiempo real, ordenados por nombre.
  @override
  Stream<List<Cliente>> listar() async* {
    if (!haySupabase) {
      yield List.unmodifiable(_locales);
      yield* _cambiosLocales.stream;
      return;
    }
    yield* _remotos();
  }

  /// Busca por nombre, documento o placa.
  static List<Cliente> buscar(List<Cliente> clientes, String texto) {
    final busqueda = texto.trim().toLowerCase().replaceAll('-', '');
    if (busqueda.isEmpty) return clientes;
    return clientes.where((c) {
      return c.nombre.toLowerCase().contains(busqueda) ||
          c.numeroDocumento.contains(busqueda) ||
          c.vehiculos.any((v) => v.placa.toLowerCase().replaceAll('-', '').contains(busqueda));
    }).toList();
  }

  /// Cliente y vehículo dueños de [placa] (null si no está registrada).
  (Cliente, Vehiculo)? porPlaca(String placa) {
    final buscada = normalizarPlaca(placa);
    for (final c in actuales) {
      final v = c.vehiculo(buscada);
      if (v != null) return (c, v);
    }
    return null;
  }

  /// Valida y crea o actualiza el cliente. Devuelve su id.
  Future<String> guardar(Cliente cliente) async {
    final nombre = cliente.nombre.trim();
    if (nombre.length < 3) throw StateError('Ingrese el nombre o la razón social');
    final numero = cliente.numeroDocumento.trim();
    final errorDocumento = cliente.tipoDocumento == Cliente.ruc
        ? Validadores.ruc(numero)
        : Validadores.dni(numero);
    if (errorDocumento != null) throw StateError(errorDocumento);
    final errorTelefono = Validadores.telefonoContacto(cliente.telefono);
    if (errorTelefono != null) throw StateError(errorTelefono);
    final repetido = actuales.where(
      (c) => c.id != cliente.id && c.numeroDocumento == numero,
    );
    if (repetido.isNotEmpty) {
      throw StateError('El ${cliente.tipoDocumento} $numero ya es de ${repetido.first.nombre}');
    }
    for (final v in cliente.vehiculos) {
      _validarPlacaLibre(v.placa, clienteId: cliente.id);
    }
    final limpio = cliente.copyWith(
      nombre: nombre,
      numeroDocumento: numero,
      telefono: cliente.telefono.replaceAll(RegExp(r'[\s-]'), ''),
    );

    if (!haySupabase) {
      if (limpio.id.isEmpty) {
        final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
        _locales = [..._locales, limpio.copyWith(id: id)]..sort(_porNombre);
        _emitirLocal();
        return id;
      }
      _locales = [for (final c in _locales) c.id == limpio.id ? limpio : c];
      _emitirLocal();
      return limpio.id;
    }
    if (limpio.id.isEmpty) return enSupabase(() => crear(limpio));
    await enSupabase(() => actualizar(limpio.id, limpio));
    return limpio.id;
  }

  static int _porNombre(Cliente a, Cliente b) => a.nombre.compareTo(b.nombre);

  void _validarPlacaLibre(String placa, {required String clienteId}) {
    final error = Validadores.placa(placa);
    if (error != null) throw StateError(error);
    final dueno = porPlaca(placa);
    if (dueno != null && dueno.$1.id != clienteId) {
      throw StateError('La placa ${normalizarPlaca(placa)} ya está registrada a ${dueno.$1.nombre}');
    }
  }

  Cliente _cliente(String id) {
    for (final c in actuales) {
      if (c.id == id) return c;
    }
    throw StateError('El cliente ya no existe');
  }

  /// Agrega o edita un vehículo del cliente ([placaAnterior] al editar).
  Future<void> guardarVehiculo(String clienteId, Vehiculo vehiculo, {String? placaAnterior}) async {
    final cliente = _cliente(clienteId);
    final placa = normalizarPlaca(vehiculo.placa);
    _validarPlacaLibre(placa, clienteId: clienteId);
    final errorAnio = Validadores.anio('${vehiculo.anio}');
    if (errorAnio != null) throw StateError(errorAnio);
    if (vehiculo.marca.trim().isEmpty || vehiculo.modelo.trim().isEmpty) {
      throw StateError('Ingrese la marca y el modelo');
    }
    if (!TiposVehiculo.claves.contains(vehiculo.tipo)) {
      throw StateError('Seleccione el tipo de vehículo');
    }
    final limpio = vehiculo.copyWith(
      placa: placa,
      marca: vehiculo.marca.trim(),
      modelo: vehiculo.modelo.trim(),
    );
    final anterior = placaAnterior == null ? null : normalizarPlaca(placaAnterior);
    final otros = cliente.vehiculos.where((v) => v.placa != (anterior ?? placa));
    await guardar(cliente.copyWith(vehiculos: [...otros, limpio]));
  }

  Future<void> eliminarVehiculo(String clienteId, String placa) async {
    final cliente = _cliente(clienteId);
    await guardar(cliente.copyWith(
      vehiculos: cliente.vehiculos.where((v) => v.placa != placa).toList(),
    ));
  }

  /// Elimina el cliente y lo devuelve para "Deshacer".
  Future<Cliente> eliminarCliente(String id) async {
    final cliente = _cliente(id);
    if (!haySupabase) {
      _locales = _locales.where((c) => c.id != id).toList();
      _emitirLocal();
      return cliente;
    }
    // RLS: solo administración borra (si no, la base no borra nada).
    final borradas = await enSupabase(() => supabase.from(tabla).delete().eq('id', id).select('id'));
    if (borradas.isEmpty) throw StateError('Solo administración puede eliminar clientes');
    return cliente;
  }

  Future<void> restaurarCliente(Cliente cliente) async {
    if (!haySupabase) {
      _locales = [..._locales, cliente]..sort(_porNombre);
      _emitirLocal();
      return;
    }
    await enSupabase(() => restaurar(cliente.id, cliente));
  }

  /// Al crear una orden: km del vehículo, fecha del último servicio y
  /// cantidad de servicios del cliente. No falla la orden si no se puede.
  Future<void> registrarServicio(String placa, {required int km, DateTime? fecha}) async {
    final dueno = porPlaca(placa);
    if (dueno == null) return;
    final (cliente, vehiculo) = dueno;
    final actualizado = cliente.copyWith(
      servicios: cliente.servicios + 1,
      vehiculos: [
        for (final v in cliente.vehiculos)
          v.placa == vehiculo.placa
              ? v.copyWith(km: km > v.km ? km : v.km, ultimoServicio: fecha ?? DateTime.now())
              : v,
      ],
    );
    try {
      if (!haySupabase) {
        _locales = [for (final c in _locales) c.id == cliente.id ? actualizado : c];
        _emitirLocal();
        return;
      }
      await enSupabase(() => actualizar(cliente.id, actualizado));
    } catch (_) {
      // la orden ya se creó; el km se corrige en la próxima visita
    }
  }

  /// Clientes nuevos registrados en [desde, hasta) (para reportes).
  int nuevosEntre(DateTime desde, DateTime hasta) => actuales
      .where((c) => !c.creadoEn.isBefore(desde) && c.creadoEn.isBefore(hasta))
      .length;

  /// Sube los clientes de ejemplo a Supabase (si el documento ya existe, lo
  /// actualiza). La base genera los ids.
  Future<void> sembrar() async {
    if (!haySupabase) throw StateError('Supabase no está configurado');
    await enSupabase(() => supabase
        .from(tabla)
        .upsert([for (final c in clientesDeEjemplo()) c.aMapa()], onConflict: 'numero_documento'));
  }

  /// Datos de ejemplo, no reales.
  static List<Cliente> clientesDeEjemplo() {
    final alta = DateTime(2025, 3, 10);
    Cliente persona(String id, String nombre, String dni, String telefono, int servicios, List<Vehiculo> vehiculos) =>
        Cliente(
          id: id,
          nombre: nombre,
          tipoDocumento: Cliente.dni,
          numeroDocumento: dni,
          telefono: telefono,
          servicios: servicios,
          vehiculos: vehiculos,
          creadoEn: alta,
        );
    return [
      persona('local-c1', 'Elena Chávez Rojas', '41887520', '987003514', 4, [
        Vehiculo(placa: 'A4R-119', marca: 'Nissan', modelo: 'Sentra', anio: 2017, km: 112900, ultimoServicio: DateTime(2026, 6, 2)),
      ]),
      persona('local-c2', 'Julio Ramos Quispe', '46220931', '976884301', 5, [
        Vehiculo(placa: 'B9M-772', marca: 'Kia', modelo: 'Rio', anio: 2020, km: 55300, ultimoServicio: DateTime(2026, 9, 1)),
      ]),
      persona('local-c3', 'Marco Ríos Anco', '70884213', '951640227', 3, [
        Vehiculo(placa: 'W7B-320', marca: 'Hyundai', modelo: 'Accent', anio: 2021, km: 41150, ultimoServicio: DateTime(2026, 9, 5)),
      ]),
      persona('local-c4', 'Pedro Loayza Meza', '43015566', '964225870', 2, [
        Vehiculo(placa: 'C1T-509', marca: 'Toyota', modelo: 'RAV4', anio: 2018, tipo: TiposVehiculo.suv, km: 87400),
      ]),
      persona('local-c5', 'Rosa Paucar Lazo', '45120884', '964112480', 7, [
        Vehiculo(placa: 'V2K-841', marca: 'Toyota', modelo: 'Yaris', anio: 2019, km: 78420, ultimoServicio: DateTime(2026, 7, 14)),
        Vehiculo(placa: 'F3L-207', marca: 'Toyota', modelo: 'Hilux', anio: 2015, tipo: TiposVehiculo.suv, km: 160300, ultimoServicio: DateTime(2026, 3, 20)),
      ]),
      persona('local-c6', 'Sara Huamán Torres', '47781203', '943551190', 1, [
        Vehiculo(placa: 'D8F-644', marca: 'Suzuki', modelo: 'Swift', anio: 2022, km: 19800),
      ]),
      Cliente(
        id: 'local-c7',
        nombre: 'Transportes Mantaro S.A.C.',
        tipoDocumento: Cliente.ruc,
        numeroDocumento: '20486112094',
        telefono: '064231447',
        servicios: 14,
        creadoEn: alta,
        vehiculos: [
          Vehiculo(placa: 'X9P-114', marca: 'Hyundai', modelo: 'H1', anio: 2022, tipo: TiposVehiculo.pesado, km: 98000, ultimoServicio: DateTime(2026, 8, 18)),
          Vehiculo(placa: 'X9P-115', marca: 'Hyundai', modelo: 'H1', anio: 2022, tipo: TiposVehiculo.pesado, km: 102500, ultimoServicio: DateTime(2026, 8, 18)),
        ],
      ),
    ];
  }
}
