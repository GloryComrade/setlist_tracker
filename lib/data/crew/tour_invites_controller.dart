/// Tour invites: the ones Crew mates sent you (cards on The Crew tab), and
/// sending your own from Book The Tour or the Tour tab.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/crew.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';
import 'crew_controller.dart';
import 'crew_service.dart';

/// Invites sent to you, as the server has them. Empty when signed out or
/// before a stage name is picked.
final tourInvitesProvider =
    NotifierProvider<TourInvitesController, List<CrewTourInvite>>(
      TourInvitesController.new,
    );

/// The invites worth a card: Opening Night still to come, and not a race
/// your active Tour already co-headlines.
final visibleTourInvitesProvider = Provider<List<CrewTourInvite>>((ref) {
  final invites = ref.watch(tourInvitesProvider);
  if (invites.isEmpty) return const [];
  final mine = ref.watch(activeTourProvider).value;
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  return [
    for (final i in invites)
      if (!i.raceDate.isBefore(day) && !(mine != null && i.sameRaceAs(mine))) i,
  ];
});

class TourInvitesController extends Notifier<List<CrewTourInvite>> {
  CrewService? _service;

  /// Tries at sending before giving up on a Tour that hasn't synced.
  static const sendTries = 4;

  /// How long one try waits for a running sync to finish.
  static const syncWait = Duration(seconds: 8);

  @override
  List<CrewTourInvite> build() {
    _service = ref.watch(crewServiceProvider);
    final ready = ref.watch(
      crewControllerProvider.select((s) => s.profile != null),
    );
    if (_service == null || !ready) return const [];
    ref.listen(syncControllerProvider.select((s) => s.lastSynced), (_, _) {
      unawaited(refresh());
    });
    Future.microtask(refresh);
    return const [];
  }

  bool get _ready =>
      _service != null && ref.read(crewControllerProvider).profile != null;

  /// Reloads from the server. Keeps what's shown when it can't be reached.
  Future<void> refresh() async {
    if (!_ready) return;
    try {
      state = await _service!.tourInvites();
    } catch (_) {
      // The next refresh picks it up.
    }
  }

  /// "Not this time". Gone right away; back if the server says no.
  Future<void> dismiss(CrewTourInvite invite) async {
    final before = state;
    state = [
      for (final i in state)
        if (i.id != invite.id) i,
    ];
    try {
      await _service!.dismissTourInvite(invite.id);
    } catch (_) {
      state = before;
      rethrow;
    }
  }

  /// Invites [userIds] onto your Tour [tourId]. A Tour booked a moment ago
  /// may not be backstage yet, so this syncs and tries again until it is.
  /// Returns who was invited.
  Future<List<String>> send(String tourId, List<String> userIds) async {
    final service = _service;
    if (service == null || userIds.isEmpty) return const [];
    for (var attempt = 1; ; attempt++) {
      try {
        return await service.inviteToTour(tourId, userIds);
      } on TourNotSyncedException {
        if (attempt >= sendTries) rethrow;
        await _syncOnce();
      }
    }
  }

  /// Runs a sync and waits for it (or the one already running) to finish.
  Future<void> _syncOnce() async {
    final sync = ref.read(syncControllerProvider.notifier);
    await sync.syncNow();
    final until = DateTime.now().add(syncWait);
    while (ref.read(syncControllerProvider).phase == SyncPhase.syncing &&
        DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}
