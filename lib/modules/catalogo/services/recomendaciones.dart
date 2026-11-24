import '../models/servicio.dart';

/// Guía 14: sistema de recomendación ("También suelen pedir").
///
/// Como en la app de referencia: similitud de nombre (letras iniciales y
/// palabras en común) + categorías en común + popularidad.
class Recomendaciones {
  Recomendaciones._();

  /// Los [maximo] servicios más parecidos a [referencia] (sin ella y solo
  /// los disponibles), del más al menos parecido.
  static List<Servicio> para(
    Servicio referencia,
    Iterable<Servicio> catalogo, {
    int maximo = 4,
  }) {
    final puntuados = [
      for (final servicio in catalogo)
        if (servicio.id != referencia.id && servicio.disponible)
          (servicio, puntaje(referencia, servicio)),
    ]..removeWhere((p) => p.$2 <= 0);
    // A igual puntaje se respeta el orden del catálogo (sort no es estable).
    final orden = {for (final (i, s) in catalogo.indexed) s.id: i};
    puntuados.sort((a, b) {
      final porPuntaje = b.$2.compareTo(a.$2);
      return porPuntaje != 0
          ? porPuntaje
          : orden[a.$1.id]!.compareTo(orden[b.$1.id]!);
    });
    return [for (final (servicio, _) in puntuados.take(maximo)) servicio];
  }

  /// Servicios con intervalo de km que ya tocan para un vehículo con
  /// [kmActual], según el km de su último servicio de cada tipo.
  /// [ultimoKmPorServicio]: id del servicio → km cuando se hizo.
  static List<Servicio> mantenimientoPendiente(
    Iterable<Servicio> catalogo, {
    required int kmActual,
    required Map<String, int> ultimoKmPorServicio,
  }) => [
    for (final s in catalogo)
      if (s.disponible && s.intervaloKm > 0)
        if (ultimoKmPorServicio[s.id] case final ultimo?)
          if (kmActual - ultimo >= s.intervaloKm) s,
  ];

  /// Cuánto se parece [b] a [a]. 0 = nada en común.
  static double puntaje(Servicio a, Servicio b) {
    var total = similitud(a.nombre, b.nombre).toDouble();
    final comunes = a.categoriaIds.toSet().intersection(b.categoriaIds.toSet()).length;
    total += comunes * 2;
    // Desempata a favor de lo que más se pide, sin volverlo parecido.
    if (total > 0 && b.popular) total += 0.5;
    return total;
  }

  /// Letras iniciales en común (≥ 3) + 2 por cada palabra repetida. Las
  /// palabras vacías se quitan antes: casi todo empieza con "Cambio de…" y
  /// eso no dice nada ("Cambio de pastillas" y "Rectificado de discos").
  static int similitud(String a, String b) {
    final x = _significativo(a);
    final y = _significativo(b);
    var prefijo = 0;
    while (prefijo < x.length && prefijo < y.length && x[prefijo] == y[prefijo]) {
      prefijo++;
    }
    final palabras = _palabras(y);
    final repetidas = _palabras(x).where(palabras.contains).length;
    return (prefijo >= 3 ? prefijo : 0) + repetidas * 2;
  }

  static Set<String> _palabras(String texto) => {
    for (final palabra in texto.split(RegExp(r'[^a-z0-9]+')))
      if (palabra.length > 2 && !_vacias.contains(palabra)) palabra,
  };

  /// "Cambio de pastillas de freno" → "pastillas freno".
  static String _significativo(String texto) => [
    for (final palabra in _normalizar(texto).split(RegExp(r'[^a-z0-9]+')))
      if (palabra.length > 2 && !_vacias.contains(palabra)) palabra,
  ].join(' ');

  static const _vacias = {'con', 'del', 'las', 'los', 'una', 'para', 'cambio'};

  static String _normalizar(String texto) {
    const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
    final minusculas = texto.trim().toLowerCase();
    return [for (final c in minusculas.split('')) acentos[c] ?? c].join();
  }
}
