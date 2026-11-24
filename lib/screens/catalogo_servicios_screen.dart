import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/models/categoria.dart';
import '../modules/catalogo/models/servicio.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/ind_page.dart';
import '../widgets/tarjeta_fila.dart';

enum OrdenCatalogo { masPedidos('Más pedidos'), nombre('A – Z'), menorPrecio('Menor precio'), mayorPrecio('Mayor precio');
  const OrdenCatalogo(this.label);
  final String label;
}

/// Veces que se pidió cada servicio (sin órdenes anuladas).
Map<String, int> contarPedidos(List<Orden> ordenes) {
  final conteo = <String, int>{};
  for (final o in ordenes.where((o) => o.estado != EstadoOrden.cancelado)) {
    for (final l in o.lineas.where((l) => l.esServicio)) {
      conteo[l.refId] = (conteo[l.refId] ?? 0) + l.cantidad;
    }
  }
  return conteo;
}

/// Catálogo de servicios del taller (precios y disponibilidad).
class CatalogoServiciosScreen extends StatefulWidget {
  const CatalogoServiciosScreen({super.key});

  @override
  State<CatalogoServiciosScreen> createState() => _CatalogoServiciosScreenState();
}

class _CatalogoServiciosScreenState extends State<CatalogoServiciosScreen> {
  late final Stream<List<Orden>> _ordenes = OrdenService.instancia.todas(limite: 300);
  String _categoria = Categoria.idTodas;
  OrdenCatalogo _orden = OrdenCatalogo.masPedidos;
  bool? _disponibles;

  CatalogoService get _servicio => CatalogoService.instancia;

  Future<void> _habilitarTodos(List<Servicio> agotados) async {
    for (final s in agotados) {
      await _servicio.cambiarDisponibleServicio(s.id, true);
    }
    if (mounted) mostrarMensaje(ScaffoldMessenger.of(context), '${plural(agotados.length, 'servicio disponible', 'servicios disponibles')} otra vez');
  }

  Future<void> _eliminar(Servicio s) async {
    final ok = await confirmar(context, titulo: 'Eliminar servicio', mensaje: s.nombre, accion: 'Eliminar');
    if (!ok || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final borrado = await ejecutar(context, () async {
      await _servicio.eliminarServicio(s.id);
      return true;
    });
    if (borrado == true) mostrarDeshacer(mensajero, '${s.nombre} eliminado', () => _servicio.guardarServicio(s));
  }

  @override
  Widget build(BuildContext context) {
    final puedeEditar = Permisos.puedeEditarCatalogo(AppScope.of(context).rol);
    return StreamBuilder<List<Orden>>(
      stream: _ordenes,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: _servicio,
        builder: (context, _) {
          final catalogo = _servicio.catalogo;
          final pedidos = contarPedidos(snapshot.data ?? const []);
          final todos = catalogo.filtrarServicios(categoriaId: _categoria, soloDisponibles: false);
          final agotados = catalogo.servicios.where((s) => !s.disponible).toList();
          final lista = todos.where((s) => _disponibles == null || s.disponible == _disponibles).toList();
          switch (_orden) {
            case OrdenCatalogo.masPedidos:
              lista.sort((a, b) => (pedidos[b.id] ?? 0).compareTo(pedidos[a.id] ?? 0));
            case OrdenCatalogo.nombre:
              lista.sort((a, b) => a.nombre.compareTo(b.nombre));
            case OrdenCatalogo.menorPrecio:
              lista.sort((a, b) => a.precioDesdeCentimos.compareTo(b.precioDesdeCentimos));
            case OrdenCatalogo.mayorPrecio:
              lista.sort((a, b) => b.precioDesdeCentimos.compareTo(a.precioDesdeCentimos));
          }
          final top = pedidos.isEmpty ? null : (pedidos.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

          return IndPage(
            kicker: plural(catalogo.servicios.length, 'servicio', 'servicios'),
            titulo: 'Catálogo de servicios',
            gap: 12,
            children: [
              if (puedeEditar)
                PrimaryButton(label: 'Nuevo servicio', onPressed: () => mostrarHoja<void>(context, const FormularioServicio())),
              if (puedeEditar && agotados.isNotEmpty)
                SecondaryButton(
                  label: 'Habilitar ${plural(agotados.length, 'no disponible', 'no disponibles')}',
                  onPressed: () => _habilitarTodos(agotados),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in [Categoria.todas, ...catalogo.categoriasServicio])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TagChip(label: c.nombre, selected: _categoria == c.id, onTap: () => setState(() => _categoria = c.id)),
                    ),
                ]),
              ),
              Wrap(spacing: 6, runSpacing: 2, children: [
                TagChip(label: 'Todos', selected: _disponibles == null, onTap: () => setState(() => _disponibles = null)),
                TagChip(label: 'Disponibles', selected: _disponibles == true, onTap: () => setState(() => _disponibles = true)),
                TagChip(label: 'No disponibles', selected: _disponibles == false, onTap: () => setState(() => _disponibles = false)),
                for (final o in OrdenCatalogo.values)
                  TagChip(label: o.label, selected: _orden == o, onTap: () => setState(() => _orden = o)),
              ]),
              if (lista.isEmpty) const EstadoVacio(titulo: 'Sin resultados', ayuda: 'Prueba con otra categoría'),
              for (final s in lista)
                TarjetaFila(
                  onTap: puedeEditar ? () => mostrarHoja<void>(context, FormularioServicio(servicio: s)) : null,
                  icono: iconoServicio(s),
                  colorIcono: s.disponible ? Ind.accent : Ind.n500,
                  fondoIcono: s.disponible ? Ind.a100 : Ind.n100,
                  titulo: s.nombre,
                  subtitulo: [for (final p in s.precios.values) '${p.etiqueta} ${formatoCentimos(s.aplicarDescuento(p.precioCentimos))}']
                      .join(' · '),
                  pie: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${plural(pedidos[s.id] ?? 0, 'pedido', 'pedidos')}${s.intervaloKm > 0 ? ' · cada ${formatoKm(s.intervaloKm)}' : ''}',
                        style: Ind.meta),
                    if (s.id == top) const EstadoTag('#1 pedidos', variant: TagVariant.outline),
                    if (s.tieneDescuento) EstadoTag('-${s.descuentoPorcentaje}%', variant: TagVariant.peligro),
                    if (!s.disponible) const EstadoTag('No disponible', variant: TagVariant.neutral),
                  ]),
                  debajo: puedeEditar
                      ? Container(
                          padding: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ind.n100))),
                          child: Row(children: [
                            Text(s.disponible ? 'Disponible' : 'No disponible', style: Ind.body(13, color: Ind.n700)),
                            const Spacer(),
                            Switch(
                              value: s.disponible,
                              onChanged: (v) => ejecutar(context, () => _servicio.cambiarDisponibleServicio(s.id, v)),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              onPressed: () => _eliminar(s),
                              icon: const Icon(Icons.delete_outline_rounded, size: 21, color: Ind.peligro),
                            ),
                          ]),
                        )
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Alta o edición de un servicio: precios por tipo de vehículo, minutos,
/// descuento, categorías, adicionales, garantía e intervalo de km.
class FormularioServicio extends StatefulWidget {
  const FormularioServicio({super.key, this.servicio});

  final Servicio? servicio;

  @override
  State<FormularioServicio> createState() => _FormularioServicioState();
}

class _FormularioServicioState extends State<FormularioServicio> {
  final _formKey = GlobalKey<FormState>();
  late final s = widget.servicio;
  late final _nombre = TextEditingController(text: s?.nombre ?? '');
  late final _subtitulo = TextEditingController(text: s?.subtitulo ?? '');
  late final _descuento = TextEditingController(text: '${s?.descuentoPorcentaje ?? 0}');
  late final _garantia = TextEditingController(text: '${s?.garantiaDias ?? 0}');
  late final _intervalo = TextEditingController(text: '${s?.intervaloKm ?? 0}');
  late final Map<String, TextEditingController> _precios = {
    for (final t in TiposVehiculo.claves)
      t: TextEditingController(text: s?.precios[t] == null ? '' : montoCentimos(s!.precios[t]!.precioCentimos).replaceAll(',', '')),
  };
  late final Map<String, TextEditingController> _minutos = {
    for (final t in TiposVehiculo.claves) t: TextEditingController(text: '${s?.precios[t]?.minutos ?? 60}'),
  };
  late final Set<String> _categorias = {...?s?.categoriaIds};
  late final Set<String> _adicionales = {...?s?.adicionalIds};
  late bool _popular = s?.popular ?? false;

  @override
  void dispose() {
    for (final c in [_nombre, _subtitulo, _descuento, _garantia, _intervalo, ..._precios.values, ..._minutos.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final navegador = Navigator.of(context);
    final descuento = int.parse(_descuento.text);
    final servicio = (s ?? const Servicio(id: '', nombre: '', precios: {})).copyWith(
      nombre: _nombre.text.trim(),
      subtitulo: _subtitulo.text.trim(),
      categoriaIds: _categorias.toList(),
      adicionalIds: _adicionales.toList(),
      popular: _popular,
      descuentoPorcentaje: descuento > 0 ? descuento : null,
      quitarDescuento: descuento == 0,
      garantiaDias: int.parse(_garantia.text),
      intervaloKm: int.parse(_intervalo.text),
      precios: {
        for (final t in TiposVehiculo.claves)
          if (_precios[t]!.text.trim().isNotEmpty)
            t: PrecioVehiculo(
              clave: t,
              precioCentimos: (double.parse(_precios[t]!.text.replaceAll(',', '.')) * 100).round(),
              minutos: int.tryParse(_minutos[t]!.text) ?? 60,
            ),
      },
    );
    final ok = await ejecutar(context, () async {
      await CatalogoService.instancia.guardarServicio(servicio);
      return true;
    }, exito: s == null ? 'Servicio creado' : 'Servicio actualizado');
    if (ok == true) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instancia.catalogo;
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: 'Catálogo',
        titulo: s == null ? 'Nuevo servicio' : 'Editar servicio',
        children: [
          CampoTexto(label: 'Nombre', controller: _nombre, validator: (v) => Validadores.longitudMinima(v, 'el nombre', 3)),
          CampoTexto(label: 'Subtítulo', controller: _subtitulo),
          for (final t in TiposVehiculo.claves)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: CampoTexto(
                  label: 'Precio ${TiposVehiculo.etiqueta(t)} (S/)',
                  controller: _precios[t]!,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (t != TiposVehiculo.auto && (v ?? '').trim().isEmpty) ? null : Validadores.precio(v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CampoTexto(label: 'Minutos', controller: _minutos[t]!, soloDigitos: true,
                    validator: (v) => Validadores.entero(v, 'los minutos', minimo: 5)),
              ),
            ]),
          Row(children: [
            Expanded(child: CampoTexto(label: 'Descuento %', controller: _descuento, soloDigitos: true, validator: (v) {
              final error = Validadores.entero(v, 'el descuento');
              if (error != null) return error;
              return int.parse(v!) > 99 ? 'Máximo 99 %' : null;
            })),
            const SizedBox(width: 10),
            Expanded(child: CampoTexto(label: 'Garantía (días)', controller: _garantia, soloDigitos: true,
                validator: (v) => Validadores.entero(v, 'la garantía'))),
          ]),
          CampoTexto(label: 'Repetir cada (km, 0 = no aplica)', controller: _intervalo, soloDigitos: true,
              validator: (v) => Validadores.entero(v, 'el intervalo')),
          Text('Categorías', style: Ind.kicker(size: 13, color: Ind.n700)),
          Wrap(spacing: 6, runSpacing: 2, children: [
            for (final c in catalogo.categoriasServicio)
              TagChip(label: c.nombre, selected: _categorias.contains(c.id), onTap: () => setState(() {
                _categorias.contains(c.id) ? _categorias.remove(c.id) : _categorias.add(c.id);
              })),
          ]),
          Text('Adicionales', style: Ind.kicker(size: 13, color: Ind.n700)),
          Wrap(spacing: 6, runSpacing: 2, children: [
            for (final a in catalogo.adicionales)
              TagChip(label: a.nombre, selected: _adicionales.contains(a.id), onTap: () => setState(() {
                _adicionales.contains(a.id) ? _adicionales.remove(a.id) : _adicionales.add(a.id);
              })),
          ]),
          SwitchListTile(
            value: _popular,
            onChanged: (v) => setState(() => _popular = v),
            contentPadding: EdgeInsets.zero,
            title: Text('Popular (aparece primero)', style: Ind.body(13)),
          ),
          PrimaryButton(label: 'Guardar', onPressed: _guardar),
        ],
      ),
    );
  }
}
