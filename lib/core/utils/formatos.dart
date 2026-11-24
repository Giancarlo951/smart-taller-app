/// Convierte la fecha de Postgres (texto ISO 8601, timestamptz) a la hora
/// local del celular.
DateTime leerFecha(dynamic valor) {
  if (valor is DateTime) return valor.toLocal();
  if (valor is String && valor.isNotEmpty) {
    return DateTime.tryParse(valor)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

/// Fecha para guardar en Postgres (UTC con zona: no se corre la hora).
String fechaIso(DateTime fecha) => fecha.toUtc().toIso8601String();

/// Igual que [leerFecha] pero null si no hay valor.
DateTime? leerFechaOpcional(dynamic valor) =>
    valor == null ? null : leerFecha(valor);

/// Lee una lista de textos guardada en la base (JSON).
List<String> leerListaTextos(dynamic valor) =>
    valor is List ? valor.map((e) => e.toString()).toList() : <String>[];

/// Lee un mapa anidado guardado en Firestore.
Map<String, dynamic> leerMapa(dynamic valor) =>
    valor is Map ? Map<String, dynamic>.from(valor) : <String, dynamic>{};

/// Lee una lista de mapas (líneas, historial...).
List<Map<String, dynamic>> leerListaMapas(dynamic valor) => valor is List
    ? valor.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : <Map<String, dynamic>>[];

double leerDouble(dynamic valor) => valor is num ? valor.toDouble() : 0;

int leerInt(dynamic valor) => valor is num ? valor.toInt() : 0;

/// 07/10/2026
String formatoFecha(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

/// 14:05
String formatoHora(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';

/// 07/10/2026 14:05
String formatoFechaHora(DateTime fecha) =>
    '${formatoFecha(fecha)} ${formatoHora(fecha)}';

/// 1,250.50 (sin símbolo de moneda).
String formatoMonto(double valor) {
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final entero = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${valor < 0 ? '-' : ''}$entero.${partes[1]}';
}

/// S/ 1,250.50
String formatoMoneda(double valor) {
  final monto = formatoMonto(valor);
  return monto.startsWith('-') ? '-S/ ${monto.substring(1)}' : 'S/ $monto';
}

/// Todo monto se guarda en céntimos (int): 28500 -> "S/ 285.00".
String formatoCentimos(int centimos) => formatoMoneda(centimos / 100);

/// 28500 -> "285.00"
String montoCentimos(int centimos) => formatoMonto(centimos / 100);

/// 78420 -> "78,420 km"
String formatoKm(int km) =>
    '${km.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} km';

/// "1 servicio" / "3 servicios"
String plural(int cantidad, String singular, String enPlural) =>
    '$cantidad ${cantidad == 1 ? singular : enPlural}';

/// Tiempo relativo en español: "Justo ahora", "Hace 5 min", "Hace 2 h"...
String tiempoRelativo(DateTime fecha, {DateTime? ahora}) {
  final diferencia = (ahora ?? DateTime.now()).difference(fecha);
  if (diferencia.inSeconds < 60) return 'Justo ahora';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'Ayer';
  if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays} días';
  return formatoFecha(fecha);
}

/// Iniciales para el avatar: "Rosa Paucar" -> "RP".
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (partes.isEmpty) return '';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

String capitalizar(String texto) =>
    texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';

/// Placa en mayúsculas con guion: "v2k841" -> "V2K-841".
String normalizarPlaca(String placa) {
  final limpia = placa.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (limpia.length == 6) return '${limpia.substring(0, 3)}-${limpia.substring(3)}';
  return limpia;
}

/// Número correlativo del comprobante: 248 -> "00248" (como B001-00248).
String correlativo(int numero, {int digitos = 5}) =>
    numero.toString().padLeft(digitos, '0');

/// Lunes 14 de septiembre
String fechaLarga(DateTime fecha) {
  const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${dias[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}';
}
