/// Hands the runner a text file. On web it downloads; elsewhere it returns
/// false so the caller can fall back (the iPhone build will use the share
/// sheet in Phase 5).
library;

export 'save_text_file_stub.dart'
    if (dart.library.js_interop) 'save_text_file_web.dart';
