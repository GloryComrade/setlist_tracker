import 'dart:convert' show base64Url, utf8;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../auth/auth_service.dart';
import 'api_client.dart';
import 'backend_config.dart';
import 'browser_address.dart';

/// Opens [url] in a sign-in sheet and returns the address it finished on.
typedef OpenSignInSheet = Future<String> Function(String url, String scheme);

/// Sign-in through the Cloudflare Worker (docs/cloudflare-api.md).
///
/// Google, and Apple on the web, use the Worker's browser flow: it ends on
/// a return address carrying a one-time `login_code`, which is exchanged
/// for a session. On the web the page itself leaves and comes back
/// ([completeWebSignIn] picks the code up at startup). On the iPhone the
/// flow runs in ASWebAuthenticationSession (flutter_web_auth_2). Apple on
/// the iPhone uses Apple's own sheet instead.
class CloudflareAuthService implements AuthService {
  CloudflareAuthService(
    this._api, {
    bool? isWeb,
    bool? onIPhone,
    OpenSignInSheet? openSheet,
    Uri Function()? currentPage,
  }) : _isWeb = isWeb ?? kIsWeb,
       _onIPhone =
           onIPhone ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
       _openSheet = openSheet ?? _flutterWebAuth,
       _page = currentPage ?? (() => Uri.base);

  final ApiClient _api;
  final bool _isWeb;
  final bool _onIPhone;
  final OpenSignInSheet _openSheet;
  final Uri Function() _page;

  static Future<String> _flutterWebAuth(String url, String scheme) =>
      FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: scheme);

  @override
  bool get available => true;

  @override
  PassHolder? get current => _holder(_api.session);

  @override
  Stream<PassHolder?> changes() => _api.sessionChanges
      .map(_holder)
      // A token refresh changes the session, not who holds the Pass.
      .distinct(
        (a, b) => a?.id == b?.id && a?.name == b?.name && a?.email == b?.email,
      );

  static PassHolder? _holder(ApiSession? s) => s == null
      ? null
      : PassHolder(id: s.user.id, name: s.user.name, email: s.user.email);

  /// The web app comes back to the page it was opened from, minus any
  /// query or in-app route, so it works on localhost and the Worker alike.
  String get _webReturn {
    final here = _page();
    return Uri(
      scheme: here.scheme,
      host: here.host,
      port: here.hasPort ? here.port : null,
      path: here.path,
    ).toString();
  }

  String _startUrl(String provider, String returnTo) =>
      Uri.parse('${_api.baseUrl}/api/auth/$provider/start')
          .replace(queryParameters: {'return': returnTo})
          .toString();

  @override
  Future<void> signInWithGoogle() => _browserSignIn('google');

  @override
  Future<void> signInWithApple() =>
      _onIPhone ? _signInWithAppleNatively() : _browserSignIn('apple');

  Future<void> _browserSignIn(String provider) async {
    if (_isWeb) {
      // Leaves the app; completeWebSignIn finishes when the page comes back.
      openInThisTab(_startUrl(provider, _webReturn));
      return;
    }
    final String result;
    try {
      result = await _openSheet(
        _startUrl(provider, nativeAuthRedirect),
        nativeAuthScheme,
      );
    } on PlatformException catch (e) {
      // Closing the sheet isn't an error worth a message.
      if (e.code == 'CANCELED') return;
      rethrow;
    }
    final query = Uri.parse(result).queryParameters;
    final code = query['login_code'];
    if (code == null) {
      throw ApiException(400, query['login_error'] ?? 'no_login_code');
    }
    await exchange(code);
  }

  /// Trades a one-time login code for a session and signs in.
  Future<void> exchange(String code) async {
    final json = await _api.post(
      '/api/auth/exchange',
      body: {'code': code},
      auth: false,
    );
    await _api.setSession(ApiSession.fromJson(json));
  }

  /// Web startup: when the page has just come back from a sign-in page with
  /// `login_code` (or `login_error`) in its address, exchanges the code and
  /// takes both out of the address bar. Does nothing anywhere else.
  Future<void> completeWebSignIn() async {
    if (!_isWeb) return;
    final cleaned = await completeSignInFrom(_page());
    if (cleaned != null) replaceAddress(cleaned.toString());
  }

  /// The part of [completeWebSignIn] that doesn't touch the browser.
  /// Returns [page] without the sign-in parameters, or null when it had
  /// none. A failed exchange is logged, not thrown: the runner lands signed
  /// out and can try again.
  Future<Uri?> completeSignInFrom(Uri page) async {
    final query = page.queryParameters;
    final code = query['login_code'];
    final error = query['login_error'];
    if (code == null && error == null) return null;
    if (code != null) {
      try {
        await exchange(code);
      } catch (e) {
        debugPrint('Sign-in not finished: $e');
      }
    } else {
      debugPrint('Sign-in refused: $error');
    }
    final rest = {...query}
      ..remove('login_code')
      ..remove('login_error');
    return Uri(
      scheme: page.scheme,
      host: page.host,
      port: page.hasPort ? page.port : null,
      path: page.path,
      queryParameters: rest.isEmpty ? null : rest,
      fragment: page.hasFragment ? page.fragment : null,
    );
  }

  /// Apple's own sheet (Face ID), then the ID token goes to the Worker.
  /// Apple gets the SHA-256 of a one-time nonce and the Worker the raw
  /// nonce, so the token can't be replayed.
  Future<void> _signInWithAppleNatively() async {
    final rawNonce = _rawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const ApiException(400, 'bad_request', 'Apple sent no ID token.');
    }
    await signInWithAppleCredential(
      identityToken: idToken,
      authorizationCode: credential.authorizationCode,
      rawNonce: rawNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  /// Sends what Apple's sheet returned to the Worker. Apple shares the name
  /// only on the very first sign-in, so it goes along for the Backstage
  /// Pass. Public for tests.
  Future<void> signInWithAppleCredential({
    required String identityToken,
    required String authorizationCode,
    required String rawNonce,
    String? givenName,
    String? familyName,
  }) async {
    final json = await _api.post(
      '/api/auth/apple/native',
      body: {
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
        'rawNonce': rawNonce,
        'givenName': givenName,
        'familyName': familyName,
      },
      auth: false,
    );
    await _api.setSession(ApiSession.fromJson(json));
  }

  static String _rawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  @override
  Future<void> signOut() async {
    final s = _api.session;
    if (s != null) {
      try {
        await _api.post(
          '/api/auth/signout',
          body: {'refreshToken': s.refreshToken},
          auth: false,
        );
      } catch (e) {
        // Offline or already gone: this device forgets the session anyway.
        debugPrint('Sign-out not sent: $e');
      }
    }
    await _api.clearSession();
  }

  @override
  Future<void> deleteAccount() async {
    // The Worker deletes the account and every row of it (and revokes
    // Apple's tokens), then this device forgets the session.
    await _api.delete('/api/me');
    await _api.clearSession();
  }
}
