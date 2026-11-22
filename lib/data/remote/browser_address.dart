/// The browser's address bar, for the web sign-in round trip. Native builds
/// have no address bar and never call these.
library;

export 'browser_address_stub.dart'
    if (dart.library.js_interop) 'browser_address_web.dart';
