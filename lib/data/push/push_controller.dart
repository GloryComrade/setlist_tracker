import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_controller.dart';
import 'push_api.dart';
import 'push_bridge.dart';

final pushBridgeProvider = Provider<PushBridge>((ref) => const NoPushBridge());
final pushApiProvider = Provider<PushApi?>((ref) => null);

class PushState {
  const PushState({
    this.permission = PushPermission.unsupported,
    this.token,
    this.nudgeHidden = false,
  });

  final PushPermission permission;

  /// This phone's token, once registered with the server.
  final String? token;

  /// "Not now" on the Crew screen's card, until the app is opened again.
  final bool nudgeHidden;

  bool get supported => permission != PushPermission.unsupported;
  bool get allowed => permission == PushPermission.authorized;

  PushState copyWith({
    PushPermission? permission,
    String? token,
    bool? nudgeHidden,
  }) => PushState(
    permission: permission ?? this.permission,
    token: token ?? this.token,
    nudgeHidden: nudgeHidden ?? this.nudgeHidden,
  );
}

final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);

/// Keeps the server's list of this runner's phones current: registers the
/// phone after sign-in once notifications are allowed, and forgets it on
/// sign-out ([forgetDevice], run by [SyncController.signOut]).
class PushController extends Notifier<PushState> {
  StreamSubscription<PushToken>? _sub;

  @override
  PushState build() {
    final bridge = ref.watch(pushBridgeProvider);
    final api = ref.watch(pushApiProvider);
    final holderId = ref.watch(
      syncControllerProvider.select((s) => s.holder?.id),
    );
    if (!bridge.supported || api == null) return const PushState();

    _sub = bridge.tokens.listen((t) => unawaited(_send(api, t)));
    final remove = ref
        .read(syncControllerProvider.notifier)
        .beforeSignOut(forgetDevice);
    ref.onDispose(() {
      _sub?.cancel();
      remove();
    });
    if (holderId != null) unawaited(_check(bridge));
    return const PushState(permission: PushPermission.notDetermined);
  }

  Future<void> _check(PushBridge bridge) async {
    try {
      final p = await bridge.permission();
      state = state.copyWith(permission: p);
      if (p == PushPermission.authorized) await bridge.register();
    } catch (e) {
      debugPrint('Push check failed: $e');
    }
  }

  Future<void> _send(PushApi api, PushToken t) async {
    if (ref.read(syncControllerProvider).holder == null) return;
    try {
      await api.registerDevice(t.token, sandbox: t.sandbox);
      state = state.copyWith(token: t.token);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Shows the iOS prompt. True when notifications are allowed.
  Future<bool> requestPermission() async {
    final bridge = ref.read(pushBridgeProvider);
    if (!bridge.supported) return false;
    final ok = await bridge.requestPermission();
    state = state.copyWith(
      permission: ok ? PushPermission.authorized : PushPermission.denied,
    );
    if (ok) await bridge.register();
    return ok;
  }

  void hideNudge() => state = state.copyWith(nudgeHidden: true);

  /// Re-reads the permission (after a trip to iOS Settings).
  Future<void> recheck() => _check(ref.read(pushBridgeProvider));

  /// Stops notifications to this phone (sign-out).
  Future<void> forgetDevice() async {
    final token = state.token;
    final api = ref.read(pushApiProvider);
    if (token == null || api == null) return;
    try {
      await api.forgetDevice(token);
    } catch (e) {
      debugPrint('Push forget failed: $e');
    }
    state = PushState(
      permission: state.permission,
      nudgeHidden: state.nudgeHidden,
    );
  }
}
