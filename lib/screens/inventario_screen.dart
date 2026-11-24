import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../core/widgets/mensajes.dart';
import '../modules/catalogo/models/categoria.dart';
import '../modules/catalogo/models/repuesto.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/cuentas/services/permisos.dart';
import '../state/app_state.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/foto_repuesto.dart';
import '../widgets/ind_page.dart';
import '../widgets/kpi_card.dart';
import '../widgets/stock_bar.dart';
import '../widgets/tarjeta_fila.dart';

enum FiltroStock { todos('Todos'), criticos('Stock crítico'), inactivos('Descontinuados');
  const FiltroStock(this.label);
  final String label;
}

enum OrdenStock { nombre('A – Z'), stock('Menor stock'), precio('Mayor precio');
  const OrdenStock(this.label);
  final String label;
}

/// Filtra y ordena el inventario (función pura).
List<Repuesto> listarInventario(
  Catalogo catalogo, {
  String texto = '',
  FiltroStock filtro = FiltroStock.todos,
  OrdenStock orden = OrdenStock.nombre,
}) {
  final lista = catalogo
      .filtrarRepuestos(texto: texto, soloCriticos: filtro == FiltroStock.criticos)
      .where((r) => filtro == FiltroStock.inactivos ? !r.activo : (filtro == FiltroStock.todos || r.activo))
      .toList();
  switch (orden) {
    case OrdenStock.nombre:
      lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    case OrdenStock.stock:
      lista.sort((a, b) => (a.stock / (a.minimo == 0 ? 1 : a.minimo)).compareTo(b.stock / (b.minimo == 0 ? 1 : b.minimo)));
    case OrdenStock.precio:
      lista.sort((a, b) => b.precioCentimos.compareTo(a.precioCentimos));
  }
  return lista;
}

/// Inventario de repuestos (Módulo 04).
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _busqueda = TextEditingController();
  FiltroStock _filtro = FiltroStock.todos;
  OrdenStock _orden = OrdenStock.nombre;

  CatalogoService get _servicio => CatalogoService.instancia;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _ingresar(Repuesto r) async {
    final texto = await pedirTexto(context,
        titulo: 'Ingreso de ${r.nombre}', etiqueta: 'Unidades que ingresan', accion: 'Ingresar', soloDigitos: true,
        validator: (v) => Validadores.entero(v, 'la cantidad', minimo: 1));
    if (texto == null || !mounted) return;
    ejecutar(context, () => _servicio.ingresarStock(r.codigo, int.parse(texto)), exito: '+$texto ${r.nombre}');
  }

  Future<void> _ajustar(Repuesto r) async {
    final texto = await pedirTexto(context,
        titulo: 'Inventario físico', etiqueta: 'Unidades contadas de ${r.nombre}', accion: 'Ajustar',
        soloDigitos: true, inicial: '${r.stock}', validator: (v) => Validadores.entero(v, 'el stock'));
    if (texto == null || !mounted) return;
    ejecutar(context, () => _servicio.ajustarStock(r.codigo, int.parse(texto)), exito: 'Stock de ${r.nombre}: $texto');
  }

  Future<void> _eliminar(Repuesto r) async {
    final ok = await confirmar(context, titulo: 'Eliminar ${r.codigo}', mensaje: r.nombre, accion: 'Eliminar');
    if (!ok || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final eliminado = await ejecutar(context, () => _servicio.eliminarRepuesto(r.codigo));
    if (eliminado == null) return;
    mostrarDeshacer(mensajero, '${r.nombre} eliminado', () => _servicio.guardarRepuesto(eliminado, nuevo: true));
  }

  void _acciones(Repuesto r, bool puedeEditar) => mostrarHoja<void>(
    context,
    HojaContenido(
      kicker: '${r.codigo} · ${r.marca.isEmpty ? 'sin marca' : r.marca}',
      titulo: r.nombre,
      children: [
        Row(children: [
          FotoRepuesto(r, tamano: 96, alerta: r.critico),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatoCentimos(r.precioCentimos), style: Ind.heading(22, color: Ind.accent)),
              Text('Precio de venta', style: Ind.meta),
            ]),
          ),
        ]),
        NivelBar(valor: r.nivel, color: r.critico ? Ind.peligro : Ind.accent),
        FilaMonto('Stock / mínimo', '${r.stock} / ${r.minimo}'),
        if (r.critico) FilaMonto('Sugerido reponer', '${r.sugeridoReponer} unidades'),
        if (puedeEditar) ...[
          PrimaryButton(label: 'Ingreso de mercadería', onPressed: () {
            Navigator.pop(context);
            _ingresar(r);
          }),
          SecondaryButton(label: 'Inventario físico', onPressed: () {
            Navigator.pop(context);
            _ajustar(r);
          }),
          SecondaryButton(label: 'Editar', onPressed: () {
            Navigator.pop(context);
            mostrarHoja<void>(context, FormularioRepuesto(repuesto: r));
          }),
          SecondaryButton(label: r.activo ? 'Descontinuar' : 'Reactivar', onPressed: () {
            Navigator.pop(context);
            ejecutar(context, () => _servicio.cambiarActivoRepuesto(r.codigo, !r.activo));
          }),
          TextButton(onPressed: () {
            Navigator.pop(context);
            _eliminar(r);
          }, child: const Text('Eliminar')),
        ] else
          Text('Solo el jefe de taller o administración mueven el stock. '
              'La salida a una orden es automática en la etapa Repuestos.', style: Ind.meta),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final puedeEditar = Permisos.puedeEditarCatalogo(AppScope.of(context).rol);
    return ListenableBuilder(
      listenable: _servicio,
      builder: (context, _) {
        final catalogo = _servicio.catalogo;
        final lista = listarInventario(catalogo, texto: _busqueda.text, filtro: _filtro, orden: _orden);
        final valor = catalogo.repuestos.where((r) => r.activo).fold(0, (s, r) => s + r.precioCentimos * r.stock);
        return IndPage(
          kicker: 'Almacén',
          titulo: 'Inventario',
          gap: 12,
          children: [
            KpiGrid(valorSize: 24, items: [
              ('${catalogo.stockCritico.length}', 'Stock crítico'),
              (formatoCentimos(valor).replaceFirst('S/ ', ''), 'Valor S/ en almacén'),
            ]),
            if (puedeEditar)
              PrimaryButton(label: 'Nuevo repuesto', onPressed: () => mostrarHoja<void>(context, const FormularioRepuesto())),
            TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              style: Ind.body(14, height: 1.3),
              decoration: const InputDecoration(hintText: 'Buscar por nombre, código o marca', prefixIcon: Icon(Icons.search_rounded)),
            ),
            Wrap(spacing: 6, runSpacing: 2, children: [
              for (final f in FiltroStock.values)
                TagChip(label: f.label, selected: _filtro == f, onTap: () => setState(() => _filtro = f)),
              for (final o in OrdenStock.values)
                TagChip(label: o.label, selected: _orden == o, onTap: () => setState(() => _orden = o)),
            ]),
            if (lista.isEmpty)
              const EstadoVacio(titulo: 'Sin resultados', ayuda: 'Prueba con otro filtro o búsqueda')
            else
              for (final r in lista)
                TarjetaFila(
                  onTap: () => _acciones(r, puedeEditar),
                  semanticLabel: '${r.nombre}, stock ${r.stock}',
                  // Descontinuado: la foto se ve apagada.
                  inicio: Opacity(
                    opacity: r.activo ? 1 : 0.45,
                    child: FotoRepuesto(r, tamano: 56, alerta: r.activo && r.critico),
                  ),
                  titulo: r.nombre,
                  subtitulo: '${r.codigo} · stock ${r.stock} (mín. ${r.minimo})',
                  pie: Text(formatoCentimos(r.precioCentimos), style: Ind.heading(14.5, color: Ind.accent)),
                  trailing: !r.activo
                      ? const EstadoTag('Descontinuado', variant: TagVariant.neutral)
                      : r.critico
                          ? const EstadoTag('Stock crítico', variant: TagVariant.peligro)
                          : null,
                  debajo: NivelBar(valor: r.nivel, color: r.activo && r.critico ? Ind.peligro : Ind.accent),
                ),
          ],
        );
      },
    );
  }
}

/// Alta o edición de un repuesto.
class FormularioRepuesto extends StatefulWidget {
  const FormularioRepuesto({super.key, this.repuesto});

  final Repuesto? repuesto;

  @override
  State<FormularioRepuesto> createState() => _FormularioRepuestoState();
}

class _FormularioRepuestoState extends State<FormularioRepuesto> {
  final _formKey = GlobalKey<FormState>();
  late final r = widget.repuesto;
  late final _codigo = TextEditingController(text: r?.codigo ?? '');
  late final _nombre = TextEditingController(text: r?.nombre ?? '');
  late final _marca = TextEditingController(text: r?.marca ?? '');
  late final _precio = TextEditingController(text: r == null ? '' : montoCentimos(r!.precioCentimos).replaceAll(',', ''));
  late final _stock = TextEditingController(text: '${r?.stock ?? 0}');
  late final _minimo = TextEditingController(text: '${r?.minimo ?? 5}');
  late String _categoria = r?.categoriaId ?? '';

  @override
  void dispose() {
    for (final c in [_codigo, _nombre, _marca, _precio, _stock, _minimo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final navegador = Navigator.of(context);
    final ok = await ejecutar(
      context,
      () async {
        await CatalogoService.instancia.guardarRepuesto(
          Repuesto(
            codigo: _codigo.text,
            nombre: _nombre.text,
            marca: _marca.text.trim(),
            categoriaId: _categoria,
            precioCentimos: (double.parse(_precio.text.replaceAll(',', '.')) * 100).round(),
            stock: int.parse(_stock.text),
            minimo: int.parse(_minimo.text),
            activo: r?.activo ?? true,
          ),
          nuevo: r == null,
        );
        return true;
      },
      exito: r == null ? 'Repuesto creado' : 'Repuesto actualizado',
    );
    if (ok == true) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categorias = CatalogoService.instancia.catalogo.categoriasRepuesto;
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: 'Inventario',
        titulo: r == null ? 'Nuevo repuesto' : 'Editar ${r!.codigo}',
        children: [
          if (r == null)
            CampoTexto(label: 'Código (LUB-1040)', controller: _codigo, mayusculas: true,
                validator: (v) => Validadores.requerido(v, 'el código')),
          CampoTexto(label: 'Nombre', controller: _nombre, validator: (v) => Validadores.requerido(v, 'el nombre')),
          CampoTexto(label: 'Marca', controller: _marca),
          Wrap(spacing: 6, runSpacing: 2, children: [
            for (final Categoria c in categorias)
              TagChip(label: c.nombre, selected: _categoria == c.id, onTap: () => setState(() => _categoria = c.id)),
          ]),
          CampoTexto(label: 'Precio (S/)', controller: _precio, teclado: const TextInputType.numberWithOptions(decimal: true),
              validator: Validadores.precio),
          Row(children: [
            Expanded(child: CampoTexto(label: 'Stock', controller: _stock, soloDigitos: true,
                validator: (v) => Validadores.entero(v, 'el stock'))),
            const SizedBox(width: 10),
            Expanded(child: CampoTexto(label: 'Mínimo', controller: _minimo, soloDigitos: true,
                validator: (v) => Validadores.entero(v, 'el mínimo'))),
          ]),
          PrimaryButton(label: 'Guardar', onPressed: _guardar),
        ],
      ),
    );
  }
}
