/// The Crew: running friends who see each other's Shows.
///
/// Everything here comes from the server (the Cloudflare Worker), which reads
/// the Setlists the app already syncs. Your Crew sees every Show you log,
/// except the ones marked "Keep off the Crew" ([Show.crewPrivate]), and your
/// active Tour.
library;

import 'json_utils.dart';
import 'show.dart';
import 'tour.dart';

/// How many avatar colors there are (see `crewColor` in the UI).
const kCrewColors = 4;

/// Your stage name and avatar color.
class CrewProfile {
  const CrewProfile({
    required this.userId,
    required this.stageName,
    this.color = 0,
    this.allActivityPending = false,
    this.avatarBadge,
    this.avatarUrl,
    this.shareViews = true,
    this.pushShows = true,
    this.pushShoutouts = true,
  });

  final String userId;
  final String stageName;

  /// 0 to [kCrewColors] - 1.
  final int color;

  /// True for runners who joined The Crew before it saw every Show: until
  /// they OK the change, their Crew sees only the Shows they had shared.
  final bool allActivityPending;

  /// A drawn tour-art badge id (`kAvatarBadges` in the UI), or null.
  final String? avatarBadge;

  /// Where the uploaded photo is fetched from, or null without one. A new
  /// photo gets a new address.
  final String? avatarUrl;

  /// "Let my Crew know when I've seen their Shows". Off, your views of
  /// their Shows aren't recorded (and the old ones are forgotten).
  final bool shareViews;

  /// "When my Crew logs a Show": a push notification on iPhone when a Crew
  /// mate logs a new Show.
  final bool pushShows;

  /// "Shout-outs on my Shows": a push notification on iPhone when someone
  /// gives a Shout-out on one of your Shows.
  final bool pushShoutouts;

  /// Pass null as [avatarBadge] or [avatarUrl] to clear it.
  CrewProfile copyWith({
    String? stageName,
    int? color,
    bool? allActivityPending,
    bool? shareViews,
    bool? pushShows,
    bool? pushShoutouts,
    Object? avatarBadge = _keep,
    Object? avatarUrl = _keep,
  }) => CrewProfile(
    userId: userId,
    stageName: stageName ?? this.stageName,
    color: color ?? this.color,
    allActivityPending: allActivityPending ?? this.allActivityPending,
    avatarBadge: identical(avatarBadge, _keep)
        ? this.avatarBadge
        : avatarBadge as String?,
    avatarUrl: identical(avatarUrl, _keep)
        ? this.avatarUrl
        : avatarUrl as String?,
    shareViews: shareViews ?? this.shareViews,
    pushShows: pushShows ?? this.pushShows,
    pushShoutouts: pushShoutouts ?? this.pushShoutouts,
  );

  /// `{userId, stageName, color, allActivityPending, avatarBadge, avatarUrl,
  /// shareViews, pushShows, pushShoutouts}`.
  factory CrewProfile.fromJson(Map<String, Object?> r) => CrewProfile(
    userId: '${r['userId']}',
    stageName: '${r['stageName']}',
    color: asInt(r['color']),
    allActivityPending: r['allActivityPending'] == true,
    avatarBadge: asStringOrNull(r['avatarBadge']),
    avatarUrl: asStringOrNull(r['avatarUrl']),
    shareViews: r['shareViews'] != false,
    pushShows: r['pushShows'] != false,
    pushShoutouts: r['pushShoutouts'] != false,
  );
}

/// "Leave as it is" for nullable copyWith arguments.
const _keep = Object();

/// A Crew mate's active Tour, as the mates list carries it.
class CrewTourSummary {
  const CrewTourSummary({
    required this.id,
    required this.name,
    required this.raceDate,
    this.raceDistance = RaceDistance.marathon,
    this.featuring,
  });

  final String id;
  final String name;

  /// Opening Night, a local calendar date.
  final DateTime raceDate;
  final RaceDistance raceDistance;

  /// Who that Tour was booked featuring, if anyone.
  final ({String userId, String stageName})? featuring;

  factory CrewTourSummary.fromTour(Tour t) => CrewTourSummary(
    id: t.id,
    name: t.name,
    raceDate: t.setup.raceDate,
    raceDistance: t.setup.raceDistance,
    featuring: t.featuring,
  );

  /// `{id, name, raceDate: "YYYY-MM-DD", raceDistance, featuring}`.
  static CrewTourSummary? fromJson(Map<String, Object?>? json) {
    final date = parseDateOnly(json?['raceDate']);
    if (json == null || date == null) return null;
    return CrewTourSummary(
      id: '${json['id']}',
      name: asStringOrNull(json['name']) ?? 'The Tour',
      raceDate: date,
      raceDistance: RaceDistance.fromName(asStringOrNull(json['raceDistance'])),
      featuring: TourFeaturing.fromJson(asMap(json['featuring'])),
    );
  }

  /// True when [tour] races the same Opening Night as this one.
  bool sameRaceAs(Tour tour) => sameRace(
    raceDate,
    raceDistance,
    tour.setup.raceDate,
    tour.setup.raceDistance,
  );
}

/// Someone in your Crew (or someone you blocked).
class CrewMate {
  const CrewMate({
    required this.userId,
    required this.stageName,
    required this.color,
    required this.since,
    this.tour,
    this.blocked = false,
    this.avatarBadge,
    this.avatarUrl,
  });

  final String userId;
  final String stageName;
  final int color;
  final DateTime since;

  /// See [CrewProfile.avatarBadge]. Always null on runners you blocked.
  final String? avatarBadge;

  /// See [CrewProfile.avatarUrl]. Always null on runners you blocked.
  final String? avatarUrl;

  /// Their active Tour, or null when they have none.
  final CrewTourSummary? tour;
  final bool blocked;

  factory CrewMate.fromJson(Map<String, Object?> m) => CrewMate(
    userId: '${m['userId']}',
    stageName: asStringOrNull(m['stageName']) ?? 'Runner',
    color: asInt(m['color']),
    since: parseDate(m['since']) ?? DateTime.now(),
    tour: CrewTourSummary.fromJson(asMap(m['tour'])),
    blocked: m['blocked'] == true,
    avatarBadge: asStringOrNull(m['avatarBadge']),
    avatarUrl: asStringOrNull(m['avatarUrl']),
  );
}

/// Who sent an invite code.
class CrewInvitePreview {
  const CrewInvitePreview({
    required this.stageName,
    required this.color,
    this.alreadyCrew = false,
    this.ownInvite = false,
  });

  final String stageName;
  final int color;
  final bool alreadyCrew;
  final bool ownInvite;
}

/// A Show on the Crew feed (or on a Crew mate's page): the whole Show, as
/// its owner logged it.
class CrewPost {
  const CrewPost({
    required this.id,
    required this.ownerId,
    required this.stageName,
    required this.color,
    required this.show,
    required this.sharedAt,
    this.gearName,
    this.encores = 0,
    this.encoredByMe = false,
    this.mine = false,
    this.avatarBadge,
    this.avatarUrl,
    this.shoutouts = 0,
    this.seenBy,
  });

  /// The owner's picture: see [CrewProfile.avatarBadge].
  final String? avatarBadge;
  final String? avatarUrl;

  /// `<ownerId>:<showId>`.
  final String id;
  final String ownerId;
  final String stageName;
  final int color;
  final Show show;

  /// The name of the Gear the Show was run in, if any.
  final String? gearName;

  /// When the Show was last saved.
  final DateTime sharedAt;
  final int encores;
  final bool encoredByMe;
  final bool mine;

  /// How many Shout-outs you can read on it.
  final int shoutouts;

  /// Who saw it: only on your own Shows, null on everyone else's.
  final CrewSeenSummary? seenBy;

  String get showId => show.id;

  static String idFor(String ownerId, String showId) => '$ownerId:$showId';

  CrewPost _copy({
    int? encores,
    bool? encoredByMe,
    Object? avatarBadge = _keep,
    Object? avatarUrl = _keep,
    int? shoutouts,
  }) => CrewPost(
    id: id,
    ownerId: ownerId,
    stageName: stageName,
    color: color,
    show: show,
    gearName: gearName,
    sharedAt: sharedAt,
    encores: encores ?? this.encores,
    encoredByMe: encoredByMe ?? this.encoredByMe,
    mine: mine,
    avatarBadge: identical(avatarBadge, _keep)
        ? this.avatarBadge
        : avatarBadge as String?,
    avatarUrl: identical(avatarUrl, _keep)
        ? this.avatarUrl
        : avatarUrl as String?,
    shoutouts: shoutouts ?? this.shoutouts,
    seenBy: seenBy,
  );

  /// The same post with the owner's new picture.
  CrewPost withPicture(String? badge, String? url) =>
      _copy(avatarBadge: badge, avatarUrl: url);

  CrewPost withEncore(bool on) => _copy(
    encores: encores - (encoredByMe ? 1 : 0) + (on ? 1 : 0),
    encoredByMe: on,
  );

  CrewPost withShoutouts(int n) => _copy(shoutouts: n);

  /// `{id, ownerId, stageName, color, showId, show, gearName, sharedAt,
  /// encores, encoredByMe, mine, shoutouts, seenBy}`.
  factory CrewPost.fromJson(Map<String, Object?> p) {
    final ownerId = '${p['ownerId']}';
    final showJson = {...?asMap(p['show'])};
    // The record id wins when the Show JSON lacks one.
    showJson['id'] ??= p['showId'];
    final show = Show.fromJson(showJson);
    return CrewPost(
      id: asStringOrNull(p['id']) ?? idFor(ownerId, show.id),
      ownerId: ownerId,
      stageName: asStringOrNull(p['stageName']) ?? 'Runner',
      color: asInt(p['color']),
      show: show,
      gearName: asStringOrNull(p['gearName']),
      sharedAt: parseDate(p['sharedAt'])?.toLocal() ?? DateTime.now(),
      encores: asInt(p['encores']),
      encoredByMe: p['encoredByMe'] == true,
      mine: p['mine'] == true,
      avatarBadge: asStringOrNull(p['avatarBadge']),
      avatarUrl: asStringOrNull(p['avatarUrl']),
      shoutouts: asInt(p['shoutouts']),
      seenBy: switch (asMap(p['seenBy'])) {
        final m? => CrewSeenSummary.fromJson(m),
        null => null,
      },
    );
  }
}

/// "Seen by Maya, Sam +2": who saw one of your Shows.
class CrewSeenSummary {
  const CrewSeenSummary({this.count = 0, this.names = const []});

  final int count;

  /// The latest few stage names, newest first.
  final List<String> names;

  /// `{count, names}`.
  factory CrewSeenSummary.fromJson(Map<String, Object?> m) => CrewSeenSummary(
    count: asInt(m['count']),
    names: [for (final n in (m['names'] as List?) ?? const []) '$n'],
  );
}

/// Someone on a Show's Encore or Seen by list.
class CrewPerson {
  const CrewPerson({
    required this.userId,
    required this.stageName,
    this.color = 0,
    this.avatarBadge,
    this.avatarUrl,
    required this.at,
  });

  final String userId;
  final String stageName;
  final int color;
  final String? avatarBadge;
  final String? avatarUrl;

  /// When they gave the Encore, or first saw the Show.
  final DateTime at;

  /// `{userId, stageName, color, avatarBadge, avatarUrl, at}`.
  factory CrewPerson.fromJson(Map<String, Object?> m) => CrewPerson(
    userId: '${m['userId']}',
    stageName: asStringOrNull(m['stageName']) ?? 'Runner',
    color: asInt(m['color']),
    avatarBadge: asStringOrNull(m['avatarBadge']),
    avatarUrl: asStringOrNull(m['avatarUrl']),
    at: parseDate(m['at'])?.toLocal() ?? DateTime.now(),
  );
}

/// Who gave a Show an Encore and, on your own Shows, who saw it.
class CrewAudience {
  const CrewAudience({
    this.encores = const [],
    this.otherEncores = 0,
    this.seenBy,
  });

  /// Encores from you and your Crew, newest first.
  final List<CrewPerson> encores;

  /// Encores from runners outside your Crew, counted but not named.
  final int otherEncores;

  /// Null unless the Show is yours.
  final List<CrewPerson>? seenBy;

  /// `{encores, otherEncores, seenBy}`.
  factory CrewAudience.fromJson(Map<String, Object?> m) => CrewAudience(
    encores: asMapList(m['encores']).map(CrewPerson.fromJson).toList(),
    otherEncores: asInt(m['otherEncores']),
    seenBy: m['seenBy'] == null
        ? null
        : asMapList(m['seenBy']).map(CrewPerson.fromJson).toList(),
  );
}

/// The longest Shout-out, in characters.
const kMaxShoutoutChars = 280;

/// A Shout-out: a short comment on a Show from its owner or their Crew.
class CrewShoutout {
  const CrewShoutout({
    required this.id,
    required this.userId,
    required this.stageName,
    this.color = 0,
    this.avatarBadge,
    this.avatarUrl,
    required this.body,
    required this.createdAt,
    this.mine = false,
    this.canDelete = false,
  });

  final String id;
  final String userId;
  final String stageName;
  final int color;
  final String? avatarBadge;
  final String? avatarUrl;
  final String body;
  final DateTime createdAt;

  /// You wrote it.
  final bool mine;

  /// You wrote it, or it's on your Show.
  final bool canDelete;

  /// `{id, userId, stageName, color, avatarBadge, avatarUrl, body,
  /// createdAt, mine, canDelete}`.
  factory CrewShoutout.fromJson(Map<String, Object?> m) => CrewShoutout(
    id: '${m['id']}',
    userId: '${m['userId']}',
    stageName: asStringOrNull(m['stageName']) ?? 'Runner',
    color: asInt(m['color']),
    avatarBadge: asStringOrNull(m['avatarBadge']),
    avatarUrl: asStringOrNull(m['avatarUrl']),
    body: asStringOrNull(m['body']) ?? '',
    createdAt: parseDate(m['createdAt'])?.toLocal() ?? DateTime.now(),
    mine: m['mine'] == true,
    canDelete: m['canDelete'] == true,
  );
}

/// Everything on a Crew mate's page: who they are, their active Tour and
/// their whole Setlist (minus Shows kept off the Crew).
class CrewMateDetail {
  const CrewMateDetail({required this.mate, this.tour, this.shows = const []});

  final CrewMate mate;
  final Tour? tour;

  /// Newest first.
  final List<CrewPost> shows;

  /// `{mate: {userId, stageName, color, since}, tour: Tour|null, shows: [Post]}`.
  factory CrewMateDetail.fromJson(Map<String, Object?> json) {
    final tour = asMap(json['tour']);
    return CrewMateDetail(
      mate: CrewMate.fromJson(asMap(json['mate']) ?? const {}),
      tour: tour == null ? null : Tour.fromJson(tour),
      shows: asMapList(json['shows']).map(CrewPost.fromJson).toList(),
    );
  }
}

/// How a Crew mate's current Tour week is going.
class CrewWeekProgress {
  const CrewWeekProgress({
    required this.week,
    required this.showsDone,
    required this.showsPlanned,
    required this.miles,
    required this.plannedMiles,
  });

  final TourWeek week;
  final int showsDone;
  final int showsPlanned;

  /// Miles logged so far this week.
  final double miles;
  final double plannedMiles;

  /// Their week containing [today], or null before or after the Tour.
  /// A planned Show counts as done when a Show was logged for it, or logged
  /// on its day (the same rule as the Tour tab's checkmarks).
  static CrewWeekProgress? of(Tour tour, List<Show> shows, DateTime today) {
    final week = tour.weekContaining(today);
    if (week == null) return null;
    final inWeek = shows
        .where((s) => !s.isDeleted && week.contains(s.date))
        .toList();
    final planned = week.shows.where((p) => !p.skipped).toList();
    final linked = {for (final s in inWeek) ?s.plannedShowId};
    final freeDays = [
      for (final s in inWeek)
        if (s.plannedShowId == null)
          DateTime(s.date.year, s.date.month, s.date.day),
    ];
    var done = 0;
    for (final p in planned) {
      if (linked.contains(p.id)) {
        done++;
      } else if (freeDays.remove(p.date)) {
        done++;
      }
    }
    return CrewWeekProgress(
      week: week,
      showsDone: done,
      showsPlanned: planned.length,
      miles: inWeek.fold(0.0, (t, s) => t + s.distanceMiles),
      plannedMiles: week.plannedMiles,
    );
  }
}

/// "Ryan invited you on the Spring 2027 Half Tour": a Crew mate asking you
/// to book a Tour for the same Opening Night.
class CrewTourInvite {
  const CrewTourInvite({
    required this.id,
    required this.fromUserId,
    required this.fromStageName,
    required this.tourId,
    required this.tourName,
    required this.raceDate,
    required this.createdAt,
    this.fromColor = 0,
    this.raceDistance = RaceDistance.marathon,
  });

  final String id;
  final String fromUserId;
  final String fromStageName;
  final int fromColor;
  final String tourId;
  final String tourName;

  /// Opening Night, a local calendar date.
  final DateTime raceDate;
  final RaceDistance raceDistance;
  final DateTime createdAt;

  /// What "Join the Tour" hands to Book The Tour.
  TourFeaturing get featuring => TourFeaturing(
    userId: fromUserId,
    stageName: fromStageName,
    raceDate: raceDate,
    raceDistance: raceDistance,
    tourName: tourName,
  );

  /// True when [tour] races the same Opening Night.
  bool sameRaceAs(Tour tour) => sameRace(
    raceDate,
    raceDistance,
    tour.setup.raceDate,
    tour.setup.raceDistance,
  );

  /// `{id, from: {userId, stageName, color}, tourId, tourName,
  /// raceDate: "YYYY-MM-DD", raceDistance, createdAt}`. Null without a
  /// race date.
  static CrewTourInvite? fromJson(Map<String, Object?> json) {
    final date = parseDateOnly(json['raceDate']);
    if (date == null) return null;
    final from = asMap(json['from']) ?? const {};
    return CrewTourInvite(
      id: '${json['id']}',
      fromUserId: '${from['userId']}',
      fromStageName: asStringOrNull(from['stageName']) ?? 'Runner',
      fromColor: asInt(from['color']),
      tourId: '${json['tourId']}',
      tourName: asStringOrNull(json['tourName']) ?? 'The Tour',
      raceDate: date,
      raceDistance: RaceDistance.fromName(asStringOrNull(json['raceDistance'])),
      createdAt: parseDate(json['createdAt'])?.toLocal() ?? DateTime.now(),
    );
  }
}
