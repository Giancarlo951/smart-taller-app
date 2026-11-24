import 'entorno_stub.dart'
    if (dart.library.io) 'entorno_io.dart'
    as entorno;

/// true dentro de `flutter test`: ahí no hay plugins nativos ni red.
bool get enPruebas => entorno.enPruebas;
