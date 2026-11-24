import 'dart:io';

/// `flutter test` define FLUTTER_TEST en el entorno del proceso.
bool get enPruebas => Platform.environment.containsKey('FLUTTER_TEST');
