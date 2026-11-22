import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import 'backend_config.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);
  final SupabaseClient _client;

  @override
  bool get available => true;

  @override
  PassHolder? get current => _holder(_client.auth.currentUser);

  @override
  Stream<PassHolder?> changes() =>
      _client.auth.onAuthStateChange.map((s) => _holder(s.session?.user));

  PassHolder? _holder(User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    final name = meta['full_name'] ?? meta['name'];
    return PassHolder(
      id: u.id,
      name: name is String && name.isNotEmpty ? name : null,
      email: u.email,
    );
  }

  /// The web app comes back to the page it was opened from (minus any
  /// in-app route), so it works on localhost and on GitHub Pages alike.
  String get _redirect {
    if (!kIsWeb) return nativeAuthRedirect;
    final here = Uri.base;
    return Uri(
      scheme: here.scheme,
      host: here.host,
      port: here.hasPort ? here.port : null,
      path: here.path,
    ).toString();
  }

  /// On the iPhone the sign-in page opens in Safari, which hands the runner
  /// back to the app through [nativeAuthRedirect] (Supabase's recommended
  /// setup). On the web it replaces the current page.
  LaunchMode get _launchMode =>
      kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;

  static bool get _onIPhone =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> signInWithGoogle() => _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: _redirect,
    authScreenLaunchMode: _launchMode,
  );

  @override
  Future<void> signInWithApple() async {
    if (_onIPhone) return _signInWithAppleNatively();
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirect,
      authScreenLaunchMode: _launchMode,
    );
  }

  /// Apple's own sheet (Face ID), then the ID token is traded for a
  /// Supabase session. Apple gets the SHA-256 of a one-time nonce and
  /// Supabase the raw nonce, so the token can't be replayed.
  Future<void> _signInWithAppleNatively() async {
    final rawNonce = _client.auth.generateRawNonce();
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
      // Closing the sheet isn't an error worth a message.
      if (e.code == AuthorizationErrorCode.canceled) return;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sent no ID token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    // Apple shares the name only on the very first sign-in and it isn't in
    // the token, so keep it on the account for the Backstage Pass.
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((p) => p.isNotEmpty).join(' ');
    if (name.isEmpty) return;
    try {
      await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
    } on AuthException {
      // Already signed in; the Pass falls back to the email.
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    // A database function removes the account; the tables' foreign keys
    // delete every synced row with it (supabase/migrations).
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }
}
