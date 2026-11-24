import 'package:flutter/material.dart';

import '../core/utils/formatos.dart';
import '../core/utils/validadores.dart';
import '../modules/catalogo/services/catalogo_service.dart';
import '../modules/citas/models/cita.dart';
import '../modules/citas/services/cita_service.dart';
import '../modules/clientes/services/cliente_service.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_tag.dart';
import '../widgets/ind_page.dart';
import '../widgets/tarjeta_fila.dart';
import 'nueva_orden_screen.dart';

TagVariant _variante(EstadoCita e) => switch (e) {
  EstadoCita.enTaller => TagVariant.accent,
  EstadoCita.confirmada => TagVariant.outline,
  _ => TagVariant.neutral,
};

/// Agenda de citas por día (Módulo 05).
class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final _hoy = DateTime.now();
  late DateTime _dia = DateTime(_hoy.year, _hoy.month, _hoy.day);
  late Stream<List<Cita>> _citas = CitaService.instancia.delDia(_dia);

  void _elegirDia(DateTime dia) => setState(() {
    _dia = dia;
    _citas = CitaService.instancia.delDia(dia);
  });

  Future<void> _acciones(Cita c) async {
    await mostrarHoja<void>(
      context,
      HojaContenido(
        kicker: '${c.hora} · ${c.estado.label}',
        titulo: '${c.placa} · ${c.cliente}',
        children: [
          Text('${c.servicio}${c.telefono.isEmpty ? '' : ' · ${c.telefono}'}', style: Ind.body(13)),
          if (c.estado == EstadoCita.confirmada)
            PrimaryButton(
              label: 'Llegó: abrir orden de trabajo',
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NuevaOrdenScreen(
                    placaInicial: c.placa,
                    motivoInicial: c.servicio,
                    alCrear: (orden) =>
                        CitaService.instancia.cambiarEstado(c, EstadoCita.enTaller, ordenId: orden.id),
                  ),
                ));
              },
            ),
          for (final e in c.estado.siguientes)
            SecondaryButton(
              label: 'Marcar: ${e.label.toLowerCase()}',
              onPressed: () {
                Navigator.pop(context);
                ejecutar(context, () => CitaService.instancia.cambiarEstado(c, e), exito: 'Cita: ${e.label.toLowerCase()}');
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dias = CitaService.diasAgenda(_hoy, antes: 2, despues: 4);
    const abreviados = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return StreamBuilder<List<Cita>>(
      stream: _citas,
      builder: (context, snapshot) {
        final citas = snapshot.data ?? const <Cita>[];
        return IndPage(
          kicker: fechaLarga(_dia),
          titulo: 'Agenda de citas',
          gap: 12,
          children: [
            // Tira de días tipo calendario: abreviatura arriba y número grande.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final d in dias)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Dia(
                      abreviado: abreviados[d.weekday - 1],
                      numero: d.day,
                      elegido: d == _dia,
                      hoy: d.year == _hoy.year && d.month == _hoy.month && d.day == _hoy.day,
                      onTap: () => _elegirDia(d),
                    ),
                  ),
              ]),
            ),
            PrimaryButton(
              label: 'Nueva cita',
              onPressed: () => mostrarHoja<void>(context, _HojaNuevaCita(dia: _dia, citas: citas)),
            ),
            if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (citas.isEmpty)
              const EstadoVacio(titulo: 'Sin citas este día')
            else
              for (final c in citas)
                TarjetaFila(
                  onTap: () => _acciones(c),
                  semanticLabel: 'Cita ${c.hora}, ${c.placa}, ${c.estado.label}',
                  inicio: Container(
                    width: 58,
                    height: 48,
                    decoration: BoxDecoration(color: Ind.fondoIcono, borderRadius: BorderRadius.circular(Ind.radiusMd)),
                    alignment: Alignment.center,
                    child: Text(c.hora, style: Ind.heading(15, color: Ind.colorCitas)),
                  ),
                  titulo: c.servicio,
                  subtitulo: '${c.placa} · ${c.cliente}',
                  trailing: EstadoTag(c.estado.label, variant: _variante(c.estado)),
                ),
          ],
        );
      },
    );
  }
}

/// Día de la tira de la agenda (52 × 64): azul sólido si está elegido.
class _Dia extends StatelessWidget {
  const _Dia({
    required this.abreviado,
    required this.numero,
    required this.elegido,
    required this.hoy,
    required this.onTap,
  });

  final String abreviado;
  final int numero;
  final bool elegido;
  final bool hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(Ind.radiusLg);
    final texto = elegido ? Colors.white : Ind.n800;
    return Semantics(
      button: true,
      selected: elegido,
      label: '$abreviado $numero${hoy ? ', hoy' : ''}',
      excludeSemantics: true,
      child: FocusRing(
        radius: Ind.radiusLg,
        child: Material(
          color: elegido ? Ind.accent : Ind.card,
          shape: RoundedRectangleBorder(
            borderRadius: esquinas,
            side: BorderSide(color: elegido ? Ind.accent : (hoy ? Ind.a300 : Ind.n200)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(abreviado, style: Ind.body(12, height: 1.2, color: elegido ? Colors.white70 : Ind.muted)),
                  const SizedBox(height: 2),
                  Text('$numero', style: Ind.heading(19, height: 1.1, color: texto)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HojaNuevaCita extends StatefulWidget {
  const _HojaNuevaCita({required this.dia, required this.citas});

  final DateTime dia;
  final List<Cita> citas;

  @override
  State<_HojaNuevaCita> createState() => _HojaNuevaCitaState();
}

class _HojaNuevaCitaState extends State<_HojaNuevaCita> {
  final _formKey = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _cliente = TextEditingController();
  final _telefono = TextEditingController();
  final _servicio = TextEditingController();
  DateTime? _hora;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_placa, _cliente, _telefono, _servicio]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Si la placa ya está registrada, completa cliente y teléfono.
  void _buscarPlaca(String placa) {
    final dueno = ClienteService.instancia.porPlaca(placa);
    if (dueno == null) return;
    _cliente.text = dueno.$1.nombre;
    _telefono.text = dueno.$1.telefono;
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    final hora = _hora;
    if (hora == null) return;
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final cita = await ejecutar(
      context,
      () => CitaService.instancia.agendar(Cita(
        fecha: hora,
        servicio: _servicio.text,
        placa: _placa.text,
        cliente: _cliente.text,
        telefono: _telefono.text,
      )),
      exito: 'Cita agendada a las ${formatoHora(hora)}',
    );
    if (cita != null) {
      navegador.pop();
    } else if (mounted) {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = CatalogoService.instancia.catalogo.config;
    final ahora = DateTime.now();
    final horarios = CitaService.horarios(widget.dia, widget.citas, config)
        .where((h) => h.$1.isAfter(ahora))
        .toList();
    return Form(
      key: _formKey,
      child: HojaContenido(
        kicker: fechaLarga(widget.dia),
        titulo: 'Nueva cita',
        children: [
          CampoTexto(
            label: 'Placa',
            controller: _placa,
            mayusculas: true,
            validator: Validadores.placa,
          ),
          Focus(
            onFocusChange: (f) {
              if (!f) _buscarPlaca(_placa.text);
            },
            child: CampoTexto(label: 'Cliente', controller: _cliente, validator: (v) => Validadores.requerido(v, 'el cliente')),
          ),
          CampoTexto(label: 'Teléfono', controller: _telefono, soloDigitos: true, validator: Validadores.telefonoContacto),
          CampoTexto(label: 'Servicio', controller: _servicio, validator: (v) => Validadores.requerido(v, 'el servicio')),
          Text('Hora (bahías libres)', style: Ind.kicker(size: 13, color: Ind.n700)),
          if (horarios.isEmpty)
            Text('No quedan horarios este día.', style: Ind.meta)
          else
            Wrap(spacing: 6, runSpacing: 2, children: [
              for (final (hora, libres) in horarios)
                if (libres > 0)
                  TagChip(
                    label: '${formatoHora(hora)} · $libres',
                    selected: _hora == hora,
                    onTap: () => setState(() => _hora = hora),
                  ),
            ]),
          PrimaryButton(
            label: _guardando ? 'Agendando…' : 'Agendar',
            onPressed: _guardando || _hora == null ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
