import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// URL y clave pública del proyecto (Project Settings → API). Se pasan al
/// compilar para no dejarlas escritas en el código:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_...
/// Sin ellas la app trabaja en modo local con los datos de ejemplo.
/// Nunca va aquí la clave service_role.
const urlSupabase = String.fromEnvironment('SUPABASE_URL');
const claveSupabase = String.fromEnvironment('SUPABASE_KEY');

bool _conectado = false;

/// true si Supabase se inicializó; si no, la app trabaja con datos locales
/// (equivale a `hayFirebase` de la app de referencia).
bool get haySupabase => _conectado;

SupabaseClient get supabase => Supabase.instance.client;

/// Conecta Supabase. Devuelve el error si no se pudo (la app sigue con los
/// datos locales) o null si se conectó.
Future<Object?> iniciarSupabase() async {
  if (urlSupabase.isEmpty || claveSupabase.isEmpty) {
    return 'Sin SUPABASE_URL ni SUPABASE_KEY';
  }
  try {
    await Supabase.initialize(url: urlSupabase, publishableKey: claveSupabase);
    _conectado = true;
    return null;
  } catch (e) {
    return e;
  }
}

/// Mensaje en español de un error de la base. Los `raise exception` de las
/// funciones SQL (código P0001) ya vienen redactados para el usuario.
String mensajePostgrest(PostgrestException e) => switch (e.code) {
  '42501' => 'No tienes permiso para esta acción',
  '23505' => e.message.contains('numero_documento')
      ? 'Ya existe un cliente con ese documento'
      : 'Ese registro ya existe',
  '23514' => 'Un dato no cumple las reglas de la base (${e.message})',
  _ => e.message,
};

/// Ejecuta una operación remota con los errores convertidos a StateError
/// (mensaje en español) y un tiempo máximo de espera.
Future<T> enSupabase<T>(Future<T> Function() accion, {Duration espera = const Duration(seconds: 15)}) async {
  try {
    return await accion().timeout(espera);
  } on PostgrestException catch (e) {
    throw StateError(mensajePostgrest(e));
  } on TimeoutException {
    throw StateError('Sin conexión, inténtalo de nuevo');
  }
}

/// Llama a una función SQL (RPC) y devuelve su resultado JSON.
Future<Map<String, dynamic>> rpcMapa(String funcion, Map<String, dynamic> params) async {
  final resultado = await enSupabase(() => supabase.rpc(funcion, params: params));
  if (resultado is Map) return Map<String, dynamic>.from(resultado);
  throw StateError('Respuesta inesperada de $funcion');
}

/// CRUD genérico sobre una tabla de Supabase (equivale a
/// RepositorioFirestore de la app de referencia). Cada módulo lo extiende
/// indicando cómo convertir su modelo.
abstract class RepositorioSupabase<T> {
  RepositorioSupabase(this.tabla, {this.clave = 'id'});

  final String tabla;

  /// Columna de la clave primaria.
  final String clave;

  T desdeMapa(Map<String, dynamic> fila);

  /// Columnas a guardar (sin la clave si la genera la base).
  Map<String, dynamic> aMapa(T item);

  /// Lectura en tiempo real (READ).
  Stream<List<T>> listar() =>
      supabase.from(tabla).stream(primaryKey: [clave]).map((filas) => filas.map(desdeMapa).toList());

  /// CREATE: la base genera el id y se devuelve.
  Future<String> crear(T item) async {
    final fila = await supabase.from(tabla).insert(aMapa(item)).select(clave).single();
    return '${fila[clave]}';
  }

  /// UPDATE
  Future<void> actualizar(String id, T item) => supabase.from(tabla).update(aMapa(item)).eq(clave, id);

  /// DELETE
  Future<void> eliminar(String id) => supabase.from(tabla).delete().eq(clave, id);

  /// Deshacer eliminación: vuelve a crear la fila con su id.
  Future<void> restaurar(String id, T item) =>
      supabase.from(tabla).upsert({...aMapa(item), clave: id});
}
