import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/models/servicio.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/catalogo/services/recomendaciones.dart';
import '../modules/clientes/models/cliente.dart';
import '../modules/clientes/services/cliente_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_field.dart';
import '../widgets/ind_page.dart';
import '../widgets/orden_card.dart';
import '../widgets/tarjeta_fila.dart';
import 'orden_detalle_screen.dart';

/// Alta o edición de un cliente. Devuelve su id.
Future<String?> abrirFormularioCliente(BuildContext context, {Cliente? cliente}) =>
    mostrarHoja<String>(context, _FormularioCliente(cliente: cliente));

/// Clientes y vehículos (Módulos 01 · 02).
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  late final Stream<List<Cliente>> _clientes = ClienteService.instancia.listar();
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientes,
      builder: (context, snapshot) {
        final lista = ClienteService.buscar(snapshot.data ?? const [], _busqueda.text);
        return IndPage(
          kicker: 'Registro e historial',
          titulo: 'Clientes y vehículos',
          gap: 12,
          children: [
            PrimaryButton(label: 'Registrar cliente', onPressed: () => abrirFormularioCliente(context)),
            TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              style: Ind.body(14, height: 1.3),
              decoration: const InputDecoration(hintText: 'Buscar nombre, DNI/RUC o placa', prefixIcon: Icon(Icons.search_rounded)),
            ),
            if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (lista.isEmpty)
              const EstadoVacio(titulo: 'Sin resultados')
            else
              for (final c in lista)
                TarjetaFila(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClienteDetalleScreen(clienteId: c.id))),
                  semanticLabel: c.nombre,
                  inicio: AvatarIniciales(c.nombre, color: Ind.colorClientes),
                  titulo: c.nombre,
                  subtitulo: '${c.documento} · ${c.telefono} · ${plural(c.servicios, 'servicio', 'servicios')}',
                  trailing: EstadoTag(c.esEmpresa ? 'Empresa' : 'Persona', variant: c.esEmpresa ? TagVariant.accent : TagVariant.neutral),
                  debajo: c.vehiculos.isEmpty
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Ind.bg, borderRadius: BorderRadius.circular(Ind.radiusMd)),
                          child: Column(children: [
                            for (final v in c.vehiculos)
                              DatoIcono(iconoVehiculo(v.tipo), '${v.placa} · ${v.descripcion} · último servicio ${v.ultimoServicioTexto}'),
                          ]),
                        ),
                ),
          ],
        );
      },
    );
  }
}

/// Datos del cliente, sus vehículos y el historial de cada uno.
class ClienteDetalleScreen extends StatefulWidget {
  const ClienteDetalleScreen({super.key, required this.clienteId});

  final String clienteId;

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  late final Stream<List<Cliente>> _clientes = ClienteService.instancia.listar();

  Future<void> _eliminar(Cliente c) async {
    final ok = await confirmar(context, titulo: 'Eliminar cliente', mensaje: '${c.nombre} y sus vehículos', accion: 'Eliminar');
    if (!ok || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final eliminado = await ejecutar(context, () => ClienteService.instancia.eliminarCliente(c.id));
    if (eliminado == null) return;
    navegador.pop();
    mostrarDeshacer(mensajero, '${c.nombre} eliminado', () => ClienteService.instancia.restaurarCliente(eliminado));
  }

  @override
  Widget build(BuildContext context) {
    final rol = AppScope.of(context).rol;
    return StreamBuilder<List<Cliente>>(
      stream: _clientes,
      builder: (context, snapshot) {
        final c = (snapshot.data ?? const <Cliente>[]).where((c) => c.id == widget.clienteId).firstOrNull;
        if (c == null) {
          return IndPage(kicker: 'Cliente', titulo: 'Cliente', children: [
            snapshot.hasData ? const EstadoVacio(titulo: 'El cliente ya no existe') : const LinearProgressIndicator(),
          ]);
        }
        return IndPage(
          kicker: c.documento,
          titulo: c.nombre,
          gap: 14,
          children: [
            BlueprintBox(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AvatarIniciales(c.nombre, tamano: 56, color: Ind.colorClientes),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.nombre, style: Ind.heading(17, height: 1.25)),
                      Text(c.documento, style: Ind.body(13, color: Ind.muted, height: 1.3)),
                    ]),
                  ),
                  EstadoTag(c.esEmpresa ? 'Empresa' : 'Persona', variant: c.esEmpresa ? TagVariant.accent : TagVariant.neutral),
                ]),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                DatoIcono(Icons.phone_rounded, c.telefono),
                if (c.correo.isNotEmpty) DatoIcono(Icons.mail_outline_rounded, c.correo),
                DatoIcono(Icons.history_rounded,
                    '${plural(c.servicios, 'servicio', 'servicios')} · cliente desde ${formatoFecha(c.creadoEn)}'),
              ]),
            ),
            Row(children: [
              Expanded(
                child: SecondaryButton(label: 'Editar datos', onPressed: () => abrirFormularioCliente(context, cliente: c)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Agregar vehículo',
                  onPressed: () => mostrarHoja<void>(context, _FormularioVehiculo(clienteId: c.id)),
                ),
              ),
            ]),
            for (final v in c.vehiculos) _VehiculoHistorial(cliente: c, vehiculo: v),
            if (Permisos.puedeEliminarClientes(rol))
              TextButton(onPressed: () => _eliminar(c), child: const Text('Eliminar cliente')),
          ],
        );
      },
    );
  }
}

class _VehiculoHistorial extends StatefulWidget {
  const _VehiculoHistorial({required this.cliente, required this.vehiculo});

  final Cliente cliente;
  final Vehiculo vehiculo;

  @override
  State<_VehiculoHistorial> createState() => _VehiculoHistorialState();
}

class _VehiculoHistorialState extends State<_VehiculoHistorial> {
  late final Stream<List<Orden>> _historial = OrdenService.instancia.deVehiculo(widget.vehiculo.placa);

  @override
  Widget build(BuildContext context) {
    final v = widget.vehiculo;
    return StreamBuilder<List<Orden>>(
      stream: _historial,
      builder: (context, snapshot) {
        final ordenes = snapshot.data ?? const <Orden>[];
        // Último km en que se hizo cada servicio (para el mantenimiento pendiente).
        final ultimoKm = <String, int>{};
        for (final o in ordenes.where((o) => o.estado != EstadoOrden.cancelado)) {
          for (final l in o.lineas.where((l) => l.esServicio)) {
            if (o.km > (ultimoKm[l.refId] ?? -1)) ultimoKm[l.refId] = o.km;
          }
        }
        final pendientes = Recomendaciones.mantenimientoPendiente(
          CatalogoService.instancia.catalogo.servicios,
          kmActual: v.km,
          ultimoKmPorServicio: ultimoKm,
        );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TarjetaFila(
            onTap: () => mostrarHoja<void>(context, _FormularioVehiculo(clienteId: widget.cliente.id, vehiculo: v)),
            semanticLabel: 'Editar ${v.placa}',
            icono: iconoVehiculo(v.tipo),
            colorIcono: Ind.colorClientes,
            titulo: '${v.placa} · ${v.descripcion}',
            subtitulo: '${TiposVehiculo.etiqueta(v.tipo)} · ${formatoKm(v.km)} · último servicio ${v.ultimoServicioTexto}',
            trailing: const Icon(Icons.edit_outlined, size: 20, color: Ind.n400),
            debajo: pendientes.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Ind.a100, borderRadius: BorderRadius.circular(Ind.radiusMd)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.build_circle_outlined, size: 18, color: Ind.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Mantenimiento pendiente: ${pendientes.map((s) => s.nombre).join(', ')}',
                            style: Ind.body(12.5, color: Ind.a800, height: 1.4)),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: 8),
          for (final o in ordenes) ...[
            OrdenCard(orden: o, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdenDetalleScreen(ordenId: o.id)))),
            const SizedBox(height: 8),
          ],
        ]);
      },
    );
  }
}

class _FormularioCliente extends StatefulWidget {
  const _FormularioCliente({this.cliente});

  final Cliente? cliente;

  @override
  State<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends State<_FormularioCliente> {
  final _formKey = GlobalKey<FormState>();
  late final c = widget.cliente;
  late final _nombre = TextEditingController(text: c?.nombre ?? '');
  late final _documento = TextEditingController(text: c?.numeroDocumento ?? '');
  late final _telefono = TextEditingController(text: c?.telefono ?? '');
  late final _correo = TextEditingController(text: c?.correo ?? '');
  late String _tipo = c?.tipoDocumento ?? Cliente.dni;
  // Primer vehículo (solo al registrar un cliente nuevo).
  final _placa = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  String _tipoVehiculo = TiposVehiculo.auto;

  @override
  void dispose() {
    for (final t in [_nombre, _documento, _telefono, _correo, _placa, _marca, _modelo, _anio]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final navegador = Navigator.of(context);
    final nuevo = c == null;
    final cliente = (c ?? Cliente(nombre: '', tipoDocumento: _tipo, numeroDocumento: '', telefono: '', creadoEn: DateTime.now())).copyWith(
      nombre: _nombre.text,
      tipoDocumento: _tipo,
      numeroDocumento: _documento.text,
      telefono: _telefono.text,
      correo: _correo.text.trim(),
      vehiculos: nuevo
          ? [
              Vehiculo(
                placa: normalizarPlaca(_placa.text),
                marca: _marca.text.trim(),
                modelo: _modelo.text.trim(),
                anio: int.parse(_anio.text),
                tipo: _tipoVehiculo,
              ),
            ]
          : null,
    );
    final id = await ejecutar(context, () => ClienteService.instancia.guardar(cliente),
        exito: nuevo ? 'Cliente registrado' : 'Datos actualizados');
    if (id != null) navegador.pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final ruc = _tipo == Cliente.ruc;
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: 'Ley N° 29733 · datos personales',
        titulo: c == null ? 'Registrar cliente' : 'Editar cliente',
        children: [
          Segmentos<String>(
            opciones: const [(Cliente.dni, 'Persona (DNI)'), (Cliente.ruc, 'Empresa (RUC)')],
            valor: _tipo,
            alCambiar: (t) => setState(() => _tipo = t),
          ),
          CampoTexto(label: ruc ? 'RUC' : 'DNI', controller: _documento, soloDigitos: true,
              validator: ruc ? Validadores.ruc : Validadores.dni),
          CampoTexto(label: ruc ? 'Razón social' : 'Nombre y apellidos', controller: _nombre,
              validator: (v) => Validadores.longitudMinima(v, 'el nombre', 3)),
          CampoTexto(label: 'Teléfono', controller: _telefono, soloDigitos: true, validator: Validadores.telefonoContacto),
          CampoTexto(label: 'Correo (opcional)', controller: _correo, teclado: TextInputType.emailAddress,
              validator: (v) => (v ?? '').trim().isEmpty ? null : Validadores.correo(v)),
          if (c == null) ...[
            Text('Vehículo', style: Ind.heading(15)),
            ..._camposVehiculo(_placa, _marca, _modelo, _anio, _tipoVehiculo, (t) => setState(() => _tipoVehiculo = t)),
          ],
          PrimaryButton(label: 'Guardar', onPressed: _guardar),
        ],
      ),
    );
  }
}

List<Widget> _camposVehiculo(
  TextEditingController placa,
  TextEditingController marca,
  TextEditingController modelo,
  TextEditingController anio,
  String tipo,
  ValueChanged<String> alCambiarTipo, {
  bool placaEditable = true,
}) => [
  if (placaEditable) CampoTexto(label: 'Placa', controller: placa, mayusculas: true, validator: Validadores.placa),
  Row(children: [
    Expanded(child: CampoTexto(label: 'Marca', controller: marca, validator: (v) => Validadores.requerido(v, 'la marca'))),
    const SizedBox(width: 10),
    Expanded(child: CampoTexto(label: 'Modelo', controller: modelo, validator: (v) => Validadores.requerido(v, 'el modelo'))),
  ]),
  CampoTexto(label: 'Año', controller: anio, soloDigitos: true, validator: Validadores.anio),
  IndField(
    label: 'Tipo de vehículo',
    child: Segmentos<String>(
      opciones: [for (final t in TiposVehiculo.claves) (t, TiposVehiculo.etiqueta(t).split(' / ').first)],
      valor: tipo,
      alCambiar: alCambiarTipo,
    ),
  ),
];

class _FormularioVehiculo extends StatefulWidget {
  const _FormularioVehiculo({required this.clienteId, this.vehiculo});

  final String clienteId;
  final Vehiculo? vehiculo;

  @override
  State<_FormularioVehiculo> createState() => _FormularioVehiculoState();
}

class _FormularioVehiculoState extends State<_FormularioVehiculo> {
  final _formKey = GlobalKey<FormState>();
  late final v = widget.vehiculo;
  late final _placa = TextEditingController(text: v?.placa ?? '');
  late final _marca = TextEditingController(text: v?.marca ?? '');
  late final _modelo = TextEditingController(text: v?.modelo ?? '');
  late final _anio = TextEditingController(text: v == null ? '' : '${v!.anio}');
  late String _tipo = v?.tipo ?? TiposVehiculo.auto;

  @override
  void dispose() {
    for (final t in [_placa, _marca, _modelo, _anio]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final navegador = Navigator.of(context);
    final vehiculo = (v ?? Vehiculo(placa: _placa.text, marca: '', modelo: '', anio: 0)).copyWith(
      placa: _placa.text,
      marca: _marca.text,
      modelo: _modelo.text,
      anio: int.parse(_anio.text),
      tipo: _tipo,
    );
    final ok = await ejecutar(context, () async {
      await ClienteService.instancia.guardarVehiculo(widget.clienteId, vehiculo, placaAnterior: v?.placa);
      return true;
    }, exito: 'Vehículo guardado');
    if (ok == true) navegador.pop();
  }

  Future<void> _eliminar() async {
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ClienteService.instancia.eliminarVehiculo(widget.clienteId, v!.placa);
      navegador.pop();
      mostrarMensaje(mensajero, 'Vehículo ${v!.placa} eliminado');
    } catch (e) {
      mostrarMensaje(mensajero, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: v?.placa ?? 'Vehículo',
        titulo: v == null ? 'Agregar vehículo' : 'Editar vehículo',
        children: [
          ..._camposVehiculo(_placa, _marca, _modelo, _anio, _tipo, (t) => setState(() => _tipo = t),
              placaEditable: v == null),
          PrimaryButton(label: 'Guardar', onPressed: _guardar),
          if (v != null) TextButton(onPressed: _eliminar, child: const Text('Eliminar vehículo')),
        ],
      ),
    );
  }
}
