/// Signing in for the Backstage Pass.
///
/// The UI only knows [AuthService]. [CloudflareAuthService] is the real one;
/// [NoAuthService] is used when the build has no backend settings, so the
/// app stays local-only.
library;

/// The signed-in runner.
class PassHolder {
  const PassHolder({required this.id, this.name, this.email});
  final String id;
  final String? name;
  final String? email;

  /// What to call them on the Backstage Pass.
  String get displayName => name ?? email ?? 'Signed in';
}

abstract class AuthService {
  /// False when this build has no backend: sign-in is hidden.
  bool get available;

  PassHolder? get current;

  /// Emits whenever someone signs in or out.
  Stream<PassHolder?> changes();

  /// Opens Google's sign-in. On the web this leaves the page and comes back.
  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  /// Deletes the account and everything synced to it. Can't be undone.
  Future<void> deleteAccount();
}

class NoAuthService implements AuthService {
  const NoAuthService();
  @override
  bool get available => false;
  @override
  PassHolder? get current => null;
  @override
  Stream<PassHolder?> changes() => const Stream.empty();
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount() async {}
}
