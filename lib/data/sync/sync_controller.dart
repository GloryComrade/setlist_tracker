/// Keeps the Backstage Pass and the sync running in the background.
///
/// Syncs when someone signs in, a few seconds after each change, when the
/// app comes back to the foreground, and when asked (pull to refresh).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../providers.dart';
import 'sync_engine.dart';

enum SyncPhase {
  /// Guest, or a build without a backend: nothing syncs.
  off,
  syncing,
  synced,

  /// The last try failed (usually no signal). Changes wait on the device.
  offline,
}

@immutable
class SyncState {
  const SyncState({
    this.holder,
    this.phase = SyncPhase.off,
    this.lastSynced,
    this.pending = 0,
  });

  final PassHolder? holder;
  final SyncPhase phase;
  final DateTime? lastSynced;

  /// Changes on this device not uploaded yet.
  final int pending;

  bool get signedIn => holder != null;

  SyncState copyWith({
    PassHolder? holder,
    bool clearHolder = false,
    SyncPhase? phase,
    DateTime? lastSynced,
    int? pending,
  }) => SyncState(
    holder: clearHolder ? null : (holder ?? this.holder),
    phase: phase ?? this.phase,
    lastSynced: lastSynced ?? this.lastSynced,
    pending: pending ?? this.pending,
  );
}

/// Work that must happen just before signing out, while the session still
/// works (the push controller takes this phone's token back). Kept as a
/// list the others add to, so the sync needn't know about them.
class SignOutHooks {
  final _hooks = <Future<void> Function({required bool deleting})>[];

  void add(Future<void> Function({required bool deleting}) hook) =>
      _hooks.add(hook);

  void remove(Future<void> Function({required bool deleting}) hook) =>
      _hooks.remove(hook);

  /// [deleting]: the account is going, and the server removes its data.
  Future<void> run({required bool deleting}) async {
    for (final h in [..._hooks]) {
      try {
        await h(deleting: deleting);
      } catch (e) {
        debugPrint('Sign-out hook failed: $e');
      }
    }
  }
}

final signOutHooksProvider = Provider<SignOutHooks>((ref) => SignOutHooks());

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  /// How long to wait after a change before uploading, so a burst of edits
  /// (a Studio Session with ten Tracks) goes up in one trip.
  static const debounce = Duration(seconds: 3);

  late AuthService _auth;
  SyncEngine? _engine;
  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _leaving = false;

  @override
  SyncState build() {
    _auth = ref.watch(authServiceProvider);
    _engine = ref.watch(syncEngineProvider);
    final engine = _engine;
    if (!_auth.available || engine == null) return const SyncState();

    final authSub = _auth.changes().listen(_onHolder);
    final pendingSub = engine.watchPending().listen((n) {
      state = state.copyWith(pending: n);
      if (n > 0 && state.signedIn) _schedule();
    });
    final life = AppLifecycleListener(onResume: syncNow);
    ref.onDispose(() {
      authSub.cancel();
      pendingSub.cancel();
      life.dispose();
      _timer?.cancel();
    });

    final holder = _auth.current;
    if (holder != null) Future.microtask(() => _onHolder(holder));
    return SyncState(
      holder: holder,
      phase: holder == null ? SyncPhase.off : SyncPhase.syncing,
    );
  }

  Future<void> _onHolder(PassHolder? holder) async {
    if (holder == null) {
      state = state.copyWith(clearHolder: true, phase: SyncPhase.off);
      return;
    }
    if (_leaving) return;
    final first = state.holder?.id != holder.id || state.lastSynced == null;
    state = state.copyWith(holder: holder);
    if (first) {
      await _engine!.adopt(holder.id);
      await syncNow();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, syncNow);
  }

  /// Runs a sync now. Safe to call any time; overlapping calls fold into one
  /// extra run after the current one.
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null || !state.signedIn || _leaving) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      do {
        _again = false;
        await engine.sync();
      } while (_again);
      state = state.copyWith(
        phase: SyncPhase.synced,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Sync failed: $e');
      state = state.copyWith(phase: SyncPhase.offline);
    } finally {
      _running = false;
    }
  }

  /// Changes on this device not uploaded yet.
  int get pendingChanges => state.pending;

  Future<void> signInWithGoogle() => _auth.signInWithGoogle();
  Future<void> signInWithApple() => _auth.signInWithApple();

  /// Uploads anything left, signs out and clears this device's copy. Your
  /// Shows stay in the account for next time.
  ///
  /// Returns false (and stays signed in) when changes couldn't be uploaded
  /// and [force] is false, so nothing is lost by accident.
  Future<bool> signOut({bool force = false}) async {
    await syncNow();
    if (!force && state.pending > 0) return false;
    _leaving = true;
    try {
      // While still signed in (this phone stops getting Crew notifications).
      await ref.read(signOutHooksProvider).run(deleting: false);
      await _auth.signOut();
      await _engine?.clearLocal();
      state = const SyncState();
    } finally {
      _leaving = false;
    }
    return true;
  }

  Future<void> deleteAccount() async {
    _leaving = true;
    try {
      await _auth.deleteAccount();
      await ref.read(signOutHooksProvider).run(deleting: true);
      await _engine?.clearLocal();
      state = const SyncState();
    } finally {
      _leaving = false;
    }
  }
}
