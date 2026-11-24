import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/models/adicional.dart';
import '../modules/catalogo/models/categoria.dart';
import '../modules/catalogo/models/repuesto.dart';
import '../modules/catalogo/models/servicio.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/catalogo/services/favoritos_service.dart';
import '../modules/catalogo/services/recomendaciones.dart';
import '../modules/ordenes/models/calculadora_precios.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/iconos_taller.dart';
import '../widgets/stock_bar.dart';
import '../widgets/tarjeta_fila.dart';

typedef AgregarServicio = void Function(Servicio servicio, List<Adicional> adicionales, int cantidad);
typedef AgregarRepuesto = void Function(Repuesto repuesto, int cantidad);

/// Abre el catálogo para agregar servicios o repuestos a una orden.
/// Los callbacks pueden lanzar StateError (sin stock...): se muestra el error.
Future<void> abrirSelectorCatalogo(
  BuildContext context, {
  required String tipoVehiculo,
  required AgregarServicio alAgregarServicio,
  required AgregarRepuesto alAgregarRepuesto,
}) => mostrarHoja(
  context,
  SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.85,
    child: SelectorCatalogo(
      tipoVehiculo: tipoVehiculo,
      alAgregarServicio: alAgregarServicio,
      alAgregarRepuesto: alAgregarRepuesto,
    ),
  ),
);

class SelectorCatalogo extends StatefulWidget {
  const SelectorCatalogo({
    super.key,
    required this.tipoVehiculo,
    required this.alAgregarServicio,
    required this.alAgregarRepuesto,
  });

  final String tipoVehiculo;
  final AgregarServicio alAgregarServicio;
  final AgregarRepuesto alAgregarRepuesto;

  @override
  State<SelectorCatalogo> createState() => _SelectorCatalogoState();
}

class _SelectorCatalogoState extends State<SelectorCatalogo> {
  bool _repuestos = false;
  bool _soloFavoritos = false;
  String _categoria = Categoria.idTodas;
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _intentar(VoidCallback accion, String exito) {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      accion();
      mostrarMensaje(mensajero, exito);
    } catch (e) {
      mostrarMensaje(mensajero, mensajeError(e), error: true);
    }
  }

  Future<void> _elegirRepuesto(Repuesto r) async {
    final texto = await pedirTexto(
      context,
      titulo: r.nombre,
      etiqueta: 'Cantidad (hay ${r.stock})',
      accion: 'Agregar',
      inicial: '1',
      soloDigitos: true,
      validator: (v) {
        final error = Validadores.entero(v, 'la cantidad', minimo: 1);
        if (error != null) return error;
        return int.parse(v!) > r.stock ? 'Solo hay ${r.stock} unidades' : null;
      },
    );
    if (texto == null || !mounted) return;
    _intentar(() => widget.alAgregarRepuesto(r, int.parse(texto)), '${r.nombre} agregado');
  }

  Future<void> _elegirServicio(Servicio s) async {
    await mostrarHoja<void>(
      context,
      _DetalleServicio(
        servicio: s,
        tipoVehiculo: widget.tipoVehiculo,
        alAgregar: (adicionales, cantidad) =>
            _intentar(() => widget.alAgregarServicio(s, adicionales, cantidad), '${s.nombre} agregado'),
        alElegirOtro: (otro) {
          Navigator.pop(context);
          _elegirServicio(otro);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([CatalogoService.instancia, FavoritosService.instancia]),
      builder: (context, _) {
        final catalogo = CatalogoService.instancia.catalogo;
        final favoritos = FavoritosService.instancia;
        final categorias = _repuestos ? catalogo.categoriasRepuesto : catalogo.categoriasServicio;
        final texto = _busqueda.text;
        final servicios = catalogo
            .filtrarServicios(categoriaId: _categoria, texto: texto)
            .where((s) => !_soloFavoritos || favoritos.esFavorito(s.id))
            .toList();
        final repuestos = catalogo.filtrarRepuestos(
          texto: texto,
          categoriaId: _categoria,
          incluirInactivos: false,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Catálogo · ${TiposVehiculo.etiqueta(widget.tipoVehiculo)}',
                      style: Ind.kicker()),
                  Text('Agregar a la orden', style: Ind.heading(21, height: 1.2)),
                  const SizedBox(height: 12),
                  Segmentos<bool>(
                    opciones: const [(false, 'Servicios'), (true, 'Repuestos')],
                    valor: _repuestos,
                    alCambiar: (repuestos) => setState(() {
                      _repuestos = repuestos;
                      _categoria = Categoria.idTodas;
                      if (repuestos) _soloFavoritos = false;
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _busqueda,
                    onChanged: (_) => setState(() {}),
                    style: Ind.body(14, height: 1.3),
                    decoration: InputDecoration(
                      hintText: _repuestos ? 'Buscar por nombre o código' : 'Buscar servicio',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final c in [Categoria.todas, ...categorias])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TagChip(
                            label: c.nombre,
                            selected: _categoria == c.id && !_soloFavoritos,
                            onTap: () => setState(() {
                              _categoria = c.id;
                              _soloFavoritos = false;
                            }),
                          ),
                        ),
                      if (!_repuestos)
                        TagChip(
                          label: 'Favoritos',
                          selected: _soloFavoritos,
                          onTap: () => setState(() => _soloFavoritos = !_soloFavoritos),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (_repuestos ? repuestos.isEmpty : servicios.isEmpty)
                    const EstadoVacio(titulo: 'Sin resultados', ayuda: 'Prueba con otra categoría o búsqueda'),
                  if (_repuestos)
                    for (final r in repuestos) ...[
                      _FilaRepuesto(repuesto: r, onTap: r.disponible ? () => _elegirRepuesto(r) : null),
                      const SizedBox(height: 10),
                    ]
                  else
                    for (final s in servicios) ...[
                      _FilaServicio(
                        servicio: s,
                        tipoVehiculo: widget.tipoVehiculo,
                        favorito: favoritos.esFavorito(s.id),
                        alAlternarFavorito: () => favoritos.alternar(s.id),
                        onTap: () => _elegirServicio(s),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({
    required this.servicio,
    required this.tipoVehiculo,
    required this.favorito,
    required this.alAlternarFavorito,
    required this.onTap,
  });

  final Servicio servicio;
  final String tipoVehiculo;
  final bool favorito;
  final VoidCallback alAlternarFavorito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final precio = CalculadoraPrecios.precioServicio(servicio: servicio, variante: tipoVehiculo);
    return TarjetaFila(
      onTap: onTap,
      icono: iconoServicio(servicio),
      titulo: servicio.nombre,
      subtitulo: servicio.subtitulo,
      pie: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(formatoCentimos(precio), style: Ind.heading(15, color: Ind.accent)),
          if (servicio.tieneDescuento) EstadoTag('-${servicio.descuentoPorcentaje}%', variant: TagVariant.peligro),
          if (servicio.popular) const EstadoTag('Popular', variant: TagVariant.neutral),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: alAlternarFavorito,
            tooltip: favorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
            icon: Icon(favorito ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorito ? const Color(0xFFF5A524) : Ind.n400, size: 22),
          ),
          BotonAgregar(onPressed: onTap, etiqueta: 'Agregar ${servicio.nombre}'),
        ],
      ),
    );
  }
}

class _FilaRepuesto extends StatelessWidget {
  const _FilaRepuesto({required this.repuesto, this.onTap});

  final Repuesto repuesto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final alerta = repuesto.agotado || repuesto.critico;
    return TarjetaFila(
      onTap: onTap ?? () => mostrarMensaje(ScaffoldMessenger.of(context), '${repuesto.nombre} está agotado', error: true),
      semanticLabel: '${repuesto.nombre}, stock ${repuesto.stock}',
      icono: iconoRepuesto(repuesto),
      titulo: repuesto.nombre,
      subtitulo: '${repuesto.codigo} · stock ${repuesto.stock}',
      pie: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(formatoCentimos(repuesto.precioCentimos), style: Ind.heading(15, color: Ind.accent)),
          if (repuesto.agotado)
            const EstadoTag('Agotado', variant: TagVariant.peligro)
          else if (repuesto.critico)
            const EstadoTag('Stock crítico', variant: TagVariant.peligro),
        ],
      ),
      trailing: BotonAgregar(onPressed: onTap, etiqueta: 'Agregar ${repuesto.nombre}'),
      debajo: NivelBar(valor: repuesto.nivel, color: alerta ? Ind.peligro : Ind.accent),
    );
  }
}

/// Detalle del servicio: precio para el vehículo, adicionales, cantidad y
/// servicios parecidos (Guía 14).
class _DetalleServicio extends StatefulWidget {
  const _DetalleServicio({
    required this.servicio,
    required this.tipoVehiculo,
    required this.alAgregar,
    required this.alElegirOtro,
  });

  final Servicio servicio;
  final String tipoVehiculo;
  final void Function(List<Adicional>, int) alAgregar;
  final ValueChanged<Servicio> alElegirOtro;

  @override
  State<_DetalleServicio> createState() => _DetalleServicioState();
}

class _DetalleServicioState extends State<_DetalleServicio> {
  final Set<String> _elegidos = {};
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final catalogo = CatalogoService.instancia.catalogo;
    final s = widget.servicio;
    final adicionales = catalogo.adicionalesDe(s);
    final elegidos = adicionales.where((a) => _elegidos.contains(a.id)).toList();
    final unitario = CalculadoraPrecios.precioServicio(servicio: s, variante: widget.tipoVehiculo, adicionales: elegidos);
    final precio = s.precio(widget.tipoVehiculo);
    final parecidos = Recomendaciones.para(s, catalogo.servicios);

    return HojaContenido(
      kicker: TiposVehiculo.etiqueta(widget.tipoVehiculo),
      titulo: s.nombre,
      children: [
        Row(children: [
          IconoMosaico(iconoServicio(s), tamano: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatoCentimos(s.aplicarDescuento(precio.precioCentimos)), style: Ind.heading(22, color: Ind.accent)),
              Text('Mano de obra${s.tieneDescuento ? ' (-${s.descuentoPorcentaje}%)' : ''}', style: Ind.meta),
            ]),
          ),
        ]),
        if (s.descripcion.isNotEmpty || s.subtitulo.isNotEmpty)
          Text(s.descripcion.isNotEmpty ? s.descripcion : s.subtitulo, style: Ind.body(13.5, color: Ind.muted)),
        DatoIcono(Icons.schedule_rounded, '${precio.minutos} min en bahía (estimado)'),
        if (s.garantiaDias > 0) DatoIcono(Icons.verified_user_rounded, 'Garantía de ${plural(s.garantiaDias, 'día', 'días')}'),
        if (adicionales.isNotEmpty) ...[
          Text('Adicionales', style: Ind.heading(15)),
          for (final a in adicionales)
            CheckboxListTile(
              value: _elegidos.contains(a.id),
              onChanged: (v) => setState(() => v! ? _elegidos.add(a.id) : _elegidos.remove(a.id)),
              title: Text(a.nombre, style: Ind.body(13, height: 1.3)),
              secondary: Text('+${formatoCentimos(a.precioCentimos)}', style: Ind.body(12, color: Ind.muted)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
        ],
        Row(children: [
          Text('Cantidad', style: Ind.body(13)),
          const Spacer(),
          SelectorCantidad(valor: _cantidad, maximo: 10, alCambiar: (v) => setState(() => _cantidad = v)),
        ]),
        FilaMonto('Total', formatoCentimos(unitario * _cantidad), resaltar: true),
        PrimaryButton(
          label: 'Agregar a la orden',
          onPressed: () {
            widget.alAgregar(elegidos, _cantidad);
            Navigator.pop(context);
          },
        ),
        if (parecidos.isNotEmpty) ...[
          Text('También suelen pedir', style: Ind.heading(15)),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final p in parecidos)
              TagChip(label: p.nombre, selected: false, onTap: () => widget.alElegirOtro(p)),
          ]),
        ],
      ],
    );
  }
}
