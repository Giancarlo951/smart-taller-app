import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';
import '../../../core/services/sesion_service.dart';
import '../../catalogo/models/adicional.dart';
import '../../catalogo/models/codigo_promocional.dart';
import '../../catalogo/models/config_taller.dart';
import '../../catalogo/models/repuesto.dart';
import '../../catalogo/models/servicio.dart';
import '../../catalogo/services/catalogo_service.dart';
import '../models/calculadora_precios.dart';
import '../models/linea_cotizacion.dart';
import '../models/orden.dart';

/// Línea de una orden anterior con el precio de hoy. [disponible] es false
/// si el servicio o repuesto ya no está en el catálogo.
class LineaRepetida {
  const LineaRepetida({
    required this.linea,
    this.servicio,
    this.repuesto,
    this.adicionales = const [],
    this.precioCentimos = 0,
  });

  final LineaOrden linea;
  final Servicio? servicio;
  final Repuesto? repuesto;
  final List<Adicional> adicionales;

  /// Precio unitario de hoy (puede ser distinto al que se cobró).
  final int precioCentimos;

  bool get disponible => servicio != null || repuesto != null;

  int get totalCentimos => precioCentimos * linea.cantidad;
}

/// Borrador de la orden que se está armando en recepción (equivale al
/// carrito de la app de referencia). Los cambios se aplican primero en
/// memoria (optimista) y luego se sincronizan con personal.borrador.
class CotizacionService extends ChangeNotifier {
  CotizacionService({this.sincronizar = true, Catalogo Function()? catalogo})
    : _catalogo = catalogo ?? (() => CatalogoService.instancia.catalogo);

  static final instancia = CotizacionService();

  static const _claveDomicilio = 'servicioADomicilio';
  static const maximoServicio = 10;

  /// false en los tests: trabaja solo en memoria.
  final bool sincronizar;
  final Catalogo Function() _catalogo;

  final List<LineaCotizacion> _lineas = [];
  CodigoPromocional? _promo;
  bool? _aDomicilio;
  String _tipoVehiculo = TiposVehiculo.auto;

  List<LineaCotizacion> get lineas => List.unmodifiable(_lineas);

  CodigoPromocional? get promo => _promo;

  bool get estaVacia => _lineas.isEmpty;

  int get cantidadItems => CalculadoraPrecios.cantidadItems(_lineas);

  /// Tipo de vehículo del borrador: define el precio de los servicios.
  String get tipoVehiculo => _tipoVehiculo;

  /// Servicio a domicilio / recojo del vehículo. Se recuerda para la próxima.
  bool get aDomicilio =>
      _aDomicilio ??= SesionService.instancia.preferencias?.getBool(_claveDomicilio) ?? false;

  set aDomicilio(bool valor) {
    if (valor == aDomicilio) return;
    _aDomicilio = valor;
    notifyListeners();
    SesionService.instancia.preferencias?.setBool(_claveDomicilio, valor);
  }

  int recargoPara(ConfigTaller config) => aDomicilio ? config.recargoDomicilioCentimos : 0;

  /// Tiempo en bahía de los servicios del borrador (para la entrega).
  int minutosEstimados() {
    final catalogo = _catalogo();
    return _lineas.where((l) => l.esServicio).fold(
      0,
      (suma, l) => suma + (catalogo.servicio(l.refId)?.precio(_tipoVehiculo).minutos ?? 0) * l.cantidad,
    );
  }

  /// Entrega sugerida: [ahora] + tiempo de bahía, redondeada a la media hora
  /// siguiente (mínimo una hora).
  static DateTime entregaSugerida(DateTime ahora, int minutos) {
    final fin = ahora.add(Duration(minutes: minutos < 60 ? 60 : minutos));
    final resto = fin.minute % 30;
    final redondeada = resto == 0 && fin.second == 0 ? fin : fin.add(Duration(minutes: 30 - resto));
    return DateTime(redondeada.year, redondeada.month, redondeada.day, redondeada.hour, redondeada.minute);
  }

  /// El mismo cálculo para el borrador y la orden (coinciden al céntimo).
  DesgloseOrden desglose(ConfigTaller config) => CalculadoraPrecios.calcular(
    lineas: _lineas,
    recargoCentimos: recargoPara(config),
    promo: _promo,
  );

  /// uid del personal con sesión (null sin Supabase o en pruebas).
  String? get _uid {
    final sesion = SesionService.instancia;
    if (!sincronizar || !haySupabase || !sesion.cuentaVinculada || sesion.usuarioId.isEmpty) {
      return null;
    }
    return sesion.usuarioId;
  }

  /// Recupera el borrador guardado (personal.borrador) al iniciar sesión.
  Future<void> cargar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final fila = await supabase
          .from('personal')
          .select('borrador')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      _lineas
        ..clear()
        ..addAll(leerListaMapas(fila?['borrador']).map(LineaCotizacion.desdeMapa))
        ..removeWhere((l) => l.cantidad <= 0);
      notifyListeners();
    } catch (_) {
      // sin conexión: se mantiene el borrador en memoria
    }
  }

  // --------------------------------------------------------------- Agregar

  /// Agrega el servicio para el tipo de vehículo del borrador; si ya existe
  /// la misma combinación suma la cantidad.
  LineaCotizacion agregarServicio({
    required Servicio servicio,
    List<Adicional> adicionales = const [],
    int cantidad = 1,
  }) {
    if (!servicio.disponible) {
      throw StateError('${servicio.nombre} no está disponible');
    }
    final ids = adicionales.map((a) => a.id).toList()..sort();
    final id = LineaCotizacion.generarId(
      LineaCotizacion.tipoServicio,
      servicio.id,
      variante: _tipoVehiculo,
      adicionales: ids,
    );
    final precio = CalculadoraPrecios.precioServicio(
      servicio: servicio,
      variante: _tipoVehiculo,
      adicionales: adicionales,
    );
    return _sumar(
      LineaCotizacion(
        id: id,
        tipo: LineaCotizacion.tipoServicio,
        refId: servicio.id,
        nombre: servicio.nombre,
        variante: _tipoVehiculo,
        adicionalIds: ids,
        precioUnitarioCentimos: precio,
        cantidad: cantidad.clamp(1, maximoServicio),
        agregadoEn: DateTime.now(),
      ),
      maximo: maximoServicio,
    );
  }

  /// Agrega el repuesto sin pasar el stock disponible.
  LineaCotizacion agregarRepuesto({required Repuesto repuesto, int cantidad = 1}) {
    if (!repuesto.activo) throw StateError('${repuesto.nombre} está descontinuado');
    if (repuesto.agotado) throw StateError('${repuesto.nombre} está agotado');
    final id = LineaCotizacion.generarId(LineaCotizacion.tipoRepuesto, repuesto.codigo);
    final yaHay = _lineas.where((l) => l.id == id).fold(0, (s, l) => s + l.cantidad);
    if (yaHay + cantidad > repuesto.stock) {
      throw StateError(
        'Solo hay ${repuesto.stock} unidades de ${repuesto.nombre}'
        '${yaHay > 0 ? ' ($yaHay ya en la orden)' : ''}',
      );
    }
    return _sumar(
      LineaCotizacion(
        id: id,
        tipo: LineaCotizacion.tipoRepuesto,
        refId: repuesto.codigo,
        nombre: repuesto.nombre,
        precioUnitarioCentimos: repuesto.precioCentimos,
        cantidad: cantidad.clamp(1, repuesto.stock),
        agregadoEn: DateTime.now(),
      ),
      maximo: repuesto.stock,
    );
  }

  LineaCotizacion _sumar(LineaCotizacion nueva, {required int maximo}) {
    final indice = _lineas.indexWhere((l) => l.id == nueva.id);
    final LineaCotizacion linea;
    if (indice >= 0) {
      linea = _lineas[indice].copyWith(
        cantidad: (_lineas[indice].cantidad + nueva.cantidad).clamp(1, maximo),
        precioUnitarioCentimos: nueva.precioUnitarioCentimos,
      );
      _lineas[indice] = linea;
    } else {
      linea = nueva;
      _lineas.insert(0, linea);
    }
    _cerrarCambio(linea);
    return linea;
  }

  /// Cambia adicionales o cantidad de un servicio. Si la combinación nueva
  /// ya existe, suma las unidades y quita la línea anterior.
  void reemplazarServicio({
    required String idAnterior,
    required Servicio servicio,
    List<Adicional> adicionales = const [],
    required int cantidad,
  }) {
    final ids = adicionales.map((a) => a.id).toList()..sort();
    final id = LineaCotizacion.generarId(
      LineaCotizacion.tipoServicio,
      servicio.id,
      variante: _tipoVehiculo,
      adicionales: ids,
    );
    final precio = CalculadoraPrecios.precioServicio(
      servicio: servicio,
      variante: _tipoVehiculo,
      adicionales: adicionales,
    );
    final unidades = cantidad.clamp(1, maximoServicio);
    final indiceAnterior = _lineas.indexWhere((l) => l.id == idAnterior);

    if (id == idAnterior && indiceAnterior >= 0) {
      _lineas[indiceAnterior] = _lineas[indiceAnterior].copyWith(
        cantidad: unidades,
        precioUnitarioCentimos: precio,
      );
      _cerrarCambio(_lineas[indiceAnterior]);
      return;
    }
    if (indiceAnterior >= 0) _borrar(_lineas.removeAt(indiceAnterior).id);

    final destino = _lineas.indexWhere((l) => l.id == id);
    if (destino >= 0) {
      _lineas[destino] = _lineas[destino].copyWith(
        cantidad: (_lineas[destino].cantidad + unidades).clamp(1, maximoServicio),
        precioUnitarioCentimos: precio,
      );
      _cerrarCambio(_lineas[destino]);
      return;
    }
    final linea = LineaCotizacion(
      id: id,
      tipo: LineaCotizacion.tipoServicio,
      refId: servicio.id,
      nombre: servicio.nombre,
      variante: _tipoVehiculo,
      adicionalIds: ids,
      precioUnitarioCentimos: precio,
      cantidad: unidades,
      agregadoEn: DateTime.now(),
    );
    _lineas.insert(indiceAnterior < 0 ? 0 : indiceAnterior.clamp(0, _lineas.length), linea);
    _cerrarCambio(linea);
  }

  /// Cambia el tipo de vehículo y vuelve a calcular el precio de los
  /// servicios (la mano de obra de una SUV cuesta más que la de un auto).
  void cambiarTipoVehiculo(String tipo) {
    if (tipo == _tipoVehiculo) return;
    _tipoVehiculo = tipo;
    final catalogo = _catalogo();
    for (var i = 0; i < _lineas.length; i++) {
      final linea = _lineas[i];
      if (!linea.esServicio) continue;
      final servicio = catalogo.servicio(linea.refId);
      if (servicio == null) continue;
      final adicionales = linea.adicionalIds
          .map(catalogo.adicional)
          .whereType<Adicional>()
          .toList();
      final nueva = linea.copyWith(
        id: LineaCotizacion.generarId(
          linea.tipo,
          linea.refId,
          variante: tipo,
          adicionales: linea.adicionalIds,
        ),
        variante: tipo,
        precioUnitarioCentimos: CalculadoraPrecios.precioServicio(
          servicio: servicio,
          variante: tipo,
          adicionales: adicionales,
        ),
      );
      _borrar(linea.id);
      _lineas[i] = nueva;
      _guardar(nueva);
    }
    _revalidarPromo();
    notifyListeners();
  }

  void _cerrarCambio(LineaCotizacion linea) {
    _revalidarPromo();
    notifyListeners();
    _guardar(linea);
  }

  /// Suma o resta unidades (mínimo 1). Los repuestos no pasan del stock.
  void cambiarCantidad(String id, int cambio) {
    final indice = _lineas.indexWhere((l) => l.id == id);
    if (indice < 0) return;
    final linea = _lineas[indice];
    final maximo = linea.esRepuesto
        ? (_catalogo().repuesto(linea.refId)?.stock ?? linea.cantidad)
        : maximoServicio;
    final nueva = (linea.cantidad + cambio).clamp(1, maximo < 1 ? 1 : maximo);
    if (nueva == linea.cantidad) return;
    _lineas[indice] = linea.copyWith(cantidad: nueva);
    _cerrarCambio(_lineas[indice]);
  }

  /// Elimina la línea y devuelve su posición para poder deshacer.
  (int, LineaCotizacion)? eliminar(String id) {
    final indice = _lineas.indexWhere((l) => l.id == id);
    if (indice < 0) return null;
    final linea = _lineas.removeAt(indice);
    _revalidarPromo();
    notifyListeners();
    _borrar(linea.id);
    return (indice, linea);
  }

  void restaurar(int indice, LineaCotizacion linea) {
    _lineas.insert(indice.clamp(0, _lineas.length), linea);
    notifyListeners();
    _guardar(linea);
  }

  /// [remoto] false cuando la orden ya borró el borrador en su transacción.
  void vaciar({bool remoto = true}) {
    final ids = _lineas.map((l) => l.id).toList();
    _lineas.clear();
    _promo = null;
    _tipoVehiculo = TiposVehiculo.auto;
    notifyListeners();
    if (remoto) ids.forEach(_borrar);
  }

  // ------------------------------------------------------------- Repetir

  /// "Repetir servicio": las líneas de [orden] con los precios de hoy.
  static List<LineaRepetida> lineasParaRepetir(Orden orden, Catalogo catalogo) =>
      orden.lineas.map((linea) {
        if (linea.esRepuesto) {
          final repuesto = catalogo.repuesto(linea.refId);
          if (repuesto == null || !repuesto.disponible) return LineaRepetida(linea: linea);
          return LineaRepetida(
            linea: linea,
            repuesto: repuesto,
            precioCentimos: repuesto.precioCentimos,
          );
        }
        final servicio = catalogo.servicio(linea.refId);
        if (servicio == null || !servicio.disponible) return LineaRepetida(linea: linea);
        // Un adicional que ya no existe simplemente no se agrega.
        final adicionales = linea.adicionales
            .map((a) => catalogo.adicional(a.id))
            .whereType<Adicional>()
            .toList();
        return LineaRepetida(
          linea: linea,
          servicio: servicio,
          adicionales: adicionales,
          precioCentimos: CalculadoraPrecios.precioServicio(
            servicio: servicio,
            variante: orden.tipoVehiculo,
            adicionales: adicionales,
          ),
        );
      }).toList();

  /// Suma al borrador las líneas disponibles (se juntan con lo que ya haya)
  /// y repite el tipo de vehículo. Devuelve cuántas unidades agregó; los
  /// repuestos sin stock suficiente se saltan.
  int repetir(Iterable<LineaRepetida> lineas, {required String tipoVehiculo}) {
    cambiarTipoVehiculo(tipoVehiculo);
    var unidades = 0;
    for (final linea in lineas) {
      try {
        if (linea.servicio case final servicio?) {
          agregarServicio(
            servicio: servicio,
            adicionales: linea.adicionales,
            cantidad: linea.linea.cantidad,
          );
        } else if (linea.repuesto case final repuesto?) {
          agregarRepuesto(repuesto: repuesto, cantidad: linea.linea.cantidad);
        } else {
          continue;
        }
        unidades += linea.linea.cantidad;
      } on StateError {
        // sin stock suficiente para repetir esa línea
      }
    }
    return unidades;
  }

  // -------------------------------------------------------------- Promos

  /// Devuelve el mensaje de error o null si el código se aplicó.
  String? aplicarPromo(CodigoPromocional promo) {
    final error = promo.validar(CalculadoraPrecios.subtotal(_lineas));
    if (error != null) return error;
    _promo = promo;
    notifyListeners();
    return null;
  }

  void quitarPromo() {
    _promo = null;
    notifyListeners();
  }

  void _revalidarPromo() {
    if (_promo?.validar(CalculadoraPrecios.subtotal(_lineas)) != null) _promo = null;
  }

  // El borrador se guarda completo en personal.borrador. Varios cambios
  // seguidos (p. ej. cambiar el tipo de vehículo) se juntan en una escritura.
  Timer? _espera;

  void _guardar(LineaCotizacion _) => _sincronizar();

  void _borrar(String _) => _sincronizar();

  void _sincronizar() {
    final uid = _uid;
    if (uid == null) return;
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      supabase
          .from('personal')
          .update({'borrador': _lineas.map((l) => l.aMapa()).toList()})
          .eq('id', uid)
          .then((_) {}, onError: (_) {});
    });
  }
}
