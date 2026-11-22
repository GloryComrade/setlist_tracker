/// Keeps The Crew loaded for the screens, and keeps your shared Shows in
/// step with the Setlist: edit a shared Show and the Crew sees the new
/// version; delete it and it leaves the feed.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../models/crew.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import '../providers.dart';
import '../sync/sync_controller.dart';
import 'crew_service.dart';

/// The Crew backend. Null in builds without the Backstage Pass.
final crewServiceProvider = Provider<CrewService?>((ref) => null);

@immutable
class CrewState {
  const CrewState({
    this.available = false,
    this.signedIn = false,
    this.loaded = false,
    this.loading = false,
    this.profile,
    this.mates = const [],
    this.posts = const [],
    this.shared = const {},
    this.error,
  });

  /// False when this build has no backend: the Crew tab says so.
  final bool available;
  final bool signedIn;

  /// True once the first load finished (even if it failed).
  final bool loaded;
  final bool loading;
  final CrewProfile? profile;

  /// In the Crew first, then blocked runners.
  final List<CrewMate> mates;
  final List<CrewPost> posts;

  /// Your shared Shows, by Show id.
  final Map<String, SharedInfo> shared;
  final String? error;

  List<CrewMate> get crew => mates.where((m) => !m.blocked).toList();
  List<CrewMate> get blocked => mates.where((m) => m.blocked).toList();

  CrewState copyWith({
    bool? loaded,
    bool? loading,
    CrewProfile? profile,
    List<CrewMate>? mates,
    List<CrewPost>? posts,
    Map<String, SharedInfo>? shared,
    String? error,
    bool clearError = false,
  }) => CrewState(
    available: available,
    signedIn: signedIn,
    loaded: loaded ?? this.loaded,
    loading: loading ?? this.loading,
    profile: profile ?? this.profile,
    mates: mates ?? this.mates,
    posts: posts ?? this.posts,
    shared: shared ?? this.shared,
    error: clearError ? null : (error ?? this.error),
  );
}

final crewControllerProvider = NotifierProvider<CrewController, CrewState>(
  CrewController.new,
);

/// An invite code waiting for sign-in. Kept on the device so it survives
/// the trip out to Google's sign-in page and back.
final _crewPrefs = StoreRef<String, Object?>('crew_prefs');
const _pendingInviteKey = 'pendingInvite';

class CrewController extends Notifier<CrewState> {
  CrewService? _service;
  final _resharing = <String>{};

  @override
  CrewState build() {
    _service = ref.watch(crewServiceProvider);
    final holderId = ref.watch(
      syncControllerProvider.select((s) => s.holder?.id),
    );
    final service = _service;
    if (service == null) return const CrewState();
    if (holderId == null) return const CrewState(available: true);

    ref.listen(showsProvider, (_, next) {
      final shows = next.value;
      if (shows != null) unawaited(_reconcile(shows));
    });
    ref.listen(activeTourProvider, (_, next) {
      unawaited(_syncOpeningNight(next.value));
    });
    Future.microtask(refresh);
    return const CrewState(available: true, signedIn: true, loading: true);
  }

  CrewService get _s => _service!;

  /// Reloads everything from the server.
  Future<void> refresh() async {
    if (_service == null || !state.signedIn) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = await _s.myProfile();
      if (profile == null) {
        state = CrewState(
          available: true,
          signedIn: true,
          loaded: true,
          shared: state.shared,
        );
        return;
      }
      final results = await Future.wait([
        _s.crew(),
        _s.feed(),
        _s.mySharedShows(),
      ]);
      state = state.copyWith(
        loaded: true,
        loading: false,
        profile: profile,
        mates: results[0] as List<CrewMate>,
        posts: results[1] as List<CrewPost>,
        shared: results[2] as Map<String, SharedInfo>,
      );
      final shows = ref.read(showsProvider).value;
      if (shows != null) unawaited(_reconcile(shows));
      unawaited(_syncOpeningNight(ref.read(activeTourProvider).value));
    } catch (e) {
      state = state.copyWith(
        loaded: true,
        loading: false,
        error: e is CrewException
            ? e.message
            : 'The Crew couldn’t be reached. Check your connection.',
      );
    }
  }

  Future<void> saveProfile(CrewProfile profile) async {
    final withTour = _withTour(profile, ref.read(activeTourProvider).value);
    final saved = await _s.saveProfile(withTour);
    state = state.copyWith(profile: saved);
    if (state.mates.isEmpty && state.posts.isEmpty) await refresh();
  }

  /// Fills in the Opening Night fields from the active Tour, or clears them.
  CrewProfile _withTour(CrewProfile p, Tour? tour) {
    if (!p.showOpeningNight || tour == null) {
      return p.copyWith(clearOpeningNight: true);
    }
    return p.copyWith(openingNight: tour.setup.raceDate, tourName: tour.name);
  }

  Future<void> _syncOpeningNight(Tour? tour) async {
    final p = state.profile;
    if (p == null || !p.showOpeningNight) return;
    final next = _withTour(p, tour);
    if (next.openingNight == p.openingNight && next.tourName == p.tourName) {
      return;
    }
    try {
      state = state.copyWith(profile: await _s.saveProfile(next));
    } catch (e) {
      debugPrint('Crew: Opening Night not updated: $e');
    }
  }

  Future<String> inviteCode() => _s.inviteCode();

  Future<CrewInvitePreview?> previewInvite(String code) =>
      _s.previewInvite(code);

  Future<void> join(String code) async {
    await _s.join(code);
    await clearPendingInvite();
    await refresh();
  }

  Future<void> leave(CrewMate mate) async {
    await _s.leave(mate.userId);
    await refresh();
  }

  Future<void> block(String userId) async {
    await _s.block(userId);
    await refresh();
  }

  Future<void> unblock(CrewMate mate) async {
    await _s.unblock(mate.userId);
    await refresh();
  }

  /// Shares [show] with the Crew (or updates the shared copy).
  Future<void> share(Show show, {bool includeNotes = false}) async {
    final all = ref.read(showsProvider).value ?? [show];
    await _s.share(
      show.id,
      SharedShow.fromShow(show, allShows: all, includeNotes: includeNotes),
      show.updatedAt,
    );
    state = state.copyWith(
      shared: {
        ...state.shared,
        show.id: SharedInfo(
          showUpdatedAt: show.updatedAt,
          includesNotes: includeNotes && show.notes != null,
        ),
      },
    );
    unawaited(_reloadFeed());
  }

  Future<void> unshare(String showId) async {
    await _s.unshare(showId);
    state = state.copyWith(
      shared: {...state.shared}..remove(showId),
      posts: state.posts.where((p) => !(p.mine && p.showId == showId)).toList(),
    );
  }

  /// For a brand-new Show: shares it when "Share every new Show" is on.
  Future<void> shareIfAlways(Show show) async {
    if (state.profile?.alwaysShare != true) return;
    try {
      await share(show);
    } catch (e) {
      debugPrint('Crew: auto-share failed: $e');
    }
  }

  Future<void> toggleEncore(CrewPost post) async {
    final on = !post.encoredByMe;
    _replacePost(post.withEncore(on));
    try {
      await _s.encore(post.id, on: on);
    } catch (e) {
      _replacePost(post);
      rethrow;
    }
  }

  void _replacePost(CrewPost post) {
    state = state.copyWith(
      posts: [for (final p in state.posts) p.id == post.id ? post : p],
    );
  }

  Future<void> report(
    CrewPost post,
    String reason, {
    bool block = false,
  }) async {
    await _s.report(post, reason);
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != post.id).toList(),
    );
    if (block) await this.block(post.ownerId);
  }

  Future<void> _reloadFeed() async {
    try {
      state = state.copyWith(posts: await _s.feed());
    } catch (_) {
      // The next refresh picks it up.
    }
  }

  /// Re-shares edited Shows and takes deleted ones off the feed.
  Future<void> _reconcile(List<Show> shows) async {
    if (!state.signedIn || state.profile == null) return;
    final byId = {for (final s in shows) s.id: s};
    final db = ref.read(databaseProvider);
    for (final entry in state.shared.entries.toList()) {
      final id = entry.key;
      if (_resharing.contains(id)) continue;
      final show = byId[id];
      _resharing.add(id);
      try {
        if (show == null) {
          // Only a real delete counts. A Show that simply isn't on this
          // device yet (first sync still running) stays shared.
          final raw = await StoreRef<String, Object?>('shows')
              .record(id)
              .get(db);
          if (raw is Map && raw['deletedAt'] != null) await unshare(id);
        } else if (show.updatedAt.millisecondsSinceEpoch >
            entry.value.showUpdatedAt.millisecondsSinceEpoch) {
          // Compared to the millisecond: the server keeps times that way.
          await share(show, includeNotes: entry.value.includesNotes);
        }
      } catch (e) {
        debugPrint('Crew: shared Show $id not updated: $e');
      } finally {
        _resharing.remove(id);
      }
    }
  }

  // ---- Invite links that arrive before sign-in ----

  Future<void> savePendingInvite(String code) => _crewPrefs
      .record(_pendingInviteKey)
      .put(ref.read(databaseProvider), code.trim().toUpperCase());

  Future<String?> pendingInvite() async =>
      await _crewPrefs.record(_pendingInviteKey).get(ref.read(databaseProvider))
          as String?;

  Future<void> clearPendingInvite() =>
      _crewPrefs.record(_pendingInviteKey).delete(ref.read(databaseProvider));
}
