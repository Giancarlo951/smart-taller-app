/// Validaciones de los formularios (estilo Guía Práctica N° 8):
/// cada función devuelve el mensaje de error o null si el valor es válido.
class Validadores {
  Validadores._();

  static String? requerido(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) return 'Ingrese $campo';
    return null;
  }

  static String? longitudMinima(String? valor, String campo, int minimo) {
    final error = requerido(valor, campo);
    if (error != null) return error;
    if (valor!.trim().length < minimo) {
      return 'Debe tener al menos $minimo caracteres';
    }
    return null;
  }

  /// Celular peruano: 9 dígitos y empieza con 9 (para avisar al cliente).
  static String? telefono(String? valor) {
    final error = requerido(valor, 'el teléfono');
    if (error != null) return error;
    final limpio = valor!.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^9\d{8}$').hasMatch(limpio)) {
      return 'El celular debe tener 9 dígitos y empezar con 9';
    }
    return null;
  }

  /// Celular o fijo de Junín (064 + 6 dígitos), para empresas.
  static String? telefonoContacto(String? valor) {
    final error = requerido(valor, 'el teléfono');
    if (error != null) return error;
    final limpio = valor!.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^9\d{8}$').hasMatch(limpio) ||
        RegExp(r'^0\d{8}$').hasMatch(limpio)) {
      return null;
    }
    return 'Ingrese un celular (9 dígitos) o un fijo con código (064…)';
  }

  /// Número de tarjeta de 16 dígitos.
  static String? tarjeta(String? valor) {
    final limpio = (valor ?? '').replaceAll(RegExp(r'\s'), '');
    if (limpio.isEmpty) return 'Ingrese el número de tarjeta';
    if (!RegExp(r'^\d{16}$').hasMatch(limpio)) {
      return 'La tarjeta debe tener 16 dígitos';
    }
    return null;
  }

  /// Número de operación de Yape/Plin (comprobante del cliente).
  static String? numeroOperacion(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isEmpty) return 'Ingrese el número de operación';
    if (!RegExp(r'^\d{6,12}$').hasMatch(limpio)) {
      return 'Debe tener entre 6 y 12 dígitos';
    }
    return null;
  }

  static String? seleccion(Object? valor, String campo) =>
      valor == null ? 'Seleccione $campo' : null;

  /// Correo de la cuenta del personal.
  static String? correo(String? valor) {
    final error = requerido(valor, 'su correo');
    if (error != null) return error;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor!.trim())) {
      return 'El correo no es válido';
    }
    return null;
  }

  /// Contraseña: Supabase Auth pide al menos 6 caracteres.
  static String? contrasena(String? valor) {
    if (valor == null || valor.isEmpty) return 'Ingrese su contraseña';
    if (valor.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  // ------------------------------------------------------------ Automotriz

  /// Placa peruana: 3 letras/números + 3 números (V2K-841, ABC-123).
  static String? placa(String? valor) {
    final error = requerido(valor, 'la placa');
    if (error != null) return error;
    final limpia = valor!.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[A-Z0-9]{3}\d{3}$').hasMatch(limpia)) {
      return 'La placa debe tener el formato ABC-123';
    }
    return null;
  }

  /// DNI: 8 dígitos.
  static String? dni(String? valor) {
    final error = requerido(valor, 'el DNI');
    if (error != null) return error;
    if (!RegExp(r'^\d{8}$').hasMatch(valor!.trim())) {
      return 'El DNI debe tener 8 dígitos';
    }
    return null;
  }

  /// RUC: 11 dígitos, empieza con 10, 15, 17 o 20 y su dígito verificador
  /// (módulo 11 de SUNAT) coincide.
  static String? ruc(String? valor) {
    final error = requerido(valor, 'el RUC');
    if (error != null) return error;
    final limpio = valor!.trim();
    if (!RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(limpio)) {
      return 'El RUC debe tener 11 dígitos y empezar con 10, 15, 17 o 20';
    }
    if (!rucValido(limpio)) return 'El RUC no es válido';
    return null;
  }

  /// Dígito verificador del RUC (factores 5 4 3 2 7 6 5 4 3 2).
  static bool rucValido(String ruc) {
    if (!RegExp(r'^\d{11}$').hasMatch(ruc)) return false;
    const factores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    var suma = 0;
    for (var i = 0; i < 10; i++) {
      suma += int.parse(ruc[i]) * factores[i];
    }
    var digito = 11 - (suma % 11);
    if (digito == 10) digito = 0;
    if (digito == 11) digito = 1;
    return digito == int.parse(ruc[10]);
  }

  /// DNI (persona) o RUC (empresa) según la cantidad de dígitos.
  static String? documento(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isEmpty) return 'Ingrese el DNI o RUC';
    return limpio.length == 11 ? ruc(limpio) : dni(limpio);
  }

  /// Kilometraje del vehículo al ingresar.
  static String? kilometraje(String? valor, {int? anterior}) {
    final error = requerido(valor, 'el kilometraje');
    if (error != null) return error;
    final km = int.tryParse(valor!.replaceAll(RegExp(r'[\s,.]'), ''));
    if (km == null || km < 0) return 'Ingrese un kilometraje válido';
    if (km > 2000000) return 'El kilometraje es demasiado alto';
    if (anterior != null && km < anterior) {
      return 'No puede ser menor al último registrado ($anterior km)';
    }
    return null;
  }

  /// Año del vehículo (1950 hasta el próximo año).
  static String? anio(String? valor, {DateTime? hoy}) {
    final error = requerido(valor, 'el año');
    if (error != null) return error;
    final anio = int.tryParse(valor!.trim());
    final maximo = (hoy ?? DateTime.now()).year + 1;
    if (anio == null || anio < 1950 || anio > maximo) {
      return 'Ingrese un año entre 1950 y $maximo';
    }
    return null;
  }

  /// Precio en soles ("148" o "148.50"), mayor que cero.
  static String? precio(String? valor) {
    final error = requerido(valor, 'el precio');
    if (error != null) return error;
    final monto = double.tryParse(valor!.replaceAll(',', '.').trim());
    if (monto == null || monto <= 0) return 'Ingrese un precio mayor a 0';
    if (monto > 100000) return 'El precio es demasiado alto';
    return null;
  }

  /// Unidades enteras (stock, cantidad a ingresar).
  static String? entero(String? valor, String campo, {int minimo = 0}) {
    final error = requerido(valor, campo);
    if (error != null) return error;
    final numero = int.tryParse(valor!.trim());
    if (numero == null || numero < minimo) {
      return 'Ingrese un número entero desde $minimo';
    }
    return null;
  }
}
