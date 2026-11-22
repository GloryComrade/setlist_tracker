import 'package:flutter/foundation.dart' show kIsWeb;
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

  @override
  Future<void> signInWithGoogle() =>
      _client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect);

  @override
  Future<void> signInWithApple() =>
      _client.auth.signInWithOAuth(OAuthProvider.apple, redirectTo: _redirect);

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
