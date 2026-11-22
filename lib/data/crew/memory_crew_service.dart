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
    );
    return profiles[me]!;
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
}

class _Post {
  _Post(this.owner, this.show, this.gearName, this.at);
  final String owner;
  final Show show;
  final String? gearName;
  final DateTime at;
}
