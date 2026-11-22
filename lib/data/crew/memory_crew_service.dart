import 'dart:typed_data';

import '../../models/avatar_badge.dart';
import '../../models/crew.dart';
import '../../models/show.dart';
import '../../models/tour.dart';
import 'crew_service.dart';

/// [CrewService] that keeps everything in memory, with the same rules as the
/// server: only your Crew sees your Shows, Shows kept off the Crew stay
/// hidden, and a block cuts both ways.
///
/// Used by the tests and by `tool/crew_preview.dart`.
class MemoryCrewService implements CrewService {
  MemoryCrewService({required this.me});

  /// The signed-in runner's id.
  final String me;

  final profiles = <String, CrewProfile>{};

  /// Invite code → owner.
  final invites = <String, String>{};

  /// Sorted pair "a|b" → since. Blocks are kept separately.
  final links = <String, DateTime>{};

  /// Blocker → blocked.
  final blocks = <String, Set<String>>{};

  /// Post id (`<owner>:<showId>`) → the Show.
  final posts = <String, _Post>{};

  /// Owner → their Tours.
  final tours = <String, List<Tour>>{};
  final encores = <String, Set<String>>{};
  final reported = <String>{};
  final reports = <({String postId, String reason})>[];

  /// Post id → viewer → when they first saw it.
  final views = <String, Map<String, DateTime>>{};

  /// Every Shout-out, oldest first.
  final shoutoutRows = <MemoryShoutout>[];
  final shoutoutReports = <({String id, String reason})>[];

  var _clock = DateTime.utc(2026, 11, 1);

  /// The day "active Tour" is measured from. Defaults to today.
  DateTime? today;
  DateTime _tick() => _clock = _clock.add(const Duration(minutes: 1));

  static String _pair(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  bool _blocked(String a, String b) =>
      (blocks[a]?.contains(b) ?? false) || (blocks[b]?.contains(a) ?? false);

  bool isCrew(String a, String b) => links.containsKey(_pair(a, b));

  /// Puts [other] straight into [me]'s Crew (test and preview setup).
  void addMate(CrewProfile other, {DateTime? since}) {
    profiles[other.userId] = other;
    links[_pair(me, other.userId)] = since ?? _tick();
  }

  /// A Show on [owner]'s Setlist (test and preview setup). Returns the
  /// post id.
  String addShow(
    String owner,
    Show show, {
    String? gearName,
    DateTime? at,
    int encoreCount = 0,
  }) {
    final id = CrewPost.idFor(owner, show.id);
    posts[id] = _Post(owner, show, gearName, at ?? _tick());
    encores[id] = {for (var i = 0; i < encoreCount; i++) 'fan$i'};
    return id;
  }

  /// Books a Tour for [owner] (test and preview setup).
  void addTour(String owner, Tour tour) =>
      tours.putIfAbsent(owner, () => []).add(tour);

  /// The non-deleted Tour with the latest Opening Night still to come.
  Tour? activeTour(String owner) {
    final n = (today ?? DateTime.now()).toUtc();
    final day = DateTime(n.year, n.month, n.day);
    Tour? best;
    for (final t in tours[owner] ?? const <Tour>[]) {
      if (t.isDeleted || t.setup.raceDate.isBefore(day)) continue;
      if (best == null || t.setup.raceDate.isAfter(best.setup.raceDate)) {
        best = t;
      }
    }
    return best;
  }

  CrewTourSummary? _tourSummary(String owner) {
    final t = activeTour(owner);
    return t == null ? null : CrewTourSummary.fromTour(t);
  }

  @override
  Future<CrewProfile?> myProfile() async => profiles[me];

  @override
  Future<CrewProfile> saveProfile(CrewProfile profile) async {
    final name = profile.stageName.trim();
    if (name.isEmpty || name.length > 30) {
      throw const CrewException('A stage name is 1 to 30 characters.');
    }
    final saved = profile.copyWith(stageName: name);
    profiles[me] = CrewProfile(
      userId: me,
      stageName: saved.stageName,
      color: saved.color,
      // Saving a name doesn't OK the change; only acceptAllActivity does.
      allActivityPending: profiles[me]?.allActivityPending ?? false,
      // The picture has its own calls.
      avatarBadge: profiles[me]?.avatarBadge,
      avatarUrl: profiles[me]?.avatarUrl,
      shareViews: profiles[me]?.shareViews ?? true,
    );
    return profiles[me]!;
  }

  @override
  Future<CrewProfile> acceptAllActivity(CrewProfile profile) async {
    final saved = await saveProfile(profile);
    return profiles[me] = saved.copyWith(allActivityPending: false);
  }

  void _needProfile() {
    if (!profiles.containsKey(me)) {
      throw const CrewException('Pick a stage name first.');
    }
  }

  @override
  Future<String> inviteCode() async {
    _needProfile();
    for (final e in invites.entries) {
      if (e.value == me) return e.key;
    }
    const codes = ['K7Q9MX4P', 'P4TR8WHN', 'H2NV6CQD', 'D3JZ5FGT'];
    final code = codes[invites.length % codes.length];
    invites[code] = me;
    return code;
  }

  @override
  Future<CrewInvitePreview?> previewInvite(String code) async {
    final owner = invites[code.trim().toUpperCase()];
    if (owner == null || _blocked(me, owner)) return null;
    final p = profiles[owner];
    if (p == null) return null;
    return CrewInvitePreview(
      stageName: p.stageName,
      color: p.color,
      alreadyCrew: isCrew(me, owner),
      ownInvite: owner == me,
    );
  }

  @override
  Future<void> join(String code) async {
    _needProfile();
    final owner = invites[code.trim().toUpperCase()];
    if (owner == null || _blocked(me, owner)) {
      throw const CrewException('That invite has expired or doesn’t exist.');
    }
    if (owner == me) throw const CrewException('That’s your own invite.');
    links.putIfAbsent(_pair(me, owner), _tick);
  }

  @override
  Future<List<CrewMate>> crew() async {
    final out = <CrewMate>[];
    for (final e in links.entries) {
      final ids = e.key.split('|');
      if (!ids.contains(me)) continue;
      final other = ids.first == me ? ids.last : ids.first;
      final p = profiles[other];
      out.add(
        CrewMate(
          userId: other,
          stageName: p?.stageName ?? 'Runner',
          color: p?.color ?? 0,
          since: e.value,
          tour: _tourSummary(other),
          avatarBadge: p?.avatarBadge,
          avatarUrl: p?.avatarUrl,
        ),
      );
    }
    for (final other in blocks[me] ?? const <String>{}) {
      final p = profiles[other];
      out.add(
        CrewMate(
          userId: other,
          stageName: p?.stageName ?? 'Runner',
          color: p?.color ?? 0,
          since: _clock,
          blocked: true,
        ),
      );
    }
    out.sort((a, b) {
      if (a.blocked != b.blocked) return a.blocked ? 1 : -1;
      return a.stageName.compareTo(b.stageName);
    });
    return out;
  }

  @override
  Future<void> leave(String userId) async => links.remove(_pair(me, userId));

  @override
  Future<void> block(String userId) async {
    links.remove(_pair(me, userId));
    blocks.putIfAbsent(me, () => {}).add(userId);
  }

  @override
  Future<void> unblock(String userId) async => blocks[me]?.remove(userId);

  bool _visible(_Post p) =>
      !p.show.isDeleted &&
      !p.show.crewPrivate &&
      (p.owner == me || isCrew(me, p.owner));

  CrewPost _toPost(String id, _Post p) => CrewPost(
    id: id,
    ownerId: p.owner,
    stageName: profiles[p.owner]?.stageName ?? 'Runner',
    color: profiles[p.owner]?.color ?? 0,
    show: p.show,
    gearName: p.gearName,
    sharedAt: p.at,
    encores: encores[id]?.length ?? 0,
    encoredByMe: encores[id]?.contains(me) ?? false,
    mine: p.owner == me,
    avatarBadge: profiles[p.owner]?.avatarBadge,
    avatarUrl: profiles[p.owner]?.avatarUrl,
    shoutouts: _shoutoutsOn(id).length,
    seenBy: p.owner == me ? _seenSummary(id) : null,
  );

  List<CrewPost> _posts(bool Function(_Post) where, int cap) {
    final visible =
        posts.entries
            .where((e) => _visible(e.value) && where(e.value))
            .where((e) => !reported.contains(e.key))
            .toList()
          ..sort((a, b) => b.value.show.date.compareTo(a.value.show.date));
    return [for (final e in visible.take(cap)) _toPost(e.key, e.value)];
  }

  @override
  Future<List<CrewPost>> feed() async => _posts((_) => true, 60);

  @override
  Future<CrewMateDetail?> mate(String userId) async {
    if (userId != me && !isCrew(me, userId)) return null;
    final p = profiles[userId];
    return CrewMateDetail(
      mate: CrewMate(
        userId: userId,
        stageName: p?.stageName ?? 'Runner',
        color: p?.color ?? 0,
        since: links[_pair(me, userId)] ?? _clock,
        avatarBadge: p?.avatarBadge,
        avatarUrl: p?.avatarUrl,
      ),
      // Through JSON, like the server's copy.
      tour: switch (activeTour(userId)) {
        final t? => Tour.fromJson(t.toJson()),
        null => null,
      },
      shows: _posts((s) => s.owner == userId, 500),
    );
  }

  @override
  Future<void> encore(String postId, {required bool on}) async {
    final p = posts[postId];
    if (p == null || p.owner == me || !_visible(p)) return;
    final set = encores.putIfAbsent(postId, () => {});
    on ? set.add(me) : set.remove(me);
  }

  @override
  Future<void> report(CrewPost post, String reason) async {
    reports.add((postId: post.id, reason: reason));
    reported.add(post.id);
  }

  // ---- Tour invites ----

  /// Every Tour invite, sent and received.
  final tourInviteRows = <MemoryTourInvite>[];

  /// Finds [me]'s own Tour by id, the way the server finds a synced one.
  /// Defaults to the Tours given to [addTour]; tests and previews point it
  /// at the Tour repository.
  Future<Tour?> Function(String tourId)? myTour;

  /// [from] (a Crew mate) invites [me] onto [tour] (test and preview setup).
  /// Also books [tour] for [from].
  MemoryTourInvite addTourInvite(String from, Tour tour, {DateTime? at}) {
    if (!(tours[from]?.any((t) => t.id == tour.id) ?? false)) {
      addTour(from, tour);
    }
    final row = MemoryTourInvite(
      id: 'invite-${tourInviteRows.length + 1}',
      from: from,
      to: me,
      tour: tour,
      createdAt: at ?? _tick(),
    );
    tourInviteRows.add(row);
    return row;
  }

  DateTime get _today {
    final n = (today ?? DateTime.now()).toUtc();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Future<List<String>> inviteToTour(String tourId, List<String> userIds) async {
    _needProfile();
    final tour = myTour != null
        ? await myTour!(tourId)
        : tours[me]?.where((t) => t.id == tourId).firstOrNull;
    if (tour == null || tour.isDeleted) throw const TourNotSyncedException();
    if (tour.setup.raceDate.isBefore(_today)) {
      throw const CrewException('That Tour’s Opening Night has passed.');
    }
    final invited = <String>[];
    for (final id in {...userIds}) {
      if (id == me || !isCrew(me, id) || _blocked(me, id)) continue;
      invited.add(id);
      final i = tourInviteRows.indexWhere(
        (r) => r.from == me && r.to == id && r.tour.id == tourId,
      );
      if (i < 0) {
        tourInviteRows.add(
          MemoryTourInvite(
            id: 'invite-${tourInviteRows.length + 1}',
            from: me,
            to: id,
            tour: tour,
            createdAt: _tick(),
          ),
        );
      } else {
        tourInviteRows[i].tour = tour;
      }
    }
    return invited;
  }

  @override
  Future<List<CrewTourInvite>> tourInvites() async {
    final out = <CrewTourInvite>[];
    for (final r in tourInviteRows) {
      if (r.to != me || r.dismissed || !isCrew(me, r.from)) continue;
      if (_blocked(me, r.from)) continue;
      // The sender's latest copy of the Tour, as the server reads it.
      final tour =
          tours[r.from]?.where((t) => t.id == r.tour.id).firstOrNull ?? r.tour;
      if (tour.isDeleted || tour.setup.raceDate.isBefore(_today)) continue;
      final p = profiles[r.from];
      out.add(
        CrewTourInvite(
          id: r.id,
          fromUserId: r.from,
          fromStageName: p?.stageName ?? 'Runner',
          fromColor: p?.color ?? 0,
          tourId: tour.id,
          tourName: tour.name,
          raceDate: tour.setup.raceDate,
          raceDistance: tour.setup.raceDistance,
          createdAt: r.createdAt,
        ),
      );
    }
    out.sort((a, b) => a.raceDate.compareTo(b.raceDate));
    return out;
  }

  @override
  Future<void> dismissTourInvite(String id) async {
    for (final r in tourInviteRows) {
      if (r.id == id && r.to == me) r.dismissed = true;
    }
  }
  // ---- Profile pictures ----

  /// Runner id → their photo. URLs are `memory://avatar/<id>?v=<n>`.
  final photos = <String, Uint8List>{};
  final photoReports = <({String userId, String reason})>[];
  var _photoVersion = 0;

  /// Gives [userId] a photo (test and preview setup).
  void addPhoto(String userId, Uint8List jpeg) {
    photos[userId] = jpeg;
    final p = profiles[userId];
    if (p != null) {
      profiles[userId] = p.copyWith(
        avatarUrl: 'memory://avatar/$userId?v=${++_photoVersion}',
      );
    }
  }

  @override
  Future<CrewProfile> saveAvatarBadge(
    CrewProfile profile,
    String? badge,
  ) async {
    _needProfile();
    if (badge != null && !isAvatarBadge(badge)) {
      throw const CrewException('Pick one of the badges.');
    }
    return profiles[me] = profiles[me]!.copyWith(avatarBadge: badge);
  }

  @override
  Future<CrewProfile> uploadAvatar(Uint8List jpeg) async {
    _needProfile();
    if (jpeg.length > kMaxAvatarBytes ||
        jpeg.length < 3 ||
        jpeg[0] != 0xff ||
        jpeg[1] != 0xd8) {
      throw const CrewException('That photo didn’t work. Try another one.');
    }
    addPhoto(me, jpeg);
    return profiles[me]!;
  }

  @override
  Future<CrewProfile> removeAvatar() async {
    _needProfile();
    photos.remove(me);
    return profiles[me] = profiles[me]!.copyWith(avatarUrl: null);
  }

  @override
  Future<Uint8List> avatarBytes(String url) async {
    final id = Uri.parse(url).pathSegments.last;
    final bytes = photos[id];
    if (bytes == null || (id != me && (!isCrew(me, id) || _blocked(me, id)))) {
      throw const CrewException('That photo isn’t there anymore.');
    }
    return bytes;
  }

  @override
  Future<void> reportAvatar(String userId, String reason) async =>
      photoReports.add((userId: userId, reason: reason));

  // ---- Seen by, Encores and Shout-outs ----

  /// Whether [user] is the owner of [postId] or in their Crew, and not
  /// blocked either way with [me].
  bool _canSpeak(String user, _Post p) =>
      (user == p.owner || (isCrew(user, p.owner) && !_blocked(user, p.owner))) &&
      !_blocked(me, user);

  bool _named(String user) => user == me || (isCrew(me, user) && !_blocked(me, user));

  List<MapEntry<String, DateTime>> _viewers(String postId) {
    final out = [
      for (final e in (views[postId] ?? const <String, DateTime>{}).entries)
        if (_named(e.key) && (profiles[e.key]?.shareViews ?? true)) e,
    ]..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  CrewSeenSummary _seenSummary(String postId) {
    final v = _viewers(postId);
    return CrewSeenSummary(
      count: v.length,
      names: [
        for (final e in v.take(3)) profiles[e.key]?.stageName ?? 'Runner',
      ],
    );
  }

  CrewPerson _person(String userId, DateTime at) {
    final p = profiles[userId];
    return CrewPerson(
      userId: userId,
      stageName: p?.stageName ?? 'Runner',
      color: p?.color ?? 0,
      avatarBadge: p?.avatarBadge,
      avatarUrl: p?.avatarUrl,
      at: at,
    );
  }

  _Post _visiblePost(String postId) {
    final p = posts[postId];
    if (p == null || !_visible(p)) {
      throw const CrewException('That Show isn’t in your Crew’s feed anymore.');
    }
    return p;
  }

  @override
  Future<CrewProfile> setShareViews(CrewProfile profile, bool on) async {
    profiles[me] = (profiles[me] ?? profile).copyWith(shareViews: on);
    if (!on) {
      for (final v in views.values) {
        v.remove(me);
      }
    }
    return profiles[me]!;
  }

  @override
  Future<void> markSeen(String postId) async {
    final p = _visiblePost(postId);
    if (p.owner == me || !(profiles[me]?.shareViews ?? true)) return;
    views.putIfAbsent(postId, () => {}).putIfAbsent(me, _tick);
  }

  @override
  Future<CrewAudience> audience(String postId) async {
    final p = _visiblePost(postId);
    final fans = encores[postId] ?? const <String>{};
    final named = [for (final u in fans) if (_named(u)) u];
    return CrewAudience(
      encores: [for (final u in named) _person(u, _clock)],
      otherEncores: fans.length - named.length,
      seenBy: p.owner == me
          ? [for (final e in _viewers(postId)) _person(e.key, e.value)]
          : null,
    );
  }

  List<MemoryShoutout> _shoutoutsOn(String postId) {
    final p = posts[postId];
    if (p == null) return const [];
    return [
      for (final r in shoutoutRows)
        if (r.postId == postId &&
            _canSpeak(r.userId, p) &&
            !shoutoutReports.any((x) => x.id == r.id))
          r,
    ];
  }

  CrewShoutout _toShoutout(MemoryShoutout r) {
    final p = profiles[r.userId];
    final owner = posts[r.postId]?.owner;
    return CrewShoutout(
      id: r.id,
      userId: r.userId,
      stageName: p?.stageName ?? 'Runner',
      color: p?.color ?? 0,
      avatarBadge: p?.avatarBadge,
      avatarUrl: _named(r.userId) ? p?.avatarUrl : null,
      body: r.body,
      createdAt: r.createdAt,
      mine: r.userId == me,
      canDelete: r.userId == me || owner == me,
    );
  }

  @override
  Future<List<CrewShoutout>> shoutouts(String postId) async {
    _visiblePost(postId);
    return [for (final r in _shoutoutsOn(postId)) _toShoutout(r)];
  }

  /// [from] gives a Shout-out (test and preview setup).
  CrewShoutout addShoutoutFrom(String from, String postId, String body) {
    final r = MemoryShoutout(
      id: 'so${shoutoutRows.length + 1}',
      postId: postId,
      userId: from,
      body: body,
      createdAt: _tick(),
    );
    shoutoutRows.add(r);
    return _toShoutout(r);
  }

  @override
  Future<CrewShoutout> addShoutout(String postId, String body) async {
    final text = body.trim();
    if (text.isEmpty || text.runes.length > kMaxShoutoutChars) {
      throw const CrewException(
        'A Shout-out needs 1 to $kMaxShoutoutChars characters.',
      );
    }
    _visiblePost(postId);
    return addShoutoutFrom(me, postId, text);
  }

  @override
  Future<void> deleteShoutout(String id) async => shoutoutRows.removeWhere(
    (r) => r.id == id && (r.userId == me || posts[r.postId]?.owner == me),
  );

  @override
  Future<void> reportShoutout(String id, String reason) async =>
      shoutoutReports.add((id: id, reason: reason));
}

/// One Shout-out in [MemoryCrewService].
class MemoryShoutout {
  MemoryShoutout({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
}

/// One Tour invite in [MemoryCrewService].
class MemoryTourInvite {
  MemoryTourInvite({
    required this.id,
    required this.from,
    required this.to,
    required this.tour,
    required this.createdAt,
  });

  final String id;
  final String from;
  final String to;
  Tour tour;
  final DateTime createdAt;
  bool dismissed = false;
}

class _Post {
  _Post(this.owner, this.show, this.gearName, this.at);
  final String owner;
  final Show show;
  final String? gearName;
  final DateTime at;
}
