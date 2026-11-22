/// Keeps this iPhone's push notifications in step with the runner.
///
/// - Asks iOS once, the first time a signed-in runner with a stage name
///   opens The Crew ([PushController.askOnce]); remembered on the device.
/// - Sends the token to the Worker whenever iOS hands one out and either
///   switch in Settings → The Crew is on; takes it back when both are off
///   and when the runner signs out.
/// - A tapped notification opens The Crew ([PushState.opens]).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../models/json_utils.dart';
import '../crew/crew_controller.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';
import 'push_service.dart';

/// iOS's side. [NoPushService] on web, other platforms and in tests.
final pushServiceProvider = Provider<PushService>((ref) => createPushService());

/// The Worker's device route. Null in builds without the Backstage Pass.
final pushDevicesProvider = Provider<PushDevices?>((ref) => null);

final pushControllerProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);

/// "Asked once" is kept on the device, beside the Crew's own prefs.
final _pushPrefs = StoreRef<String, Object?>('push_prefs');
const _askedKey = 'asked';

@immutable
class PushState {
  const PushState({
    this.available = false,
    this.permission = PushPermission.notDetermined,
    this.opens = 0,
    this.openedPostId,
  });

  /// False on web and anywhere but iPhone: Settings shows no switches.
  final bool available;
  final PushPermission permission;

  /// Goes up by one each time a notification is tapped.
  final int opens;

  /// The Crew post (`ownerId:showId`) the last tapped notification was about.
  final String? openedPostId;

  PushState copyWith({
    PushPermission? permission,
    int? opens,
    String? openedPostId,
  }) => PushState(
    available: available,
    permission: permission ?? this.permission,
    opens: opens ?? this.opens,
    openedPostId: openedPostId ?? this.openedPostId,
  );
}

class PushController extends Notifier<PushState> {
  late PushService _service;
  PushDevices? _devices;
  PushToken? _token;

  /// What the server was last told about [_token]: `on|user|token|env` or
  /// `off|token`. Null when unknown (start, sign-out, a failed call).
  String? _sent;
  Future<void> _queue = Future.value();
  bool _askedThisRun = false;

  @override
  PushState build() {
    _service = ref.watch(pushServiceProvider);
    _devices = ref.watch(pushDevicesProvider);
    _token = null;
    _sent = null;
    _askedThisRun = false;
    if (!_service.available) return const PushState();

    final tokenSub = _service.tokens.listen((t) {
      _token = t;
      _syncServer();
    });
    final openSub = _service.opened.listen(_onOpened);
    final life = AppLifecycleListener(onResume: refreshPermission);
    final hooks = ref.watch(signOutHooksProvider)..add(_beforeSignOut);
    ref.onDispose(() {
      tokenSub.cancel();
      openSub.cancel();
      life.dispose();
      hooks.remove(_beforeSignOut);
    });
    ref.listen(
      crewControllerProvider.select((s) {
        final p = s.profile;
        return p == null
            ? null
            : '${p.userId}|${p.pushShows}|${p.pushShoutouts}';
      }),
      (_, _) => _syncServer(),
    );
    Future.microtask(_start);
    return const PushState(available: true);
  }

  Future<void> _start() async {
    await refreshPermission();
    final first = await _service.initialMessage();
    if (first != null) _onOpened(first);
  }

  /// Reads iOS's answer again (the runner may have changed it in iOS
  /// Settings) and asks for a token when allowed.
  Future<void> refreshPermission() async {
    if (!state.available) return;
    final permission = await _service.status();
    state = state.copyWith(permission: permission);
    if (permission.allowed) await _service.register();
  }

  /// The first time The Crew opens with a stage name: iOS's own prompt,
  /// once per device, and only while a switch is on.
  Future<void> askOnce() async {
    if (!state.available || _askedThisRun) return;
    final p = ref.read(crewControllerProvider).profile;
    if (p == null || !(p.pushShows || p.pushShoutouts)) return;
    _askedThisRun = true;
    final db = ref.read(databaseProvider);
    final asked = _pushPrefs.record(_askedKey);
    if (await asked.get(db) == true) return;
    await asked.put(db, true);
    var permission = await _service.status();
    if (permission == PushPermission.notDetermined) {
      await _service.requestPermission();
      permission = await _service.status();
    } else if (permission.allowed) {
      await _service.register();
    }
    state = state.copyWith(permission: permission);
  }

  /// Opens Setlist Tracker's notification settings in iOS Settings.
  Future<void> openSettings() => _service.openSettings();

  /// Signing out: this phone stops getting the Crew's notifications. Call
  /// while still signed in. With [tellServer] false (the account is being
  /// deleted, which removes its devices) only this side forgets.
  Future<void> forgetDevice({bool tellServer = true}) async {
    await _queue;
    final t = _token;
    final d = _devices;
    final wasOn = _sent?.startsWith('on|') ?? false;
    _sent = null;
    if (!tellServer || t == null || d == null || !wasOn) return;
    try {
      await d.unregister(t.token);
    } catch (e) {
      debugPrint('Push: unregister failed: $e');
    }
  }

  Future<void> _beforeSignOut({required bool deleting}) =>
      forgetDevice(tellServer: !deleting);

  void _syncServer() {
    _queue = _queue.then((_) => _send()).catchError((Object _) {});
  }

  Future<void> _send() async {
    final t = _token;
    final d = _devices;
    final p = ref.read(crewControllerProvider).profile;
    if (t == null || d == null || p == null) return;
    final on = p.pushShows || p.pushShoutouts;
    final want = on
        ? 'on|${p.userId}|${t.token}|${t.environment}'
        : 'off|${t.token}';
    if (_sent == want) return;
    try {
      if (on) {
        await d.register(t);
      } else {
        await d.unregister(t.token);
      }
      _sent = want;
    } catch (e) {
      debugPrint('Push: device update failed: $e');
      _sent = null;
    }
  }

  void _onOpened(Map<String, Object?> data) {
    // `{type, postId}`, beside `aps` or under a `data` key.
    final postId = data['postId'] ?? asMap(data['data'])?['postId'];
    state = state.copyWith(
      opens: state.opens + 1,
      openedPostId: postId is String ? postId : null,
    );
  }
}
