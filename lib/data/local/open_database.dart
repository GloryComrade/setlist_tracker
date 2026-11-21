/// Opens the on-device database.
///
/// Web uses the browser's IndexedDB and iOS uses a file in the app's documents
/// folder. Dart picks the right file at compile time, so web-only code never
/// ends up in the iOS build.
library;

export 'open_database_io.dart'
    if (dart.library.js_interop) 'open_database_web.dart';
