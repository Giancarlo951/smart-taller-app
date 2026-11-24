import 'dart:async';
import 'dart:io';

/// Hay internet si una petición corta responde. El Wi-Fi encendido no basta:
/// el teléfono puede estar asociado a la red y sin salida.
Future<bool> hayInternet() async {
  final cliente = HttpClient();
  cliente.connectionTimeout = const Duration(seconds: 4);
  try {
    final peticion = await cliente.getUrl(
      Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
    );
    final respuesta = await peticion.close().timeout(
      const Duration(seconds: 4),
    );
    await respuesta.drain<void>();
    return respuesta.statusCode == 204 || respuesta.statusCode == 200;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  } finally {
    cliente.close(force: true);
  }
}
