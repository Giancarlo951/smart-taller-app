import 'dart:async';

import '../../../core/services/supabase_servicio.dart';
import '../../../core/utils/formatos.dart';
import '../../../core/utils/validadores.dart';
import '../../avisos/models/aviso.dart';
import '../../avisos/services/aviso_service.dart';
import '../../catalogo/models/adicional.dart';
import '../../catalogo/models/codigo_promocional.dart';
import '../../catalogo/models/config_taller.dart';
import '../../catalogo/models/repuesto.dart';
import '../../catalogo/services/catalogo_service.dart';
import '../../clientes/services/cliente_service.dart';
import '../../cuentas/models/rol.dart';
import '../models/calculadora_precios.dart';
import '../models/linea_cotizacion.dart';
import '../models/orden.dart';
import 'mercado_pago_service.dart';
import 'ordenes_local.dart';
import 'pago_service.dart';
import 'reglas_orden.dart';

/// Quién hace la acción (rol para los permisos y nombre para el historial).
class Actor {
  const Actor({required this.rol, this.nombre = '', this.uid = ''});

  final Rol rol;
  final String nombre;
  final String uid;
}

/// Órdenes de trabajo (tabla ordenes).
///
/// Como PedidoService de la app de referencia: los precios se recalculan
/// desde el catálogo (nunca se toman del borrador) y la orden se crea con el
/// correlativo OT-#### en una sola transacción. En Supabase esa transacción
/// es la función SQL `crear_orden` (supabase/esquema.sql), que además valida
/// montos, stock y código promocional; las demás acciones también son
/// funciones SQL que vuelven a comprobar el rol en el servidor. Al llegar a
/// la etapa Repuestos sale el stock (y vuelve si la orden se anula).
/// Sin Supabase, las órdenes viven en memoria con las mismas reglas.
class OrdenService extends RepositorioSupabase<Orden> {
  OrdenService._() : super('ordenes');

  static final instancia = OrdenService._();

  /// La primera orden nueva será OT-1043 (las de ejemplo llegan a OT-1042).
  static const numeroInicial = OrdenesLocal.ultimoNumero;
  static const numeroInicialBoleta = OrdenesLocal.ultimaBoleta;
  static const numeroInicialFactura = OrdenesLocal.ultimaFactura;

  @override
  Orden desdeMapa(Map<String, dynamic> fila) => Orden.desdeMapa(fila);

  @override
  Map<String, dynamic> aMapa(Orden item) => item.aMapaNueva();

  CatalogoService get _catalogo => CatalogoService.instancia;
  AvisoService get _avisos => AvisoService.instancia;

  // ---- Modo local (sin Supabase) ----
  List<Orden> _locales = OrdenesLocal.ejemplo();
  final _cambiosLocales = StreamController<List<Orden>>.broadcast();
  int _ultimoLocal = numeroInicial;
  int _ultimaBoleta = numeroInicialBoleta;
  int _ultimaFactura = numeroInicialFactura;

  /// Vuelve a las órdenes de ejemplo. Solo para pruebas.
  void reiniciarLocal({DateTime? ahora}) {
    _locales = OrdenesLocal.ejemplo(ahora: ahora);
    _ultimoLocal = numeroInicial;
    _ultimaBoleta = numeroInicialBoleta;
    _ultimaFactura = numeroInicialFactura;
    _emitirLocal();
  }

  /// Órdenes del modo local (más recientes primero).
  List<Orden> get locales => List.unmodifiable(_locales);

  Stream<List<Orden>> _streamLocal(bool Function(Orden) filtro) async* {
    yield _locales.where(filtro).toList();
    yield* _cambiosLocales.stream.map((l) => l.where(filtro).toList());
  }

  void _emitirLocal() => _cambiosLocales.add(List.of(_locales));

  /// Filas de Supabase → órdenes, más recientes primero.
  List<Orden> _ordenar(List<Map<String, dynamic>> filas) =>
      filas.map(Orden.desdeMapa).toList()..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  void _reemplazarLocal(Orden orden) {
    final indice = _locales.indexWhere((o) => o.id == orden.id);
    if (indice < 0) return;
    _locales[indice] = orden;
    _emitirLocal();
  }

  Orden? _localPorId(String id) {
    for (final o in _locales) {
      if (o.id == id) return o;
    }
    return null;
  }

  // ------------------------------------------------------------ Lecturas

  /// Últimas órdenes, más recientes primero.
  Stream<List<Orden>> todas({int limite = 100}) {
    if (!haySupabase) return _streamLocal((_) => true).map((l) => l.take(limite).toList());
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .limit(limite)
        .map(_ordenar);
  }

  /// Órdenes en el taller (sin entregar ni anular).
  Stream<List<Orden>> activas() {
    if (!haySupabase) return _streamLocal((o) => o.estado.activa);
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .inFilter('estado', [for (final e in EstadoOrden.etapas) e.valor])
        .map(_ordenar);
  }

  /// Una orden en tiempo real (detalle y seguimiento).
  Stream<Orden?> escuchar(String id) {
    if (!haySupabase) {
      return _streamLocal((o) => o.id == id).map((l) => l.isEmpty ? null : l.first);
    }
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((filas) => filas.isEmpty ? null : Orden.desdeMapa(filas.first));
  }

  /// Órdenes creadas en [desde, hasta).
  Stream<List<Orden>> entre(DateTime desde, DateTime hasta) {
    bool enRango(Orden o) => !o.creadoEn.isBefore(desde) && o.creadoEn.isBefore(hasta);
    if (!haySupabase) return _streamLocal(enRango);
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .gte('created_at', fechaIso(desde))
        .map((filas) => _ordenar(filas).where(enRango).toList());
  }

  /// Historial de un vehículo.
  Stream<List<Orden>> deVehiculo(String placa) {
    final buscada = normalizarPlaca(placa);
    if (!haySupabase) return _streamLocal((o) => o.placa == buscada);
    return supabase.from('ordenes').stream(primaryKey: ['id']).eq('placa', buscada).map(_ordenar);
  }

  /// Historial de facturación (órdenes con comprobante), más recientes primero.
  Stream<List<Orden>> conComprobante({int limite = 100}) {
    List<Orden> porFecha(Iterable<Orden> l) => l.where((o) => o.tieneComprobante).toList()
      ..sort((a, b) => b.comprobante!.emitidoEn.compareTo(a.comprobante!.emitidoEn));
    if (!haySupabase) {
      return _streamLocal((o) => o.tieneComprobante).map((l) => porFecha(l).take(limite).toList());
    }
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .order('updated_at')
        .limit(300)
        .map((filas) => porFecha(filas.map(Orden.desdeMapa)).take(limite).toList());
  }

  /// Listas para entrega con el cobro pendiente o por verificar.
  Stream<List<Orden>> porCobrar() {
    bool pendiente(Orden o) => o.estado == EstadoOrden.listo && !o.estaPagada;
    if (!haySupabase) return _streamLocal(pendiente);
    return supabase
        .from('ordenes')
        .stream(primaryKey: ['id'])
        .eq('estado', EstadoOrden.listo.valor)
        .map((filas) => _ordenar(filas).where(pendiente).toList());
  }

  // ------------------------------------------------------------ Crear

  /// Convierte el borrador en líneas con los precios actuales del catálogo.
  /// [validarStock]: que alcance el stock (al crear o con stock reservado).
  static List<LineaOrden> lineasDesdeCatalogo(
    List<LineaCotizacion> lineas,
    Catalogo catalogo, {
    required String tipoVehiculo,
    bool validarStock = true,
  }) {
    final resultado = <LineaOrden>[];
    final pedidos = <String, int>{};
    for (final linea in lineas) {
      if (linea.cantidad <= 0) continue;
      if (linea.esRepuesto) {
        final repuesto = catalogo.repuesto(linea.refId);
        if (repuesto == null || !repuesto.activo) {
          throw StateError('${linea.nombre} ya no está en el inventario');
        }
        pedidos[repuesto.codigo] = (pedidos[repuesto.codigo] ?? 0) + linea.cantidad;
        resultado.add(LineaOrden(
          tipo: linea.tipo,
          refId: repuesto.codigo,
          nombre: repuesto.nombre,
          precioUnitarioCentimos: repuesto.precioCentimos,
          cantidad: linea.cantidad,
        ));
        continue;
      }
      final servicio = catalogo.servicio(linea.refId);
      if (servicio == null || !servicio.disponible) {
        throw StateError('${linea.nombre} ya no está disponible');
      }
      final adicionales = linea.adicionalIds.map(catalogo.adicional).whereType<Adicional>().toList();
      resultado.add(LineaOrden(
        tipo: linea.tipo,
        refId: servicio.id,
        nombre: servicio.nombre,
        variante: tipoVehiculo,
        adicionales: [
          for (final a in adicionales) AdicionalOrden(id: a.id, nombre: a.nombre, precioCentimos: a.precioCentimos),
        ],
        precioUnitarioCentimos: CalculadoraPrecios.precioServicio(
          servicio: servicio,
          variante: tipoVehiculo,
          adicionales: adicionales,
        ),
        cantidad: linea.cantidad,
      ));
    }
    if (validarStock) {
      for (final entrada in pedidos.entries) {
        final repuesto = catalogo.repuesto(entrada.key)!;
        if (entrada.value > repuesto.stock) {
          throw StateError('Solo hay ${repuesto.stock} unidades de ${repuesto.nombre}');
        }
      }
    }
    return resultado;
  }

  static List<LineaCotizacion> _comoBorrador(List<LineaOrden> lineas) =>
      [for (final l in lineas) l.aLineaCotizacion()];

  Future<Orden> crearOrden({
    required List<LineaCotizacion> lineas,
    required Catalogo catalogo,
    CodigoPromocional? promo,
    String clienteId = '',
    required String clienteNombre,
    String documentoCliente = '',
    required String telefono,
    required String placa,
    required String vehiculo,
    required String tipoVehiculo,
    required int km,
    int? kmAnterior,
    String motivo = '',
    String mecanico = '',
    DateTime? entregaEstimada,
    bool aDomicilio = false,
    required Actor actor,
  }) async {
    if (lineas.isEmpty && motivo.trim().isEmpty) {
      throw StateError('Agrega un servicio o describe el motivo de ingreso');
    }
    if (clienteNombre.trim().isEmpty) throw StateError('Seleccione el cliente');
    final errorTelefono = Validadores.telefonoContacto(telefono);
    if (errorTelefono != null) throw StateError(errorTelefono);
    final errorPlaca = Validadores.placa(placa);
    if (errorPlaca != null) throw StateError(errorPlaca);
    final errorKm = Validadores.kilometraje('$km', anterior: kmAnterior);
    if (errorKm != null) throw StateError(errorKm);
    final ahora = DateTime.now();
    if (entregaEstimada != null && entregaEstimada.isBefore(ahora)) {
      throw StateError('La entrega estimada no puede ser en el pasado');
    }

    // Recalcula cada línea con los precios actuales del catálogo.
    final lineasOrden = lineasDesdeCatalogo(lineas, catalogo, tipoVehiculo: tipoVehiculo);
    final config = catalogo.config;
    final desglose = CalculadoraPrecios.calcular(
      lineas: _comoBorrador(lineasOrden),
      recargoCentimos: aDomicilio ? config.recargoDomicilioCentimos : 0,
      promo: promo,
    );
    if (lineasOrden.isNotEmpty && desglose.subtotal < config.minimoOrdenCentimos) {
      throw StateError('El monto mínimo es ${formatoCentimos(config.minimoOrdenCentimos)}');
    }
    if (promo != null) {
      final error = promo.validar(desglose.subtotal);
      if (error != null) throw StateError(error);
    }

    final base = Orden(
      codigo: '',
      clienteId: clienteId,
      clienteNombre: clienteNombre.trim(),
      documentoCliente: documentoCliente,
      telefono: telefono.replaceAll(RegExp(r'[\s-]'), ''),
      placa: normalizarPlaca(placa),
      vehiculo: vehiculo,
      tipoVehiculo: tipoVehiculo,
      km: km,
      motivo: motivo.trim(),
      mecanico: mecanico,
      entregaEstimada: entregaEstimada,
      lineas: lineasOrden,
      subtotalCentimos: desglose.subtotal,
      descuentoCentimos: desglose.descuento,
      recargoCentimos: desglose.recargo,
      totalCentimos: desglose.total,
      codigoPromo: desglose.descuento > 0 ? promo?.codigo : null,
      aDomicilio: aDomicilio,
      estado: EstadoOrden.recepcion,
      historial: [CambioEstado(estado: EstadoOrden.recepcion, fecha: ahora, por: actor.nombre)],
      creadoPor: actor.uid,
      creadoPorNombre: actor.nombre,
      creadoEn: ahora,
      actualizadoEn: ahora,
    );

    final Orden orden;
    if (!haySupabase) {
      _ultimoLocal++;
      orden = base.copyWith(id: 'local-$_ultimoLocal', codigo: Orden.generarCodigo(_ultimoLocal));
      if (orden.codigoPromo != null) _catalogo.sumarUsoPromoLocal(orden.codigoPromo!);
      _locales.insert(0, orden);
      _emitirLocal();
    } else {
      // crear_orden: correlativo, uso del promo y borrador vacío en una
      // sola transacción del servidor.
      orden = Orden.desdeMapa(await rpcMapa('crear_orden', {'p': base.aMapaNueva()}));
    }

    await ClienteService.instancia.registrarServicio(orden.placa, km: km, fecha: ahora);
    await _avisos.registrar(
      TipoAviso.orden,
      '${orden.codigo} registrada: ${orden.placa} · ${orden.servicioPrincipal}.',
      ordenId: orden.id,
    );
    return orden;
  }

  // ------------------------------------------------------ Cambiar estado

  /// "Registrar avance": pasa a la siguiente etapa (máx. "Listo").
  Future<Orden> avanzar(Orden orden, {required Actor actor}) {
    final siguiente = orden.estado.siguienteEtapa;
    if (siguiente == null) {
      throw StateError(
        orden.estado.activa
            ? 'La orden ${orden.codigo} ya está lista para entrega'
            : 'La orden ${orden.codigo} ya está ${orden.estado.etiqueta.toLowerCase()}',
      );
    }
    return cambiarEstado(orden, siguiente, actor: actor);
  }

  /// Entrega el vehículo (la orden debe estar lista y pagada).
  Future<Orden> entregar(Orden orden, {required Actor actor}) =>
      cambiarEstado(orden, EstadoOrden.entregado, actor: actor);

  /// Anula la orden y devuelve al almacén los repuestos que ya salieron.
  Future<Orden> anular(Orden orden, {required Actor actor, required String motivo}) {
    if (motivo.trim().length < 5) throw StateError('Escribe el motivo de la anulación');
    return cambiarEstado(orden, EstadoOrden.cancelado, actor: actor, nota: motivo.trim());
  }

  /// Movimiento de stock al pasar a [destino]: salida al llegar a Repuestos,
  /// devolución al anular. Negativo = sale del almacén.
  static Map<String, int> movimientoDeStock(Orden orden, EstadoOrden destino) {
    if (destino == EstadoOrden.cancelado) {
      return orden.stockDescontado ? orden.repuestosRequeridos : const {};
    }
    if (!orden.stockDescontado && destino.descuentaStock) {
      return {for (final e in orden.repuestosRequeridos.entries) e.key: -e.value};
    }
    return const {};
  }

  /// Cambia el estado validando permisos y reglas; registra los pasos en el
  /// historial (con quién lo hizo) y mueve el stock si corresponde.
  Future<Orden> cambiarEstado(
    Orden orden,
    EstadoOrden destino, {
    required Actor actor,
    String nota = '',
  }) async {
    final error = ReglasOrden.validarCambio(orden, destino, actor.rol);
    if (error != null) throw StateError(error);

    List<Repuesto> criticos;
    Orden actualizada;
    if (!haySupabase) {
      final vigente = _localPorId(orden.id) ?? orden;
      final errorVigente = ReglasOrden.validarCambio(vigente, destino, actor.rol);
      if (errorVigente != null) throw StateError(errorVigente);
      final ahora = DateTime.now();
      final pasos = destino.pasosDesde(vigente.estado);
      final delta = movimientoDeStock(vigente, destino);
      // Igual que cambiar_estado_orden: pasar por Repuestos deja el stock
      // descontado aunque la orden todavía no tenga repuestos.
      final descontado = destino == EstadoOrden.cancelado
          ? false
          : (vigente.stockDescontado || destino.descuentaStock);
      criticos = delta.isEmpty ? const [] : _catalogo.moverStockLocal(delta);
      actualizada = vigente.copyWith(
        estado: destino,
        historial: [
          ...vigente.historial,
          for (final (i, estado) in pasos.indexed)
            CambioEstado(estado: estado, fecha: ahora, por: actor.nombre, nota: i == pasos.length - 1 ? nota : ''),
        ],
        stockDescontado: descontado,
        actualizadoEn: ahora,
      );
      _reemplazarLocal(actualizada);
    } else {
      final r = await rpcMapa('cambiar_estado_orden', {
        'p_orden': orden.id,
        'p_estado': destino.valor,
        'p_nota': nota,
        'p_por': actor.nombre,
      });
      actualizada = Orden.desdeMapa(leerMapa(r['orden']));
      criticos = _criticos(r['criticos']);
    }

    await _avisarCambio(actualizada, destino);
    await _avisarCriticos(criticos);
    return actualizada;
  }

  /// Repuestos que la función SQL reporta en stock crítico.
  static List<Repuesto> _criticos(Object? lista) => [
    for (final c in leerListaMapas(lista))
      Repuesto(
        codigo: '${c['codigo']}',
        nombre: c['nombre'] ?? '',
        precioCentimos: 0,
        stock: leerInt(c['stock']),
        minimo: leerInt(c['minimo']),
      ),
  ];

  Future<void> _avisarCriticos(List<Repuesto> criticos) async {
    for (final r in criticos) {
      await _avisos.registrar(
        TipoAviso.stock,
        '${r.nombre} quedó en ${r.stock} unidades, por debajo del mínimo de ${r.minimo}.',
      );
    }
  }

  Future<void> _avisarCambio(Orden orden, EstadoOrden destino) {
    final texto = switch (destino) {
      EstadoOrden.listo =>
        '${orden.codigo} está lista para entrega. Avisar a ${orden.clienteNombre} (${orden.telefono}).',
      EstadoOrden.entregado => '${orden.codigo} entregada a ${orden.clienteNombre}.',
      EstadoOrden.cancelado => '${orden.codigo} fue anulada.',
      _ => '${orden.codigo} pasó a ${destino.etiqueta.toLowerCase()}. '
          'Entrega estimada: ${orden.entregaTexto()}.',
    };
    return _avisos.registrar(TipoAviso.orden, texto, ordenId: orden.id);
  }

  // ------------------------------------------------------- Editar líneas

  /// Agrega o quita servicios y repuestos de una orden abierta (por ejemplo
  /// después del diagnóstico). Recalcula montos y, si los repuestos ya
  /// salieron del almacén, mueve la diferencia de stock.
  Future<Orden> actualizarLineas(
    Orden orden,
    List<LineaCotizacion> nuevas, {
    required Actor actor,
    Catalogo? catalogo,
  }) async {
    final error = ReglasOrden.validarEdicionLineas(orden);
    if (error != null) throw StateError(error);
    final cat = catalogo ?? _catalogo.catalogo;
    final lineas = lineasDesdeCatalogo(
      nuevas,
      cat,
      tipoVehiculo: orden.tipoVehiculo,
      validarStock: !orden.stockDescontado,
    );
    final subtotal = CalculadoraPrecios.subtotal(_comoBorrador(lineas));
    // El código ya se usó al crear la orden: se mantiene el descuento
    // (mismo cálculo que _descuento_promo en el servidor).
    final promo = orden.codigoPromo == null ? null : await _catalogo.buscarPromo(orden.codigoPromo!);
    final descuento = promo?.descuentoYaAplicado(subtotal) ?? 0;
    final total = subtotal - descuento + orden.recargoCentimos;

    var criticos = const <Repuesto>[];
    final Orden actualizada;
    if (!haySupabase) {
      final delta = <String, int>{};
      if (orden.stockDescontado) {
        final antes = orden.repuestosRequeridos;
        final despues = <String, int>{};
        for (final l in lineas.where((l) => l.esRepuesto)) {
          despues[l.refId] = (despues[l.refId] ?? 0) + l.cantidad;
        }
        for (final codigo in {...antes.keys, ...despues.keys}) {
          final d = (antes[codigo] ?? 0) - (despues[codigo] ?? 0);
          if (d != 0) delta[codigo] = d;
        }
      }
      if (delta.isNotEmpty) criticos = _catalogo.moverStockLocal(delta);
      actualizada = orden.copyWith(
        lineas: lineas,
        subtotalCentimos: subtotal,
        descuentoCentimos: descuento,
        totalCentimos: total,
        quitarPromo: descuento == 0,
        actualizadoEn: DateTime.now(),
      );
      _reemplazarLocal(actualizada);
    } else {
      final r = await rpcMapa('actualizar_lineas_orden', {
        'p_orden': orden.id,
        'p_lineas': lineas.map((l) => l.aMapa()).toList(),
        'p_subtotal': subtotal,
        'p_descuento': descuento,
        'p_total': total,
      });
      actualizada = Orden.desdeMapa(leerMapa(r['orden']));
      criticos = _criticos(r['criticos']);
    }
    await _avisarCriticos(criticos);
    return actualizada;
  }

  // ---------------------------------------------------------- Diagnóstico

  /// Guarda lo que encontró el mecánico al revisar el vehículo. Se puede
  /// corregir mientras la orden siga en el taller.
  Future<Orden> registrarDiagnostico(Orden orden, String texto, {required Actor actor}) async {
    final error = ReglasOrden.validarDiagnostico(orden, texto);
    if (error != null) throw StateError(error);
    if (!haySupabase) {
      final actualizada = orden.copyWith(diagnostico: texto.trim(), actualizadoEn: DateTime.now());
      _reemplazarLocal(actualizada);
      return actualizada;
    }
    final r = await rpcMapa('registrar_diagnostico', {'p_orden': orden.id, 'p_diagnostico': texto.trim()});
    return Orden.desdeMapa(r);
  }

  // ---------------------------------------------------------------- Cobro

  /// Registra el cobro con el medio de pago elegido. Efectivo queda pagado;
  /// Yape/Plin queda por verificar; tarjeta abre Mercado Pago (o simula el
  /// cobro en modo demo).
  Future<Orden> registrarCobro(
    Orden orden, {
    required String metodo,
    String? referencia,
    required Actor actor,
  }) async {
    final error = ReglasOrden.validarCobro(orden, actor.rol, metodo: metodo, referencia: referencia);
    if (error != null) throw StateError(error);
    final pago = await ServicioPago.para(metodo).procesar(totalCentimos: orden.totalCentimos, referencia: referencia);

    final Orden actualizada;
    if (!haySupabase) {
      final ahora = DateTime.now();
      actualizada = orden.copyWith(
        metodoPago: metodo,
        estadoPago: pago.estadoPago,
        referenciaPago: pago.referencia,
        pagadoEn: pago.estadoPago == EstadosPago.pagado ? ahora : null,
        actualizadoEn: ahora,
      );
      _reemplazarLocal(actualizada);
    } else {
      actualizada = Orden.desdeMapa(await rpcMapa('registrar_cobro', {
        'p_orden': orden.id,
        'p_metodo': metodo,
        'p_estado_pago': pago.estadoPago,
        'p_referencia': pago.referencia,
      }));
    }

    if (metodo == MetodosPago.tarjeta && PagoTarjeta.cobraConMercadoPago) {
      final url = await MercadoPagoService.instancia.crearLinkDePago(orden.id);
      await MercadoPagoService.instancia.abrirCheckout(url);
    }
    final monto = formatoCentimos(orden.totalCentimos);
    await _avisos.registrar(
      TipoAviso.pago,
      pago.estadoPago == EstadosPago.verificando
          ? 'Pago ${MetodosPago.etiquetas[metodo]} de ${orden.codigo} por $monto por verificar (Op. ${pago.referencia}).'
          : '${orden.codigo} cobrada: $monto (${MetodosPago.etiquetas[metodo]}).',
      ordenId: orden.id,
    );
    return actualizada;
  }

  /// Administración confirma el Yape/Plin con su N.° de operación.
  Future<Orden> aprobarPago(Orden orden, {required Actor actor}) async {
    final actualizada = await _verificar(orden, aprobar: true, actor: actor);
    await _avisos.registrar(TipoAviso.pago, 'Pago de ${orden.codigo} aprobado.', ordenId: orden.id);
    return actualizada;
  }

  /// El N.° de operación no aparece en la cuenta: se vuelve a cobrar.
  Future<Orden> rechazarPago(Orden orden, {required Actor actor}) async {
    final actualizada = await _verificar(orden, aprobar: false, actor: actor);
    await _avisos.registrar(TipoAviso.pago, 'Pago de ${orden.codigo} rechazado: vuelve a cobrar.', ordenId: orden.id);
    return actualizada;
  }

  Future<Orden> _verificar(Orden orden, {required bool aprobar, required Actor actor}) async {
    final error = ReglasOrden.validarVerificacion(orden, actor.rol);
    if (error != null) throw StateError(error);
    if (haySupabase) {
      return Orden.desdeMapa(await rpcMapa('verificar_pago', {'p_orden': orden.id, 'p_aprobar': aprobar}));
    }
    final ahora = DateTime.now();
    final actualizada = aprobar
        ? orden.copyWith(estadoPago: EstadosPago.pagado, pagadoEn: ahora, actualizadoEn: ahora)
        : orden.copyWith(estadoPago: EstadosPago.rechazado, actualizadoEn: ahora);
    _reemplazarLocal(actualizada);
    return actualizada;
  }

  // ------------------------------------------------------- Comprobantes

  /// Emite la boleta (B001) o factura (F001) con el correlativo siguiente
  /// (en Supabase, la función emitir_comprobante en una transacción).
  Future<Orden> emitirComprobante(
    Orden orden, {
    required String tipo,
    String documento = '',
    String razonSocial = '',
    required Actor actor,
    ConfigTaller? config,
  }) async {
    final error = ReglasOrden.validarComprobante(
      orden,
      actor.rol,
      tipo: tipo,
      documento: documento,
      razonSocial: razonSocial,
    );
    if (error != null) throw StateError(error);

    final Orden actualizada;
    if (!haySupabase) {
      final ajustes = config ?? _catalogo.catalogo.config;
      final esFactura = tipo == Comprobante.factura;
      final desglose = orden.desglose;
      final numero = esFactura ? ++_ultimaFactura : ++_ultimaBoleta;
      final comprobante = Comprobante(
        tipo: tipo,
        serie: esFactura ? ajustes.serieFactura : ajustes.serieBoleta,
        numero: numero,
        documento: documento.trim(),
        razonSocial: esFactura ? razonSocial.trim() : orden.clienteNombre,
        opGravadaCentimos: desglose.opGravada,
        igvCentimos: desglose.igvIncluido,
        totalCentimos: desglose.total,
        emitidoEn: DateTime.now(),
        // Envío a SUNAT (OSE/PSE) en modo demo: queda aceptado.
        estadoSunat: Comprobante.aceptado,
      );
      actualizada = orden.copyWith(comprobante: comprobante, actualizadoEn: comprobante.emitidoEn);
      _reemplazarLocal(actualizada);
    } else {
      actualizada = Orden.desdeMapa(await rpcMapa('emitir_comprobante', {
        'p_orden': orden.id,
        'p_tipo': tipo,
        'p_documento': documento.trim(),
        'p_razon_social': razonSocial.trim(),
      }));
    }
    final c = actualizada.comprobante!;
    await _avisos.registrar(
      TipoAviso.facturacion,
      'Comprobante ${c.codigo} emitido para ${orden.codigo} y aceptado por SUNAT.',
      ordenId: orden.id,
    );
    return actualizada;
  }
}
