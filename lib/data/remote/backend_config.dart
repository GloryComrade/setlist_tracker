/// Build-time settings for the cloud backend (the Cloudflare Worker in
/// backend/, contract in docs/cloudflare-api.md).
///
/// Nothing secret lives in the code. Pass the Worker's address when
/// building:
///
///     flutter run -d chrome --dart-define=API_URL=http://localhost:8787
///     flutter build ios --dart-define=API_URL=https://setlist-tracker.<account>.workers.dev
///     flutter build web --dart-define=API_URL=same-origin
///
/// `same-origin` (web only) means the address the page was loaded from: the
/// Worker serves the website and the API together. Without API_URL the app
/// runs exactly as before, local-only, with no sign-in.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_client.dart';

const apiUrlSetting = String.fromEnvironment('API_URL');

/// The Worker's address without a trailing slash, or null in local-only
/// builds.
final String? apiBaseUrl = resolveApiBaseUrl(
  apiUrlSetting,
  isWeb: kIsWeb,
  page: Uri.base,
);

/// True when this build can sign in and sync.
bool get backendConfigured => apiBaseUrl != null;

/// Sign in with Apple needs a paid Apple Developer account, so it stays off
/// until that is set up: add --dart-define=APPLE_SIGN_IN=true.
const appleSignInEnabled = bool.fromEnvironment('APPLE_SIGN_IN');

/// Where the sign-in page sends the iPhone app back to. The Worker allows
/// exactly this address (its NATIVE_REDIRECT setting), and
/// ASWebAuthenticationSession catches it by its scheme.
const nativeAuthRedirect = 'com.glorycomrade.setlisttracker://login-callback';

/// The scheme of [nativeAuthRedirect].
const nativeAuthScheme = 'com.glorycomrade.setlisttracker';
