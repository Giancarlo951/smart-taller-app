import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';
import '../models/adicional.dart';
import '../models/categoria.dart';
import '../models/codigo_promocional.dart';
import '../models/config_taller.dart';
import '../models/repuesto.dart';
import '../models/servicio.dart';
import 'catalogo_local.dart';

/// Catálogo completo en memoria (servicios, repuestos, adicionales...).
/// Equivale al `Menu` de la app de referencia.
class Catalogo {
  const Catalogo({
    required this.categorias,
    required this.servicios,
    required this.repuestos,
    required this.adicionales,
    required this.config,
    required this.promociones,
  });

  final List<Categoria> categorias;
  final List<Servicio> servicios;
  final List<Repuesto> repuestos;
  final List<Adicional> adicionales;
  final ConfigTaller config;
  final List<CodigoPromocional> promociones;

  Servicio? servicio(String id) {
    for (final s in servicios) {
      if (s.id == id) return s;
    }
    return null;
  }

  Repuesto? repuesto(String codigo) {
    for (final r in repuestos) {
      if (r.codigo == codigo) return r;
    }
    return null;
  }

  Adicional? adicional(String id) {
    for (final a in adicionales) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Adicionales disponibles de un servicio.
  List<Adicional> adicionalesDe(Servicio servicio) => servicio.adicionalIds
      .map(adicional)
      .whereType<Adicional>()
      .where((a) => a.disponible)
      .toList();

  List<Categoria> _deTipo(String tipo) =>
      categorias.where((c) => c.activa && c.tipo == tipo).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));

  List<Categoria> get categoriasServicio => _deTipo(Categoria.tipoServicio);
  List<Categoria> get categoriasRepuesto => _deTipo(Categoria.tipoRepuesto);

  static String _normalizar(String texto) => texto.trim().toLowerCase();

  /// Filtra por categoría y por texto (nombre o subtítulo).
  List<Servicio> filtrarServicios({
    String categoriaId = Categoria.idTodas,
    String texto = '',
    bool soloDisponibles = true,
  }) {
    final busqueda = _normalizar(texto);
    return servicios.where((s) {
      if (soloDisponibles && !s.disponible) return false;
      final enCategoria =
          categoriaId == Categoria.idTodas || s.categoriaIds.contains(categoriaId);
      final coincide =
          busqueda.isEmpty ||
          s.nombre.toLowerCase().contains(busqueda) ||
          s.subtitulo.toLowerCase().contains(busqueda);
      return enCategoria && coincide;
    }).toList();
  }

  /// Filtra el inventario por texto (nombre, código o marca).
  List<Repuesto> filtrarRepuestos({
    String texto = '',
    String categoriaId = Categoria.idTodas,
    bool soloCriticos = false,
    bool incluirInactivos = true,
  }) {
    final busqueda = _normalizar(texto);
    return repuestos.where((r) {
      if (!incluirInactivos && !r.activo) return false;
      if (soloCriticos && !r.critico) return false;
      final enCategoria =
          categoriaId == Categoria.idTodas || r.categoriaId == categoriaId;
      final coincide =
          busqueda.isEmpty ||
          r.nombre.toLowerCase().contains(busqueda) ||
          r.codigo.toLowerCase().contains(busqueda) ||
          r.marca.toLowerCase().contains(busqueda);
      return enCategoria && coincide;
    }).toList();
  }

  /// Repuestos activos por debajo del mínimo (KPI "Stock crítico").
  List<Repuesto> get stockCritico =>
      repuestos.where((r) => r.activo && r.critico).toList();

  Catalogo copyWith({
    List<Categoria>? categorias,
    List<Servicio>? servicios,
    List<Repuesto>? repuestos,
    List<Adicional>? adicionales,
    ConfigTaller? config,
    List<CodigoPromocional>? promociones,
  }) => Catalogo(
    categorias: categorias ?? this.categorias,
    servicios: servicios ?? this.servicios,
    repuestos: repuestos ?? this.repuestos,
    adicionales: adicionales ?? this.adicionales,
    config: config ?? this.config,
    promociones: promociones ?? this.promociones,
  );
}

/// Lee el catálogo de Supabase en tiempo real (categorias, servicios,
/// repuestos, adicionales, config 'taller') y, si no hay datos o no hay
/// Supabase, usa el catálogo local de ejemplo. También lo edita (panel de
/// inventario y catálogo) y mueve el stock.
class CatalogoService extends ChangeNotifier {
  CatalogoService._();

  static final instancia = CatalogoService._();

  static Catalogo get local => Catalogo(
    categorias: CatalogoLocal.categorias,
    servicios: List.of(CatalogoLocal.servicios),
    repuestos: List.of(CatalogoLocal.repuestos),
    adicionales: CatalogoLocal.adicionales,
    config: CatalogoLocal.config,
    promociones: List.of(CatalogoLocal.promociones),
  );

  Catalogo _catalogo = local;

  /// true cuando el catálogo viene de la base (no del ejemplo local).
  bool desdeServidor = false;

  /// Catálogo actual (síncrono) para los widgets.
  Catalogo get catalogo => _catalogo;

  final List<StreamSubscription<Object?>> _suscripciones = [];
  final Map<String, List<Object>> _remoto = {};
  ConfigTaller? _configRemota;

  /// Empieza a escuchar Supabase (sin Supabase no hace nada).
  void iniciar() {
    if (!haySupabase || _suscripciones.isNotEmpty) return;
    void escuchar<T extends Object>(
      String tabla,
      String clave,
      T Function(Map<String, dynamic>) convertir,
    ) {
      _suscripciones.add(
        supabase.from(tabla).stream(primaryKey: [clave]).listen((filas) {
          _remoto[tabla] = filas.map(convertir).toList();
          _reconstruir();
        }, onError: (_) {}),
      );
    }

    escuchar('categorias', 'id', Categoria.desdeMapa);
    escuchar('servicios', 'id', Servicio.desdeMapa);
    escuchar('repuestos', 'codigo', Repuesto.desdeMapa);
    escuchar('adicionales', 'id', Adicional.desdeMapa);
    _suscripciones.add(
      supabase.from('config').stream(primaryKey: ['id']).eq('id', 'taller').listen((filas) {
        _configRemota = filas.isEmpty ? null : ConfigTaller.desdeMapa(leerMapa(filas.first['datos']));
        _reconstruir();
      }, onError: (_) {}),
    );
  }

  void _reconstruir() {
    final servicios = _remoto['servicios']?.cast<Servicio>() ?? const [];
    final repuestos = _remoto['repuestos']?.cast<Repuesto>() ?? const [];
    // Base vacía: se queda el catálogo de ejemplo.
    if (servicios.isEmpty && repuestos.isEmpty) {
      desdeServidor = false;
      notifyListeners();
      return;
    }
    desdeServidor = true;
    final categorias = _remoto['categorias']?.cast<Categoria>().toList() ?? [];
    final adicionales = _remoto['adicionales']?.cast<Adicional>().toList() ?? [];
    _catalogo = Catalogo(
      categorias: categorias.isEmpty ? CatalogoLocal.categorias : categorias,
      // Populares primero.
      servicios: servicios.toList()..sort((a, b) => (b.popular ? 1 : 0) - (a.popular ? 1 : 0)),
      repuestos: repuestos.toList()..sort((a, b) => a.nombre.compareTo(b.nombre)),
      adicionales: adicionales.isEmpty ? CatalogoLocal.adicionales : adicionales,
      config: _configRemota ?? CatalogoLocal.config,
      promociones: _catalogo.promociones,
    );
    notifyListeners();
  }

  /// Vuelve al catálogo de ejemplo. Solo para pruebas y al cerrar sesión.
  void reiniciarLocal() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();
    _remoto.clear();
    _configRemota = null;
    desdeServidor = false;
    _catalogo = local;
    notifyListeners();
  }

  void _actualizarLocal(Catalogo nuevo) {
    _catalogo = nuevo;
    notifyListeners();
  }

  /// Ejecuta una escritura en Supabase con los errores en español.
  Future<T> _remota<T>(Future<T> Function() accion) => enSupabase(accion);

  // ----------------------------------------------------------- Servicios

  /// Crea el servicio si su id está vacío; si no, actualiza sus datos.
  Future<void> guardarServicio(Servicio servicio) async {
    if (servicio.nombre.trim().isEmpty) {
      throw StateError('Ingrese el nombre del servicio');
    }
    if (servicio.precios.isEmpty || servicio.precios.values.any((p) => p.precioCentimos <= 0)) {
      throw StateError('Cada tipo de vehículo necesita un precio mayor a 0');
    }
    final descuento = servicio.descuentoPorcentaje ?? 0;
    if (descuento < 0 || descuento >= 100) {
      throw StateError('El descuento debe estar entre 0 y 99 %');
    }
    if (!haySupabase) {
      final lista = List.of(_catalogo.servicios);
      final indice = lista.indexWhere((s) => s.id == servicio.id);
      if (servicio.id.isEmpty || indice < 0) {
        final id = servicio.id.isEmpty ? 'local-${DateTime.now().microsecondsSinceEpoch}' : servicio.id;
        lista.insert(0, servicio.copyWith(id: id));
      } else {
        lista[indice] = servicio;
      }
      _actualizarLocal(_catalogo.copyWith(servicios: lista));
      return;
    }
    // Sin id, la base genera uno; con id, crea o reemplaza.
    await _remota(() => servicio.id.isEmpty
        ? supabase.from('servicios').insert(servicio.aMapa())
        : supabase.from('servicios').upsert(servicio.aMapa()));
  }

  Future<void> cambiarDisponibleServicio(String id, bool disponible) async {
    if (!haySupabase) {
      _actualizarLocal(_catalogo.copyWith(servicios: [
        for (final s in _catalogo.servicios) s.id == id ? s.copyWith(disponible: disponible) : s,
      ]));
      return;
    }
    await _remota(() => supabase.from('servicios').update({'disponible': disponible}).eq('id', id));
  }

  Future<void> eliminarServicio(String id) async {
    if (!haySupabase) {
      _actualizarLocal(_catalogo.copyWith(servicios: _catalogo.servicios.where((s) => s.id != id).toList()));
      return;
    }
    await _remota(() => supabase.from('servicios').delete().eq('id', id));
  }

  // ----------------------------------------------------------- Inventario

  /// Crea o edita un repuesto. Al crear, el código no puede repetirse.
  Future<void> guardarRepuesto(Repuesto repuesto, {bool nuevo = false}) async {
    final codigo = repuesto.codigo.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{2,5}-[A-Z0-9]{2,6}$').hasMatch(codigo)) {
      throw StateError('El código debe tener el formato LUB-1040');
    }
    if (repuesto.nombre.trim().isEmpty) {
      throw StateError('Ingrese el nombre del repuesto');
    }
    if (repuesto.precioCentimos <= 0) {
      throw StateError('El precio debe ser mayor a 0');
    }
    if (repuesto.stock < 0 || repuesto.minimo < 0) {
      throw StateError('El stock y el mínimo no pueden ser negativos');
    }
    if (nuevo && _catalogo.repuesto(codigo) != null) {
      throw StateError('Ya existe un repuesto con el código $codigo');
    }
    final limpio = repuesto.copyWith(codigo: codigo, nombre: repuesto.nombre.trim());
    if (!haySupabase) {
      final lista = List.of(_catalogo.repuestos);
      final indice = lista.indexWhere((r) => r.codigo == codigo);
      indice >= 0 ? lista[indice] = limpio : lista.insert(0, limpio);
      _actualizarLocal(_catalogo.copyWith(repuestos: lista));
      return;
    }
    await _remota(() => nuevo
        ? supabase.from('repuestos').insert(limpio.aMapa())
        : supabase.from('repuestos').update(limpio.aMapa()).eq('codigo', codigo));
  }

  Future<void> cambiarActivoRepuesto(String codigo, bool activo) async {
    if (!haySupabase) {
      _actualizarLocal(_catalogo.copyWith(repuestos: [
        for (final r in _catalogo.repuestos) r.codigo == codigo ? r.copyWith(activo: activo) : r,
      ]));
      return;
    }
    await _remota(() => supabase.from('repuestos').update({'activo': activo}).eq('codigo', codigo));
  }

  /// Elimina y devuelve el repuesto (para "Deshacer").
  Future<Repuesto?> eliminarRepuesto(String codigo) async {
    final repuesto = _catalogo.repuesto(codigo);
    if (!haySupabase) {
      _actualizarLocal(_catalogo.copyWith(
        repuestos: _catalogo.repuestos.where((r) => r.codigo != codigo).toList(),
      ));
      return repuesto;
    }
    await _remota(() => supabase.from('repuestos').delete().eq('codigo', codigo));
    return repuesto;
  }

  /// Ingreso de mercadería (compra a proveedor): suma unidades.
  Future<void> ingresarStock(String codigo, int cantidad) async {
    if (cantidad <= 0) throw StateError('Ingrese una cantidad mayor a 0');
    if (_catalogo.repuesto(codigo) == null) {
      throw StateError('El repuesto $codigo no existe');
    }
    if (!haySupabase) {
      moverStockLocal({codigo: cantidad});
      return;
    }
    await _remota(() => supabase.rpc('mover_stock_repuesto', params: {'p_codigo': codigo, 'p_delta': cantidad}));
  }

  /// Inventario físico: deja el stock en [stock].
  Future<void> ajustarStock(String codigo, int stock) async {
    if (stock < 0) throw StateError('El stock no puede ser negativo');
    final actual = _catalogo.repuesto(codigo);
    if (actual == null) throw StateError('El repuesto $codigo no existe');
    if (!haySupabase) {
      moverStockLocal({codigo: stock - actual.stock});
      return;
    }
    await _remota(() => supabase.rpc('mover_stock_repuesto', params: {'p_codigo': codigo, 'p_stock': stock}));
  }

  /// Faltantes para mover [delta] (negativo = salida): "Batería: hay 1, se
  /// necesitan 2". Vacío si alcanza el stock.
  List<String> faltantes(Map<String, int> delta) => [
    for (final entrada in delta.entries)
      if (entrada.value < 0)
        if (_catalogo.repuesto(entrada.key) case final r?)
          if (r.stock + entrada.value < 0) '${r.nombre}: hay ${r.stock}, se necesitan ${-entrada.value}',
  ];

  /// Modo local: aplica el movimiento de stock de una orden (salida o
  /// devolución). Devuelve los repuestos que quedaron en stock crítico.
  List<Repuesto> moverStockLocal(Map<String, int> delta) {
    final faltan = faltantes(delta);
    if (faltan.isNotEmpty) {
      throw StateError('Stock insuficiente. ${faltan.join('; ')}');
    }
    final criticos = <Repuesto>[];
    final lista = [
      for (final r in _catalogo.repuestos)
        if (delta[r.codigo] case final d? when d != 0) r.copyWith(stock: r.stock + d) else r,
    ];
    for (final r in lista) {
      final antes = _catalogo.repuesto(r.codigo);
      if (antes != null && !antes.critico && r.critico) criticos.add(r);
    }
    _actualizarLocal(_catalogo.copyWith(repuestos: lista));
    return criticos;
  }

  // ------------------------------------------------------------ Promos

  /// Busca el código en codigos_promocionales; si no, en los locales.
  Future<CodigoPromocional?> buscarPromo(String codigo) async {
    final clave = codigo.trim().toUpperCase();
    if (clave.isEmpty) return null;
    if (haySupabase) {
      try {
        final fila = await supabase
            .from('codigos_promocionales')
            .select()
            .eq('codigo', clave)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (fila != null) return CodigoPromocional.desdeMapa(fila);
        return null;
      } catch (_) {
        // sin conexión: se valida con la lista local
      }
    }
    for (final promo in _catalogo.promociones) {
      if (promo.codigo == clave) return promo;
    }
    return null;
  }

  /// Modo local: suma un uso al código (crear_orden lo hace en la base).
  void sumarUsoPromoLocal(String codigo) {
    _catalogo = _catalogo.copyWith(promociones: [
      for (final p in _catalogo.promociones) p.codigo == codigo ? p.copyWith(usados: p.usados + 1) : p,
    ]);
  }

  /// Sube el catálogo de ejemplo a Supabase (Perfil → "Cargar datos de
  /// ejemplo"). Las filas con la misma clave se sobrescriben.
  Future<void> sembrar() async {
    if (!haySupabase) throw StateError('Supabase no está configurado');
    await _remota(() async {
      await supabase.from('categorias').upsert([for (final c in CatalogoLocal.categorias) c.aMapa()]);
      await supabase.from('servicios').upsert([for (final s in CatalogoLocal.servicios) s.aMapa()]);
      await supabase.from('repuestos').upsert([for (final r in CatalogoLocal.repuestos) r.aMapa()]);
      await supabase.from('adicionales').upsert([for (final a in CatalogoLocal.adicionales) a.aMapa()]);
      await supabase.from('codigos_promocionales').upsert([for (final p in CatalogoLocal.promociones) p.aMapa()]);
      await supabase.from('config').upsert({'id': 'taller', 'datos': CatalogoLocal.config.aMapa()});
    });
  }
}
