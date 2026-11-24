import 'comprobacion_stub.dart'
    if (dart.library.io) 'comprobacion_io.dart'
    if (dart.library.html) 'comprobacion_web.dart'
    as comprobacion;

/// Acceso real a internet en el teléfono o en el navegador.
Future<bool> hayInternet() => comprobacion.hayInternet();
