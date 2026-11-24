// El navegador no tiene dart:io. Este archivo solo se compila en web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

/// En el navegador una petición no-cors confirma que la red respondió.
Future<bool> hayInternet() async {
  if (html.window.navigator.onLine == false) return false;
  try {
    await html.window
        .fetch('https://connectivitycheck.gstatic.com/generate_204', {
          'mode': 'no-cors',
          'cache': 'no-store',
        })
        .timeout(const Duration(seconds: 4));
    return true;
  } catch (_) {
    return false;
  }
}
