import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Downloads [text] as [fileName] through a temporary link.
Future<bool> saveTextFile(String fileName, String text, String mimeType) async {
  // A byte-order mark so Excel reads accented artist names as UTF-8.
  final bytes = utf8.encode('﻿$text');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
