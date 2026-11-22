import 'package:web/web.dart' as web;

/// Leaves the app for [url] in the same tab (the sign-in page comes back).
void openInThisTab(String url) => web.window.location.assign(url);

/// Changes the address bar without reloading or adding a history entry.
void replaceAddress(String url) =>
    web.window.history.replaceState(null, '', url);
