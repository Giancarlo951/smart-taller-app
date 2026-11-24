import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/models/servicio.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/clientes/models/cliente.dart';
import '../modules/clientes/services/cliente_service.dart';
import '../modules/ordenes/models/linea_cotizacion.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/cotizacion_service.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_field.dart';
import '../widgets/ind_page.dart';
import '../widgets/seccion_titulo.dart';
import '../widgets/tarjeta_fila.dart';
import 'clientes_screen.dart';
import 'orden_detalle_screen.dart';
import 'selector_catalogo.dart';

/// Nueva orden de trabajo: el borrador ([CotizacionService]) más los datos
/// de recepción. Equivale al carrito + checkout de la app de referencia.
class NuevaOrdenScreen extends StatefulWidget {
  const NuevaOrdenScreen({super.key, this.placaInicial, this.motivoInicial = '', this.alCrear});

  /// Placa del vehículo (p. ej. al llegar una cita).
  final String? placaInicial;
  final String motivoInicial;
  final ValueChanged<Orden>? alCrear;

  @override
  State<NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends State<NuevaOrdenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController();
  late final _motivo = TextEditingController(text: widget.motivoInicial);
  final _promo = TextEditingController();
  (Cliente, Vehiculo)? _vehiculo;
  String _mecanico = '';
  DateTime? _entrega;
  bool _creando = false;

  CotizacionService get _cot => CotizacionService.instancia;

  @override
  void initState() {
    super.initState();
    final placa = widget.placaInicial;
    if (placa != null) {
      final dueno = ClienteService.instancia.porPlaca(placa);
      // Después del primer frame: cambiar el tipo de vehículo avisa a otros widgets.
      if (dueno != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _usarVehiculo(dueno));
        });
      }
    }
  }

  @override
  void dispose() {
    _km.dispose();
    _motivo.dispose();
    _promo.dispose();
    super.dispose();
  }

  void _usarVehiculo((Cliente, Vehiculo) elegido) {
    _vehiculo = elegido;
    _km.text = elegido.$2.km > 0 ? '${elegido.$2.km}' : '';
    _cot.cambiarTipoVehiculo(elegido.$2.tipo);
  }

  Future<void> _elegirVehiculo() async {
    final elegido = await mostrarHoja<(Cliente, Vehiculo)>(context, const _SelectorVehiculo());
    if (elegido != null && mounted) setState(() => _usarVehiculo(elegido));
  }

  Future<void> _elegirEntrega() async {
    final ahora = DateTime.now();
    final inicial = _entrega ?? CotizacionService.entregaSugerida(ahora, _cot.minutosEstimados());
    final dia = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 30)),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(inicial));
    if (hora == null) return;
    setState(() => _entrega = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute));
  }

  Future<void> _aplicarPromo() async {
    final mensajero = ScaffoldMessenger.of(context);
    final promo = await CatalogoService.instancia.buscarPromo(_promo.text);
    if (promo == null) {
      mostrarMensaje(mensajero, 'El código ${_promo.text.trim().toUpperCase()} no existe', error: true);
      return;
    }
    final error = _cot.aplicarPromo(promo);
    mostrarMensaje(mensajero, error ?? 'Código ${promo.codigo} aplicado (${promo.resumen})', error: error != null);
  }

  Future<void> _crear() async {
    final vehiculo = _vehiculo;
    if (vehiculo == null) {
      mostrarMensaje(ScaffoldMessenger.of(context), 'Seleccione el vehículo', error: true);
      return;
    }
    if (!_formKey.currentState!.validate() || _creando) return;
    setState(() => _creando = true);
    final (cliente, v) = vehiculo;
    final catalogo = CatalogoService.instancia.catalogo;
    final orden = await ejecutar(
      context,
      () => OrdenService.instancia.crearOrden(
        lineas: _cot.lineas,
        catalogo: catalogo,
        promo: _cot.promo,
        clienteId: cliente.id,
        clienteNombre: cliente.nombre,
        documentoCliente: cliente.numeroDocumento,
        telefono: cliente.telefono,
        placa: v.placa,
        vehiculo: v.descripcion,
        tipoVehiculo: _cot.tipoVehiculo,
        km: int.parse(_km.text.replaceAll(RegExp(r'[\s,.]'), '')),
        kmAnterior: v.km,
        motivo: _motivo.text,
        mecanico: _mecanico,
        entregaEstimada: _entrega ?? CotizacionService.entregaSugerida(DateTime.now(), _cot.minutosEstimados()),
        aDomicilio: _cot.aDomicilio,
        actor: AppScope.read(context).actor,
      ),
    );
    if (!mounted) return;
    setState(() => _creando = false);
    if (orden == null) return;
    // crear_orden ya vació el borrador en la base.
    _cot.vaciar(remoto: false);
    widget.alCrear?.call(orden);
    mostrarMensaje(ScaffoldMessenger.of(context), 'Orden ${orden.codigo} registrada');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrdenDetalleScreen(ordenId: orden.id)),
    );
  }

  void _eliminar(LineaCotizacion linea) {
    final eliminado = _cot.eliminar(linea.id);
    if (eliminado == null) return;
    mostrarDeshacer(
      ScaffoldMessenger.of(context),
      '${linea.nombre} quitado de la orden',
      () => _cot.restaurar(eliminado.$1, eliminado.$2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mecanicos = CatalogoService.instancia.catalogo.config.mecanicos;
    return ListenableBuilder(
      listenable: Listenable.merge([_cot, CatalogoService.instancia]),
      builder: (context, _) {
        final config = CatalogoService.instancia.catalogo.config;
        final desglose = _cot.desglose(config);
        final sugerida = CotizacionService.entregaSugerida(DateTime.now(), _cot.minutosEstimados());
        final vehiculo = _vehiculo;
        return Form(
          key: _formKey,
          child: IndPage(
            kicker: 'Recepción del vehículo',
            titulo: 'Nueva orden de trabajo',
            gap: 16,
            pie: PrimaryButton(
              label: _creando ? 'Registrando…' : 'Crear orden · ${formatoCentimos(desglose.total)}',
              onPressed: _creando ? null : _crear,
            ),
            children: [
              // — Vehículo —
              vehiculo == null
                  ? TarjetaFila(
                      onTap: _elegirVehiculo,
                      semanticLabel: 'Elegir vehículo',
                      icono: Icons.directions_car_filled_rounded,
                      titulo: 'Elegir vehículo',
                      subtitulo: 'Busca por placa, cliente o DNI/RUC',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Ind.n400),
                    )
                  : TarjetaFila(
                      onTap: _elegirVehiculo,
                      semanticLabel: 'Cambiar vehículo ${vehiculo.$2.placa}',
                      icono: iconoVehiculo(vehiculo.$2.tipo),
                      titulo: vehiculo.$2.placa,
                      subtitulo: vehiculo.$2.descripcion,
                      trailing: Text('Cambiar', style: Ind.heading(13, color: Ind.accent)),
                      debajo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        DatoIcono(Icons.person_outline_rounded,
                            '${vehiculo.$1.nombre} · ${vehiculo.$1.documento} · ${vehiculo.$1.telefono}'),
                        DatoIcono(Icons.speed_rounded,
                            'Último km: ${formatoKm(vehiculo.$2.km)} · último servicio: ${vehiculo.$2.ultimoServicioTexto}'),
                      ]),
                    ),
              IndField(
                label: 'Tipo de vehículo (define el precio)',
                child: Segmentos<String>(
                  opciones: [
                    for (final tipo in TiposVehiculo.claves) (tipo, TiposVehiculo.etiqueta(tipo).split(' / ').first),
                  ],
                  valor: _cot.tipoVehiculo,
                  alCambiar: _cot.cambiarTipoVehiculo,
                ),
              ),
              CampoTexto(
                label: 'Kilometraje de ingreso',
                controller: _km,
                soloDigitos: true,
                validator: (v) => Validadores.kilometraje(v, anterior: vehiculo?.$2.km),
              ),
              CampoTexto(label: 'Motivo de ingreso', controller: _motivo, lineas: 2, ayuda: 'Ej. ruido al frenar'),
              if (mecanicos.isNotEmpty)
                IndField(
                  label: 'Mecánico',
                  child: Wrap(spacing: 8, runSpacing: 0, children: [
                    for (final m in mecanicos)
                      TagChip(label: m, selected: _mecanico == m, onTap: () => setState(() => _mecanico = _mecanico == m ? '' : m)),
                  ]),
                ),
              TarjetaFila(
                onTap: _elegirEntrega,
                semanticLabel: 'Entrega estimada',
                icono: Icons.event_rounded,
                titulo: formatoFechaHora(_entrega ?? sugerida),
                subtitulo: _entrega == null ? 'Entrega sugerida (tiempo de bahía)' : 'Entrega estimada',
                trailing: const Icon(Icons.edit_calendar_rounded, color: Ind.n400, size: 20),
              ),

              // — Servicios y repuestos —
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SeccionTitulo(
                    'Servicios y repuestos (${_cot.cantidadItems})',
                    accion: _cot.estaVacia ? null : 'Vaciar',
                    onAccion: () => _cot.vaciar(),
                  ),
                  for (final linea in _cot.lineas) ...[
                    Dismissible(
                      key: ValueKey(linea.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _eliminar(linea),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 18),
                        decoration: BoxDecoration(
                          color: Ind.peligroFondo,
                          borderRadius: BorderRadius.circular(Ind.radiusLg),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.delete_outline_rounded, color: Ind.peligro, size: 20),
                          const SizedBox(width: 6),
                          Text('Quitar', style: Ind.heading(13, color: Ind.peligro)),
                        ]),
                      ),
                      child: _LineaBorrador(linea: linea),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SecondaryButton(
                    label: 'Agregar servicio o repuesto',
                    onPressed: () => abrirSelectorCatalogo(
                      context,
                      tipoVehiculo: _cot.tipoVehiculo,
                      alAgregarServicio: (s, adicionales, cantidad) =>
                          _cot.agregarServicio(servicio: s, adicionales: adicionales, cantidad: cantidad),
                      alAgregarRepuesto: (r, cantidad) => _cot.agregarRepuesto(repuesto: r, cantidad: cantidad),
                    ),
                  ),
                ],
              ),

              // — Promoción, domicilio y total —
              if (_cot.promo == null)
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: CampoTexto(label: 'Código promocional', controller: _promo, mayusculas: true)),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton(onPressed: _aplicarPromo, child: const Text('Aplicar')),
                  ),
                ])
              else
                TarjetaFila(
                  icono: Icons.local_offer_rounded,
                  colorIcono: Ind.exito,
                  fondoIcono: Ind.exitoFondo,
                  titulo: _cot.promo!.codigo,
                  subtitulo: _cot.promo!.resumen,
                  trailing: TextButton(onPressed: _cot.quitarPromo, child: const Text('Quitar')),
                ),
              BlueprintBox(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SwitchListTile(
                  value: _cot.aDomicilio,
                  onChanged: (v) => _cot.aDomicilio = v,
                  contentPadding: EdgeInsets.zero,
                  secondary: const IconoMosaico(Icons.home_rounded, tamano: 40),
                  title: Text('Servicio a domicilio / recojo', style: Ind.heading(14, height: 1.3)),
                  subtitle: Text('+${formatoCentimos(config.recargoDomicilioCentimos)}', style: Ind.meta),
                ),
              ),
              BlueprintBox(
                child: Column(children: [
                  FilaMonto('Subtotal', formatoCentimos(desglose.subtotal)),
                  if (desglose.descuento > 0) FilaMonto('Descuento ${_cot.promo?.codigo ?? ''}', '-${formatoCentimos(desglose.descuento)}'),
                  if (desglose.recargo > 0) FilaMonto('Servicio a domicilio', formatoCentimos(desglose.recargo)),
                  FilaMonto('Total', formatoCentimos(desglose.total), resaltar: true),
                  FilaMonto('IGV 18 % (incluido)', formatoCentimos(desglose.igvIncluido)),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LineaBorrador extends StatelessWidget {
  const _LineaBorrador({required this.linea});

  final LineaCotizacion linea;

  @override
  Widget build(BuildContext context) {
    final cot = CotizacionService.instancia;
    final catalogo = CatalogoService.instancia.catalogo;
    final adicionales = linea.adicionalIds.map((id) => catalogo.adicional(id)?.nombre).whereType<String>();
    final maximo = linea.esRepuesto ? (catalogo.repuesto(linea.refId)?.stock ?? linea.cantidad) : CotizacionService.maximoServicio;
    final repuesto = linea.esRepuesto ? catalogo.repuesto(linea.refId) : null;
    final servicio = linea.esRepuesto ? null : catalogo.servicios.where((s) => s.id == linea.refId).firstOrNull;
    return TarjetaFila(
      icono: repuesto != null
          ? iconoRepuesto(repuesto)
          : servicio != null
              ? iconoServicio(servicio)
              : Icons.build_rounded,
      titulo: linea.nombre,
      subtitulo: [linea.etiquetaVariante, if (adicionales.isNotEmpty) '+ ${adicionales.join(', ')}'].join(' · '),
      pie: Text(formatoCentimos(linea.totalLineaCentimos), style: Ind.heading(15, color: Ind.accent)),
      trailing: SelectorCantidad(
        valor: linea.cantidad,
        maximo: maximo,
        alCambiar: (v) => cot.cambiarCantidad(linea.id, v - linea.cantidad),
      ),
    );
  }
}

/// Lista de vehículos registrados (con búsqueda) para elegir el de la orden.
class _SelectorVehiculo extends StatefulWidget {
  const _SelectorVehiculo();

  @override
  State<_SelectorVehiculo> createState() => _SelectorVehiculoState();
}

class _SelectorVehiculoState extends State<_SelectorVehiculo> {
  final _busqueda = TextEditingController();
  late final Stream<List<Cliente>> _clientes = ClienteService.instancia.listar();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: StreamBuilder<List<Cliente>>(
        stream: _clientes,
        builder: (context, snapshot) {
          final clientes = ClienteService.buscar(snapshot.data ?? const [], _busqueda.text);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text('Recepción', style: Ind.kicker()),
              Text('Elegir vehículo', style: Ind.heading(21, height: 1.2)),
              const SizedBox(height: 12),
              TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Placa, cliente o DNI/RUC', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Registrar cliente nuevo',
                onPressed: () => abrirFormularioCliente(context),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const LinearProgressIndicator()
              else if (clientes.isEmpty)
                const EstadoVacio(titulo: 'Sin resultados', ayuda: 'Registra al cliente y su vehículo')
              else
                for (final c in clientes)
                  for (final v in c.vehiculos) ...[
                    TarjetaFila(
                      onTap: () => Navigator.pop(context, (c, v)),
                      semanticLabel: '${v.placa}, ${c.nombre}',
                      icono: iconoVehiculo(v.tipo),
                      titulo: '${v.placa} · ${v.descripcion}',
                      subtitulo: '${c.nombre} · ${TiposVehiculo.etiqueta(v.tipo)}',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Ind.n400),
                    ),
                    const SizedBox(height: 10),
                  ],
            ],
          );
        },
      ),
    );
  }
}
