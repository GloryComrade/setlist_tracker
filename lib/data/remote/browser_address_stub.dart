/// Native builds sign in through flutter_web_auth_2 instead.
void openInThisTab(String url) =>
    throw UnsupportedError('Only the web app leaves the page to sign in');

/// Nothing to tidy without an address bar.
void replaceAddress(String url) {}
