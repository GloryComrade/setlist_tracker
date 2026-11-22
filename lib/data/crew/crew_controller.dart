/// Keeps The Crew loaded for the screens. The Crew sees every Show the
/// Setlist syncs (except Shows kept off the Crew), so there is nothing to
/// share by hand: the feed reloads after each sync.
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
    this.error,
    this.allActivityNoticeHidden = false,
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
  final String? error;

  /// "Not now" on the "Your Crew sees more now" card, for this session.
  final bool allActivityNoticeHidden;

  /// The runner hasn't OK'd the Crew seeing every Show yet.
  bool get allActivityPending => profile?.allActivityPending ?? false;

  List<CrewMate> get crew => mates.where((m) => !m.blocked).toList();
  List<CrewMate> get blocked => mates.where((m) => m.blocked).toList();

  CrewState copyWith({
    bool? loaded,
    bool? loading,
    CrewProfile? profile,
    List<CrewMate>? mates,
    List<CrewPost>? posts,
    String? error,
    bool clearError = false,
    bool? allActivityNoticeHidden,
  }) => CrewState(
    available: available,
    signedIn: signedIn,
    loaded: loaded ?? this.loaded,
    loading: loading ?? this.loading,
    profile: profile ?? this.profile,
    mates: mates ?? this.mates,
    posts: posts ?? this.posts,
    error: clearError ? null : (error ?? this.error),
    allActivityNoticeHidden:
        allActivityNoticeHidden ?? this.allActivityNoticeHidden,
  );
}

final crewControllerProvider = NotifierProvider<CrewController, CrewState>(
  CrewController.new,
);

/// A Crew mate's page: their Tour and Setlist. Null when they aren't in your
/// Crew (or the Crew isn't available).
final crewMateProvider = FutureProvider.autoDispose
    .family<CrewMateDetail?, String>((ref, userId) async {
      final service = ref.watch(crewServiceProvider);
      final signedIn = ref.watch(
        crewControllerProvider.select((s) => s.profile != null),
      );
      if (service == null || !signedIn) return null;
      return service.mate(userId);
    });

/// Crew mates racing the same Opening Night as your active Tour.
final coHeadlinersProvider = Provider<List<CrewMate>>((ref) {
  if (ref.watch(crewServiceProvider) == null) return const [];
  final mine = ref.watch(activeTourProvider).value;
  if (mine == null) return const [];
  final crew = ref.watch(crewControllerProvider.select((s) => s.crew));
  return [
    for (final m in crew)
      if (m.tour?.sameRaceAs(mine) ?? false) m,
  ];
});

/// True when [mine] is co-headlined with [mate]'s Tour.
bool coHeadlining(Tour? mine, CrewMate mate) =>
    mine != null && (mate.tour?.sameRaceAs(mine) ?? false);

/// An invite code waiting for sign-in. Kept on the device so it survives
/// the trip out to Google's sign-in page and back.
final _crewPrefs = StoreRef<String, Object?>('crew_prefs');
const _pendingInviteKey = 'pendingInvite';

class CrewController extends Notifier<CrewState> {
  CrewService? _service;

  @override
  CrewState build() {
    _service = ref.watch(crewServiceProvider);
    final holderId = ref.watch(
      syncControllerProvider.select((s) => s.holder?.id),
    );
    final service = _service;
    if (service == null) return const CrewState();
    if (holderId == null) return const CrewState(available: true);

    // Your own Shows on the feed follow the Setlist right away; the rest
    // arrives with the next sync.
    ref.listen(showsProvider, (_, next) {
      final shows = next.value;
      if (shows != null) _followSetlist(shows);
    });
    ref.listen(syncControllerProvider.select((s) => s.lastSynced), (_, _) {
      if (state.profile != null) unawaited(_reloadFeed());
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
        state = const CrewState(available: true, signedIn: true, loaded: true);
        return;
      }
      final results = await Future.wait([_s.crew(), _s.feed()]);
      state = state.copyWith(
        loaded: true,
        loading: false,
        profile: profile,
        mates: results[0] as List<CrewMate>,
        posts: results[1] as List<CrewPost>,
      );
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object? e) {
    state = state.copyWith(
      loaded: true,
      loading: false,
      error: e is CrewException
          ? e.message
          : 'The Crew couldn’t be reached. Check your connection.',
    );
  }

  Future<void> saveProfile(CrewProfile profile) async {
    final saved = await _s.saveProfile(profile);
    state = state.copyWith(profile: saved);
    if (state.mates.isEmpty && state.posts.isEmpty) await refresh();
  }

  /// "Sounds good": the Crew sees every Show from now on.
  Future<void> acceptAllActivity() async {
    final p = state.profile;
    if (p == null) return;
    final saved = await _s.acceptAllActivity(p);
    state = state.copyWith(profile: saved);
    // The server has the last word on what the Crew sees.
    final fresh = await _s.myProfile();
    if (fresh != null) state = state.copyWith(profile: fresh);
  }

  /// "Not now": hides the card until the app is opened again. The Crew
  /// keeps seeing only the Shows you shared.
  void hideAllActivityNotice() =>
      state = state.copyWith(allActivityNoticeHidden: true);

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

  /// Marks one of your Shows "Keep off the Crew" and takes it off the feed.
  /// The Crew stops seeing it once the Setlist syncs.
  Future<void> keepOffCrew(CrewPost post) async {
    final repo = ref.read(showRepositoryProvider);
    final show = await repo.getById(post.showId);
    if (show == null) return;
    await repo.save(show.copyWith(crewPrivate: true));
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != post.id).toList(),
    );
  }

  /// A Crew mate's page. Null when they aren't in your Crew.
  Future<CrewMateDetail?> mate(String userId) => _s.mate(userId);

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

  // ---- Profile pictures ----

  /// Picks a drawn badge, or none with null.
  Future<void> setAvatarBadge(String? badge) async {
    final p = state.profile;
    if (p == null) return;
    _showMyPicture(await _s.saveAvatarBadge(p, badge));
  }

  /// [jpeg] is already square and small (see `avatar_photo.dart`).
  Future<void> uploadAvatar(Uint8List jpeg) async =>
      _showMyPicture(await _s.uploadAvatar(jpeg));

  Future<void> removeAvatar() async => _showMyPicture(await _s.removeAvatar());

  /// Reports a Crew mate's photo, and blocks them too when asked.
  Future<void> reportAvatar(
    CrewMate mate,
    String reason, {
    bool block = false,
  }) async {
    await _s.reportAvatar(mate.userId, reason);
    if (block) await this.block(mate.userId);
  }

  /// Your own posts on the feed wear the new picture straight away.
  void _showMyPicture(CrewProfile saved) {
    state = state.copyWith(
      profile: saved,
      posts: [
        for (final p in state.posts)
          p.mine ? p.withPicture(saved.avatarBadge, saved.avatarUrl) : p,
      ],
    );
  }

  // ---- Seen by, Encores and Shout-outs ----

  /// Posts already marked seen this session, so each is sent once.
  final _seen = <String>{};

  /// You saw [post] (opened it, or its card stayed on screen). Sent once per
  /// post; your own Shows and the switch being off send nothing.
  Future<void> markSeen(CrewPost post) async {
    if (post.mine || !(state.profile?.shareViews ?? true)) return;
    if (!_seen.add(post.id)) return;
    try {
      await _s.markSeen(post.id);
    } catch (_) {
      _seen.remove(post.id); // Try again next time it's seen.
    }
  }

  /// "Let my Crew know when I've seen their Shows".
  Future<void> setShareViews(bool on) async {
    final p = state.profile;
    if (p == null) return;
    state = state.copyWith(profile: await _s.setShareViews(p, on));
  }

  Future<CrewAudience> audience(CrewPost post) => _s.audience(post.id);

  Future<List<CrewShoutout>> shoutouts(CrewPost post) async {
    final list = await _s.shoutouts(post.id);
    _setShoutoutCount(post.id, list.length);
    return list;
  }

  Future<CrewShoutout> addShoutout(CrewPost post, String body) async {
    final added = await _s.addShoutout(post.id, body);
    _bumpShoutouts(post.id, 1);
    return added;
  }

  Future<void> deleteShoutout(CrewPost post, CrewShoutout shoutout) async {
    await _s.deleteShoutout(shoutout.id);
    _bumpShoutouts(post.id, -1);
  }

  /// Reports a Shout-out, and blocks its writer too when asked.
  Future<void> reportShoutout(
    CrewPost post,
    CrewShoutout shoutout,
    String reason, {
    bool block = false,
  }) async {
    await _s.reportShoutout(shoutout.id, reason);
    _bumpShoutouts(post.id, -1);
    if (block) await this.block(shoutout.userId);
  }

  void _bumpShoutouts(String postId, int by) {
    for (final p in state.posts) {
      if (p.id == postId) {
        _replacePost(p.withShoutouts((p.shoutouts + by).clamp(0, 1 << 30)));
      }
    }
  }

  void _setShoutoutCount(String postId, int n) {
    for (final p in state.posts) {
      if (p.id == postId && p.shoutouts != n) _replacePost(p.withShoutouts(n));
    }
  }

  Future<void> _reloadFeed() async {
    try {
      state = state.copyWith(posts: await _s.feed());
    } catch (_) {
      // The next refresh picks it up.
    }
  }

  /// Your own posts show the Setlist's latest version of each Show, and
  /// leave as soon as a Show is kept off the Crew.
  void _followSetlist(List<Show> shows) {
    if (!state.posts.any((p) => p.mine)) return;
    final byId = {for (final s in shows) s.id: s};
    final gear = ref.read(gearListProvider).value ?? const [];
    var changed = false;
    final next = <CrewPost>[];
    for (final p in state.posts) {
      final local = p.mine ? byId[p.showId] : null;
      if (local == null || identical(local, p.show)) {
        next.add(p);
        continue;
      }
      changed = true;
      if (local.crewPrivate) continue;
      next.add(
        CrewPost(
          id: p.id,
          ownerId: p.ownerId,
          stageName: p.stageName,
          color: p.color,
          show: local,
          gearName: local.gearId == p.show.gearId
              ? p.gearName
              : gear.where((g) => g.id == local.gearId).firstOrNull?.name,
          sharedAt: p.sharedAt,
          encores: p.encores,
          encoredByMe: p.encoredByMe,
          mine: true,
          avatarBadge: p.avatarBadge,
          avatarUrl: p.avatarUrl,
        ),
      );
    }
    if (changed) state = state.copyWith(posts: next);
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
