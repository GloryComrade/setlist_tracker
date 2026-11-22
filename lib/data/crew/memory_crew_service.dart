import '../../models/crew.dart';
import 'crew_service.dart';

/// [CrewService] that keeps everything in memory, with the same rules as the
/// server: only your Crew sees what you share, and a block cuts both ways.
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
  final posts = <String, _Post>{};
  final encores = <String, Set<String>>{};
  final reported = <String>{};
  final reports = <({String postId, String reason})>[];

  var _clock = DateTime.utc(2026, 11, 1);
  var _ids = 0;
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

  /// A Show shared by someone else (test and preview setup).
  String addPost(
    String owner,
    String showId,
    SharedShow show, {
    DateTime? at,
    int encoreCount = 0,
  }) {
    final id = 'post${_ids++}';
    posts[id] = _Post(id, owner, showId, show, at ?? _tick(), _clock);
    encores[id] = {for (var i = 0; i < encoreCount; i++) 'fan$i'};
    return id;
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
      alwaysShare: saved.alwaysShare,
      showOpeningNight: saved.showOpeningNight,
      openingNight: saved.showOpeningNight ? saved.openingNight : null,
      tourName: saved.showOpeningNight ? saved.tourName : null,
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
          openingNight: p?.openingNight,
          tourName: p?.tourName,
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

  @override
  Future<List<CrewPost>> feed() async {
    final visible =
        posts.values
            .where((p) => p.owner == me || isCrew(me, p.owner))
            .where((p) => !reported.contains(p.id))
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    return [
      for (final p in visible)
        CrewPost(
          id: p.id,
          ownerId: p.owner,
          stageName: profiles[p.owner]?.stageName ?? 'Runner',
          color: profiles[p.owner]?.color ?? 0,
          showId: p.showId,
          show: p.show,
          sharedAt: p.at,
          encores: encores[p.id]?.length ?? 0,
          encoredByMe: encores[p.id]?.contains(me) ?? false,
          mine: p.owner == me,
        ),
    ];
  }

  @override
  Future<Map<String, SharedInfo>> mySharedShows() async => {
    for (final p in posts.values)
      if (p.owner == me)
        p.showId: SharedInfo(
          showUpdatedAt: p.showUpdatedAt,
          includesNotes: p.show.includesNotes,
        ),
  };

  @override
  Future<void> share(
    String showId,
    SharedShow show,
    DateTime showUpdatedAt,
  ) async {
    _needProfile();
    final existing = posts.values
        .where((p) => p.owner == me && p.showId == showId)
        .firstOrNull;
    if (existing != null) {
      posts[existing.id] = _Post(
        existing.id,
        me,
        showId,
        show,
        existing.at,
        showUpdatedAt,
      );
      return;
    }
    final id = 'post${_ids++}';
    posts[id] = _Post(id, me, showId, show, _tick(), showUpdatedAt);
  }

  @override
  Future<void> unshare(String showId) async {
    final ids = posts.values
        .where((p) => p.owner == me && p.showId == showId)
        .map((p) => p.id)
        .toList();
    for (final id in ids) {
      posts.remove(id);
      encores.remove(id);
    }
  }

  @override
  Future<void> encore(String postId, {required bool on}) async {
    final p = posts[postId];
    if (p == null || p.owner == me || !isCrew(me, p.owner)) return;
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
  _Post(
    this.id,
    this.owner,
    this.showId,
    this.show,
    this.at,
    this.showUpdatedAt,
  );
  final String id;
  final String owner;
  final String showId;
  final SharedShow show;
  final DateTime at;
  final DateTime showUpdatedAt;
}
