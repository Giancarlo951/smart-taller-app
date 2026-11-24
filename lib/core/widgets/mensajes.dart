import 'package:flutter/material.dart';

import '../../theme/industry_theme.dart';

/// SnackBar de confirmación o de error.
void mostrarMensaje(
  ScaffoldMessengerState? mensajero,
  String texto, {
  bool error = false,
}) {
  if (mensajero == null) return;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? const Color(0xFFB3261E) : Ind.a900,
      ),
    );
}

/// SnackBar con la acción "Deshacer" tras eliminar un elemento.
void mostrarDeshacer(
  ScaffoldMessengerState? mensajero,
  String texto,
  VoidCallback alDeshacer,
) {
  if (mensajero == null) return;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: Ind.a300,
          onPressed: alDeshacer,
        ),
      ),
    );
}

/// Texto del error para el usuario (StateError lleva el mensaje en español).
String mensajeError(Object error) {
  if (error is StateError) return error.message;
  final texto = '$error';
  if (texto.contains('permission-denied')) {
    return 'No tienes permiso para esta acción (revisa firestore.rules)';
  }
  if (texto.contains('unavailable') || texto.contains('network')) {
    return 'Sin conexión, inténtalo de nuevo';
  }
  return texto;
}
