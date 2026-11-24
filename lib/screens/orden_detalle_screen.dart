import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/models/linea_cotizacion.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/cotizacion_service.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../modules/ordenes/services/pago_service.dart';
import '../modules/ordenes/services/reglas_orden.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/avance_timeline.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_field.dart';
import '../widgets/ind_page.dart';
import '../widgets/orden_card.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_fila.dart';
import 'nueva_orden_screen.dart';
import 'selector_catalogo.dart';

/// Detalle y seguimiento en tiempo real de una orden de trabajo.
class OrdenDetalleScreen extends StatefulWidget {
  const OrdenDetalleScreen({super.key, required this.ordenId});

  final String ordenId;

  @override
  State<OrdenDetalleScreen> createState() => _OrdenDetalleScreenState();
}

class _OrdenDetalleScreenState extends State<OrdenDetalleScreen> {
  late final Stream<Orden?> _orden = OrdenService.instancia.escuchar(widget.ordenId);
  bool _ocupado = false;

  OrdenService get _ordenes => OrdenService.instancia;

  Future<void> _accion(Future<Object?> Function() accion, {String? exito}) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    await ejecutar(context, accion, exito: exito);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _avanzar(Orden o) async {
    final app = AppScope.read(context);
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    final (resultado, error) = await app.avanzar(o);
    if (!mounted) return;
    setState(() => _ocupado = false);
    switch (resultado) {
      case ResultadoAvance.avanzada:
        mostrarMensaje(mensajero, '${o.codigo}: ${o.estado.siguienteEtapa?.titulo ?? 'avance registrado'}');
      case ResultadoAvance.yaCompletada:
        mostrarMensaje(mensajero, 'La orden ya está lista para entrega');
      case ResultadoAvance.sinPermiso || ResultadoAvance.error:
        mostrarMensaje(mensajero, error ?? 'No se pudo registrar el avance', error: true);
    }
  }

  Future<void> _agregar(Orden o) => abrirSelectorCatalogo(
    context,
    tipoVehiculo: o.tipoVehiculo,
    alAgregarServicio: (s, adicionales, cantidad) {
      final nueva = LineaCotizacion(
        id: LineaCotizacion.generarId(LineaCotizacion.tipoServicio, s.id,
            variante: o.tipoVehiculo, adicionales: adicionales.map((a) => a.id).toList()),
        tipo: LineaCotizacion.tipoServicio,
        refId: s.id,
        nombre: s.nombre,
        variante: o.tipoVehiculo,
        adicionalIds: adicionales.map((a) => a.id).toList(),
        precioUnitarioCentimos: 0,
        cantidad: cantidad,
        agregadoEn: DateTime.now(),
      );
      _guardarLineas(o, [..._lineas(o), nueva]);
    },
    alAgregarRepuesto: (r, cantidad) {
      final nueva = LineaCotizacion(
        id: LineaCotizacion.generarId(LineaCotizacion.tipoRepuesto, r.codigo),
        tipo: LineaCotizacion.tipoRepuesto,
        refId: r.codigo,
        nombre: r.nombre,
        precioUnitarioCentimos: r.precioCentimos,
        cantidad: cantidad,
        agregadoEn: DateTime.now(),
      );
      _guardarLineas(o, [..._lineas(o), nueva]);
    },
  );

  List<LineaCotizacion> _lineas(Orden o) => [for (final l in o.lineas) l.aLineaCotizacion()];

  void _guardarLineas(Orden o, List<LineaCotizacion> lineas) => _accion(
    () => _ordenes.actualizarLineas(o, lineas, actor: AppScope.read(context).actor),
    exito: 'Orden ${o.codigo} actualizada',
  );

  Future<void> _quitarLinea(Orden o, int indice) async {
    final linea = o.lineas[indice];
    final ok = await confirmar(context,
        titulo: 'Quitar ${linea.nombre}', mensaje: 'Se recalcula el total de la orden.', accion: 'Quitar');
    if (!ok || !mounted) return;
    final lineas = _lineas(o)..removeAt(indice);
    _guardarLineas(o, lineas);
  }

  Future<void> _anular(Orden o) async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Anular ${o.codigo}',
      etiqueta: 'Motivo',
      accion: 'Anular',
      validator: (v) => (v == null || v.trim().length < 5) ? 'Escribe el motivo' : null,
    );
    if (motivo == null || !mounted) return;
    _accion(
      () => _ordenes.anular(o, actor: AppScope.read(context).actor, motivo: motivo),
      exito: '${o.codigo} anulada${o.stockDescontado ? ': repuestos devueltos al almacén' : ''}',
    );
  }

  void _repetir(Orden o) {
    final lineas = CotizacionService.lineasParaRepetir(o, CatalogoService.instancia.catalogo);
    final unidades = CotizacionService.instancia.repetir(lineas, tipoVehiculo: o.tipoVehiculo);
    final faltan = lineas.where((l) => !l.disponible).length;
    mostrarMensaje(
      ScaffoldMessenger.of(context),
      '${plural(unidades, 'ítem agregado', 'ítems agregados')} con precios de hoy'
      '${faltan > 0 ? ' · ${plural(faltan, 'ya no está', 'ya no están')} en el catálogo' : ''}',
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NuevaOrdenScreen(placaInicial: o.placa, motivoInicial: o.motivo),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rol = app.rol;
    return StreamBuilder<Orden?>(
      stream: _orden,
      builder: (context, snapshot) {
        final o = snapshot.data;
        if (o == null) {
          return IndPage(kicker: 'Orden de trabajo', titulo: 'Cargando…', children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else
              const EstadoVacio(titulo: 'No encontramos esta orden', ayuda: 'Puede que haya sido eliminada.'),
          ]);
        }
        final d = o.desglose;
        final editable = ReglasOrden.validarEdicionLineas(o) == null;
        final siguiente = o.estado.siguienteEtapa;
        return IndPage(
          kicker: '${o.codigo} · ${o.estado.etiqueta}',
          titulo: 'Orden de trabajo',
          gap: 16,
          children: [
            BlueprintBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconoMosaico(iconoVehiculo(o.tipoVehiculo), tamano: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.placa, style: Ind.heading(22, height: 1.15)),
                        Text(o.vehiculo, style: Ind.body(13, color: Ind.muted, height: 1.3)),
                      ]),
                    ),
                    EstadoTag(o.estado.etiqueta, variant: tagDeEstado(o.estado)),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  DatoIcono(Icons.person_outline_rounded, '${o.clienteNombre} · ${o.telefono}'),
                  DatoIcono(Icons.speed_rounded, formatoKm(o.km)),
                  DatoIcono(Icons.engineering_outlined, o.mecanico.isEmpty ? 'Sin mecánico asignado' : o.mecanico),
                  DatoIcono(
                    Icons.schedule_rounded,
                    'Entrega ${o.entregaTexto()}${o.atrasada() ? ' (atrasada)' : ''}',
                    color: o.atrasada() ? Ind.peligro : null,
                  ),
                  if (o.motivo.isNotEmpty) DatoIcono(Icons.notes_rounded, 'Motivo: ${o.motivo}'),
                  if (o.aDomicilio) const DatoIcono(Icons.home_outlined, 'Servicio a domicilio'),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SeccionTitulo('Avance'),
              BlueprintBox(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AvanceTimeline(orden: o),
                  if (o.estado == EstadoOrden.entregado || o.estado == EstadoOrden.cancelado) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${o.estado.titulo} · ${formatoFechaHora(o.actualizadoEn)}'
                      '${o.historial.isNotEmpty && o.historial.last.nota.isNotEmpty ? ' · ${o.historial.last.nota}' : ''}',
                      style: Ind.meta,
                    ),
                  ],
                ]),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SeccionTitulo('Servicios y repuestos',
                  accion: editable ? 'Agregar' : null, onAccion: editable ? () => _agregar(o) : null),
              BlueprintBox(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (o.lineas.isEmpty)
                    Text('Sin servicios todavía. Agrégalos después del diagnóstico.', style: Ind.body(13, color: Ind.muted)),
                  for (final (i, l) in o.lineas.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        IconoMosaico(l.esServicio ? Icons.build_rounded : Icons.settings_rounded, tamano: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.nombre, style: Ind.heading(14, height: 1.3)),
                            Text(l.detalle, style: Ind.meta),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text(formatoCentimos(l.totalLineaCentimos), style: Ind.heading(14, height: 1.3)),
                        if (editable)
                          IconButton(
                            onPressed: () => _quitarLinea(o, i),
                            tooltip: 'Quitar ${l.nombre}',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18, color: Ind.n500),
                          ),
                      ]),
                    ),
                  const Divider(),
                  const SizedBox(height: 8),
                  FilaMonto('Subtotal', formatoCentimos(d.subtotal)),
                  if (d.descuento > 0) FilaMonto('Descuento ${o.codigoPromo ?? ''}', '-${formatoCentimos(d.descuento)}'),
                  if (d.recargo > 0) FilaMonto('Servicio a domicilio', formatoCentimos(d.recargo)),
                  FilaMonto('IGV 18 % (incluido)', formatoCentimos(d.igvIncluido)),
                  const SizedBox(height: 4),
                  FilaMonto('Total', formatoCentimos(d.total), resaltar: true),
                ]),
              ),
            ]),
            TarjetaFila(
              icono: o.etiquetaMetodo == null ? Icons.payments_outlined : iconoMetodoPago(o.metodoPago ?? ''),
              colorIcono: o.estaPagada ? Ind.exito : Ind.accent,
              fondoIcono: o.estaPagada ? Ind.exitoFondo : Ind.a100,
              titulo: 'Cobro',
              subtitulo: [
                if (o.etiquetaMetodo != null)
                  '${o.etiquetaMetodo}${o.referenciaPago == null ? '' : ' · Op. ${o.referenciaPago}'}'
                      '${o.pagadoEn == null ? '' : ' · ${formatoFechaHora(o.pagadoEn!)}'}',
                if (o.comprobante != null) '${o.comprobante!.etiquetaTipo} ${o.comprobante!.codigo} · SUNAT: aceptado',
              ].join('\n'),
              trailing: EstadoTag(o.etiquetaPago, variant: o.estaPagada ? TagVariant.exito : TagVariant.neutral),
            ),

            // — Acciones según etapa y rol —
            if (siguiente != null)
              PrimaryButton(
                label: 'Registrar avance: ${siguiente.titulo.toLowerCase()}',
                onPressed: _ocupado ? null : () => _avanzar(o),
              ),
            if (o.estado == EstadoOrden.listo && !o.estaPagada && !o.pagoPorVerificar && Permisos.puedeCobrar(rol))
              PrimaryButton(
                label: 'Cobrar ${formatoCentimos(o.totalCentimos)}',
                onPressed: () => mostrarHoja<void>(context, _HojaCobro(orden: o)),
              ),
            if (o.pagoPorVerificar && Permisos.puedeAprobarPago(rol)) ...[
              PrimaryButton(
                label: 'Aprobar pago (op. ${o.referenciaPago})',
                onPressed: _ocupado ? null : () => _accion(() => _ordenes.aprobarPago(o, actor: app.actor), exito: 'Pago aprobado'),
              ),
              SecondaryButton(
                label: 'Rechazar pago',
                onPressed: _ocupado ? null : () => _accion(() => _ordenes.rechazarPago(o, actor: app.actor), exito: 'Pago rechazado'),
              ),
            ],
            if (o.estaPagada && !o.tieneComprobante && Permisos.puedeFacturar(rol))
              PrimaryButton(
                label: 'Generar comprobante',
                onPressed: () => mostrarHoja<void>(context, HojaComprobante(orden: o)),
              ),
            if (o.estado == EstadoOrden.listo && o.estaPagada && Permisos.puedeEntregarVehiculo(rol))
              SecondaryButton(
                label: 'Entregar vehículo',
                onPressed: _ocupado ? null : () => _accion(() => _ordenes.entregar(o, actor: app.actor), exito: '${o.codigo} entregada'),
              ),
            if (o.estado == EstadoOrden.entregado)
              SecondaryButton(label: 'Repetir servicio', onPressed: () => _repetir(o)),
            if (o.estado.activa && Permisos.puedeAnularOrden(rol) && !o.estaPagada)
              TextButton(onPressed: _ocupado ? null : () => _anular(o), child: const Text('Anular orden')),
          ],
        );
      },
    );
  }
}

/// Cobro: Efectivo, Yape, Plin o Tarjeta (Mercado Pago o modo demo).
class _HojaCobro extends StatefulWidget {
  const _HojaCobro({required this.orden});

  final Orden orden;

  @override
  State<_HojaCobro> createState() => _HojaCobroState();
}

class _HojaCobroState extends State<_HojaCobro> {
  final _formKey = GlobalKey<FormState>();
  final _operacion = TextEditingController();
  String _metodo = MetodosPago.efectivo;
  bool _cobrando = false;

  @override
  void dispose() {
    _operacion.dispose();
    super.dispose();
  }

  Future<void> _cobrar() async {
    if (_cobrando || !_formKey.currentState!.validate()) return;
    setState(() => _cobrando = true);
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    try {
      final actualizada = await OrdenService.instancia.registrarCobro(
        widget.orden,
        metodo: _metodo,
        referencia: _operacion.text,
        actor: AppScope.read(context).actor,
      );
      navegador.pop();
      mostrarMensaje(
        mensajero,
        actualizada.pagoPorVerificar
            ? 'Pago registrado: administración debe verificar el N.° de operación'
            : 'Cobro registrado: ${formatoCentimos(actualizada.totalCentimos)}',
      );
    } catch (e) {
      mostrarMensaje(mensajero, mensajeError(e), error: true);
      if (mounted) setState(() => _cobrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = CatalogoService.instancia.catalogo.config;
    final o = widget.orden;
    final billetera = MetodosPago.esBilletera(_metodo);
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: o.codigo,
        titulo: 'Cobrar ${formatoCentimos(o.totalCentimos)}',
        children: [
          // Métodos en mosaicos 2×2: ícono + nombre; el elegido con borde azul.
          for (var i = 0; i < MetodosPago.todos.length; i += 2)
            Row(children: [
              for (final m in MetodosPago.todos.skip(i).take(2)) ...[
                if (m != MetodosPago.todos[i]) const SizedBox(width: 10),
                Expanded(
                  child: BlueprintBox(
                    onTap: () => setState(() => _metodo = m),
                    semanticLabel: MetodosPago.etiquetas[m],
                    color: _metodo == m ? Ind.a100 : null,
                    borderColor: _metodo == m ? Ind.accent : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(iconoMetodoPago(m), color: _metodo == m ? Ind.accent : Ind.n500, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          MetodosPago.etiquetas[m]!,
                          style: Ind.heading(14, color: _metodo == m ? Ind.a800 : Ind.n800),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          if (billetera) ...[
            Text(
              'El cliente paga al ${MetodosPago.etiquetas[_metodo]} del taller: '
              '${_metodo == MetodosPago.yape ? config.numeroYape : config.numeroPlin}. Luego ingresa el N.° de operación; '
              'administración lo verifica.',
              style: Ind.body(13, color: Ind.muted),
            ),
            CampoTexto(label: 'N.° de operación', controller: _operacion, soloDigitos: true, validator: Validadores.numeroOperacion),
          ],
          if (_metodo == MetodosPago.tarjeta)
            Text(
              PagoTarjeta.cobraConMercadoPago
                  ? 'Se abrirá Mercado Pago para cobrar con tarjeta.'
                  : 'Modo demo: no se realiza ningún cobro real.',
              style: Ind.body(13, color: Ind.muted),
            ),
          FilaMonto('Total a cobrar', formatoCentimos(o.totalCentimos), resaltar: true),
          PrimaryButton(label: _cobrando ? 'Registrando…' : 'Registrar cobro', onPressed: _cobrando ? null : _cobrar),
        ],
      ),
    );
  }
}

/// Emitir boleta o factura electrónica (IGV 18 %).
class HojaComprobante extends StatefulWidget {
  const HojaComprobante({super.key, required this.orden});

  final Orden orden;

  @override
  State<HojaComprobante> createState() => _HojaComprobanteState();
}

class _HojaComprobanteState extends State<HojaComprobante> {
  final _formKey = GlobalKey<FormState>();
  late final _documento = TextEditingController(text: widget.orden.documentoCliente);
  late final _razon = TextEditingController(text: widget.orden.documentoCliente.length == 11 ? widget.orden.clienteNombre : '');
  late String _tipo = widget.orden.documentoCliente.length == 11 ? Comprobante.factura : Comprobante.boleta;
  bool _emitiendo = false;

  @override
  void dispose() {
    _documento.dispose();
    _razon.dispose();
    super.dispose();
  }

  Future<void> _emitir() async {
    if (_emitiendo || !_formKey.currentState!.validate()) return;
    setState(() => _emitiendo = true);
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    try {
      final o = await OrdenService.instancia.emitirComprobante(
        widget.orden,
        tipo: _tipo,
        documento: _documento.text,
        razonSocial: _razon.text,
        actor: AppScope.read(context).actor,
      );
      navegador.pop();
      mostrarMensaje(mensajero, 'Comprobante ${o.comprobante!.codigo} emitido y enviado');
    } catch (e) {
      mostrarMensaje(mensajero, mensajeError(e), error: true);
      if (mounted) setState(() => _emitiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.orden;
    final d = o.desglose;
    final config = CatalogoService.instancia.catalogo.config;
    final factura = _tipo == Comprobante.factura;
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: 'Serie ${factura ? config.serieFactura : config.serieBoleta}',
        titulo: factura ? 'Factura electrónica' : 'Boleta electrónica',
        children: [
          Segmentos<String>(
            opciones: const [(Comprobante.boleta, 'Boleta'), (Comprobante.factura, 'Factura')],
            valor: _tipo,
            alCambiar: (t) => setState(() => _tipo = t),
          ),
          CampoTexto(
            label: factura ? 'RUC del cliente' : 'DNI del cliente (opcional hasta S/ 700)',
            controller: _documento,
            soloDigitos: true,
            validator: (v) => ReglasOrden.validarComprobante(
              o,
              AppScope.read(context).rol,
              tipo: _tipo,
              documento: v ?? '',
              razonSocial: factura ? _razon.text : '',
            ),
          ),
          if (factura)
            IndField(
              label: 'Razón social',
              child: TextFormField(
                controller: _razon,
                validator: (v) => (v == null || v.trim().length < 3) ? 'Ingrese la razón social' : null,
              ),
            ),
          FilaMonto('Op. gravada', formatoCentimos(d.opGravada)),
          FilaMonto('IGV 18 %', formatoCentimos(d.igvIncluido)),
          FilaMonto('Total', formatoCentimos(d.total), resaltar: true),
          Text('Se envía a SUNAT al emitir (modo demo: queda aceptado).', style: Ind.meta),
          PrimaryButton(label: _emitiendo ? 'Emitiendo…' : 'Emitir y enviar', onPressed: _emitiendo ? null : _emitir),
        ],
      ),
    );
  }
}
