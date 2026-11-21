import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

int _counter = 0;

/// Loads [uri] as a <script> with a `callback=` parameter and returns the JSON
/// it hands back, as a string.
Future<String> fetchJsonp(Uri uri) {
  final completer = Completer<String>();
  final name = '__setlistJsonp${_counter++}';
  final script = web.HTMLScriptElement();

  void cleanup() {
    script.remove();
    globalContext.delete(name.toJS);
  }

  globalContext.setProperty(
    name.toJS,
    ((JSAny? data) {
      final json = (globalContext['JSON'] as JSObject)
          .callMethod<JSString>('stringify'.toJS, data)
          .toDart;
      cleanup();
      if (!completer.isCompleted) completer.complete(json);
    }).toJS,
  );
  script.onerror = ((web.Event _) {
    cleanup();
    if (!completer.isCompleted) {
      completer.completeError(Exception('Song search could not load'));
    }
  }).toJS;
  script.src = uri.replace(queryParameters: {
    ...uri.queryParameters,
    'callback': name,
  }).toString();
  web.document.head!.append(script);

  return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
    cleanup();
    throw TimeoutException('Song search timed out');
  });
}
