import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/mensajes.dart';
import '../theme/blueprint.dart';
import '../theme/industry_theme.dart';
import 'ind_field.dart';

/// Ejecuta [accion] y muestra el resultado en un SnackBar (o el error).
Future<T?> ejecutar<T>(
  BuildContext context,
  Future<T> Function() accion, {
  String? exito,
}) async {
  final mensajero = ScaffoldMessenger.maybeOf(context);
  try {
    final resultado = await accion();
    if (exito != null) mostrarMensaje(mensajero, exito);
    return resultado;
  } catch (e) {
    mostrarMensaje(mensajero, mensajeError(e), error: true);
    return null;
  }
}

/// Hoja inferior con el estilo del sistema (blanca, esquinas superiores
/// redondeadas y tirador, sobre el teclado). En PC no pasa de 640 px de
/// ancho y queda centrada.
Future<T?> mostrarHoja<T>(BuildContext context, Widget contenido) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (hoja) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(hoja).bottom),
      child: contenido,
    ),
  );
}

/// Contenido de una hoja: texto pequeño + título y bloques con separación.
class HojaContenido extends StatelessWidget {
  const HojaContenido({super.key, required this.kicker, required this.titulo, required this.children});

  final String kicker;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kicker.isNotEmpty) Text(kicker, style: Ind.kicker()),
          Text(titulo, style: Ind.heading(21, height: 1.2)),
          const SizedBox(height: 16),
          for (final (i, hijo) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            hijo,
          ],
        ],
      ),
    );
  }
}

/// Campo de texto con etiqueta del sistema.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.teclado,
    this.ayuda,
    this.soloDigitos = false,
    this.mayusculas = false,
    this.lineas = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? teclado;
  final String? ayuda;
  final bool soloDigitos;
  final bool mayusculas;
  final int lineas;

  @override
  Widget build(BuildContext context) {
    return IndField(
      label: label,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: soloDigitos ? TextInputType.number : teclado,
        textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.sentences,
        inputFormatters: soloDigitos ? [FilteringTextInputFormatter.digitsOnly] : null,
        minLines: lineas,
        maxLines: lineas,
        style: Ind.body(14, height: 1.3),
        decoration: InputDecoration(hintText: ayuda),
      ),
    );
  }
}

/// Fila "concepto ............ S/ 0.00".
class FilaMonto extends StatelessWidget {
  const FilaMonto(this.concepto, this.valor, {super.key, this.resaltar = false});

  final String concepto;
  final String valor;
  final bool resaltar;

  @override
  Widget build(BuildContext context) {
    final estilo = resaltar ? Ind.heading(17) : Ind.body(13, height: 1.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(concepto, style: estilo)),
          const SizedBox(width: 12),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

/// Lista vacía o sin resultados.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.titulo, this.ayuda = ''});

  final String titulo;
  final String ayuda;

  @override
  Widget build(BuildContext context) {
    return BlueprintBox(
      padding: const EdgeInsets.symmetric(horizontal: Ind.s6, vertical: 28),
      child: Column(
        children: [
          const IconoMosaico(Icons.inbox_outlined, tamano: 52),
          const SizedBox(height: 12),
          Text(titulo, style: Ind.heading(16), textAlign: TextAlign.center),
          if (ayuda.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ayuda, style: Ind.body(13, color: Ind.muted), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Selector segmentado (dos o tres opciones excluyentes): fondo gris y la
/// opción elegida en blanco con texto azul.
class Segmentos<T> extends StatelessWidget {
  const Segmentos({super.key, required this.opciones, required this.valor, required this.alCambiar});

  final List<(T, String)> opciones;
  final T valor;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Ind.n100, borderRadius: BorderRadius.circular(Ind.radiusMd)),
      child: Row(
        children: [
          for (final (opcion, etiqueta) in opciones)
            Expanded(
              child: Semantics(
                button: true,
                selected: opcion == valor,
                child: GestureDetector(
                  onTap: () => alCambiar(opcion),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: opcion == valor ? Ind.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: opcion == valor ? Ind.shadowSm : null,
                    ),
                    child: Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ind.heading(13.5, height: 1, color: opcion == valor ? Ind.accent : Ind.n600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// − cantidad + (mínimo 1).
class SelectorCantidad extends StatelessWidget {
  const SelectorCantidad({super.key, required this.valor, required this.alCambiar, this.maximo = 99});

  final int valor;
  final ValueChanged<int> alCambiar;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    // "−" claro y "+" azul sólido, ambos cuadrados redondeados de 34 px.
    Widget boton(IconData icono, String etiqueta, VoidCallback? accion, {bool principal = false}) => Semantics(
      label: etiqueta,
      button: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 34,
        child: IconButton(
          onPressed: accion,
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: principal ? Ind.accent : Ind.a100,
            foregroundColor: principal ? Colors.white : Ind.a800,
            disabledBackgroundColor: Ind.n100,
            disabledForegroundColor: Ind.n400,
          ),
          icon: Icon(icono),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton(Icons.remove_rounded, 'Quitar uno', valor > 1 ? () => alCambiar(valor - 1) : null),
        SizedBox(width: 36, child: Text('$valor', textAlign: TextAlign.center, style: Ind.heading(16))),
        boton(Icons.add_rounded, 'Agregar uno', valor < maximo ? () => alCambiar(valor + 1) : null, principal: true),
      ],
    );
  }
}

/// Diálogo de confirmación. true = confirmó.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: Text(accion)),
      ],
    ),
  );
  return respuesta ?? false;
}

/// Pide un texto en un diálogo (motivo de anulación, cantidad...).
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  required String accion,
  String? Function(String?)? validator,
  bool soloDigitos = false,
  String inicial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoTexto(
      titulo: titulo,
      etiqueta: etiqueta,
      accion: accion,
      validator: validator,
      soloDigitos: soloDigitos,
      inicial: inicial,
    ),
  );
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.accion,
    this.validator,
    this.soloDigitos = false,
    this.inicial = '',
  });

  final String titulo;
  final String etiqueta;
  final String accion;
  final String? Function(String?)? validator;
  final bool soloDigitos;
  final String inicial;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _formKey = GlobalKey<FormState>();
  late final _texto = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: CampoTexto(
          label: widget.etiqueta,
          controller: _texto,
          validator: widget.validator,
          soloDigitos: widget.soloDigitos,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.pop(context, _texto.text.trim());
          },
          child: Text(widget.accion),
        ),
      ],
    );
  }
}
