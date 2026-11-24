import 'package:flutter/material.dart';

import '../modules/ordenes/models/orden.dart';
import '../modules/ordenes/services/orden_service.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/ind_page.dart';
import '../widgets/orden_card.dart';
import 'nueva_orden_screen.dart';
import 'orden_detalle_screen.dart';

/// Filtros de la lista (selección única).
enum FiltroOrdenes {
  activas('En taller'),
  diagnostico('Diagnóstico'),
  reparacion('En reparación'),
  listo('Listo'),
  cerradas('Cerradas'),
  todas('Todas');

  const FiltroOrdenes(this.label);
  final String label;

  bool incluye(Orden o) => switch (this) {
    activas => o.estado.activa,
    diagnostico => o.estado == EstadoOrden.diagnostico,
    reparacion => o.estado == EstadoOrden.reparacion,
    listo => o.estado == EstadoOrden.listo,
    cerradas => !o.estado.activa,
    todas => true,
  };
}

/// Busca por placa, código, cliente o servicio.
List<Orden> buscarOrdenes(List<Orden> ordenes, String texto) {
  final b = texto.trim().toLowerCase().replaceAll('-', '');
  if (b.isEmpty) return ordenes;
  return ordenes.where((o) {
    return o.placa.toLowerCase().replaceAll('-', '').contains(b) ||
        o.codigo.toLowerCase().replaceAll('-', '').contains(b) ||
        o.clienteNombre.toLowerCase().contains(b) ||
        o.servicioPrincipal.toLowerCase().contains(b);
  }).toList();
}

class OrdenesScreen extends StatefulWidget {
  const OrdenesScreen({super.key});

  @override
  State<OrdenesScreen> createState() => _OrdenesScreenState();
}

class _OrdenesScreenState extends State<OrdenesScreen> {
  late final Stream<List<Orden>> _ordenes = OrdenService.instancia.todas(limite: 200);
  FiltroOrdenes _filtro = FiltroOrdenes.activas;
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _push(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Orden>>(
      stream: _ordenes,
      builder: (context, snapshot) {
        final todas = snapshot.data ?? const <Orden>[];
        final lista = buscarOrdenes(todas.where(_filtro.incluye).toList(), _busqueda.text);
        return IndPage(
          kicker: 'Taller',
          titulo: 'Órdenes de trabajo',
          gap: 12,
          children: [
            PrimaryButton(label: 'Nueva orden de trabajo', onPressed: () => _push(const NuevaOrdenScreen())),
            TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              style: Ind.body(14, height: 1.3),
              decoration: const InputDecoration(hintText: 'Buscar placa, OT, cliente o servicio', prefixIcon: Icon(Icons.search_rounded)),
            ),
            Wrap(spacing: 6, runSpacing: 2, children: [
              for (final f in FiltroOrdenes.values)
                TagChip(
                  label: '${f.label} ${todas.where(f.incluye).length}',
                  selected: _filtro == f,
                  onTap: () => setState(() => _filtro = f),
                ),
            ]),
            if (snapshot.hasError)
              EstadoVacio(titulo: 'No se pudieron cargar las órdenes', ayuda: '${snapshot.error}')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (lista.isEmpty)
              const EstadoVacio(titulo: 'No hay órdenes aquí', ayuda: 'Prueba con otro filtro o búsqueda')
            else
              for (final o in lista) OrdenCard(orden: o, onTap: () => _push(OrdenDetalleScreen(ordenId: o.id))),
          ],
        );
      },
    );
  }
}
