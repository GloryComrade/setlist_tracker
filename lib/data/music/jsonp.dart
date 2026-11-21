/// JSONP fallback for the song search on web, used only if the browser
/// blocks a normal request to the search service. Native builds never use it.
library;

export 'jsonp_stub.dart' if (dart.library.js_interop) 'jsonp_web.dart';
