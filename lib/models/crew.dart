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
  });

  final String userId;
  final String stageName;

  /// 0 to [kCrewColors] - 1.
  final int color;

  /// True for runners who joined The Crew before it saw every Show: until
  /// they OK the change, their Crew sees only the Shows they had shared.
  final bool allActivityPending;

  CrewProfile copyWith({
    String? stageName,
    int? color,
    bool? allActivityPending,
  }) => CrewProfile(
    userId: userId,
    stageName: stageName ?? this.stageName,
    color: color ?? this.color,
    allActivityPending: allActivityPending ?? this.allActivityPending,
  );
}

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
  });

  final String userId;
  final String stageName;
  final int color;
  final DateTime since;

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
  });

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

  String get showId => show.id;

  static String idFor(String ownerId, String showId) => '$ownerId:$showId';

  CrewPost withEncore(bool on) => CrewPost(
    id: id,
    ownerId: ownerId,
    stageName: stageName,
    color: color,
    show: show,
    gearName: gearName,
    sharedAt: sharedAt,
    encores: encores - (encoredByMe ? 1 : 0) + (on ? 1 : 0),
    encoredByMe: on,
    mine: mine,
  );

  /// `{id, ownerId, stageName, color, showId, show, gearName, sharedAt,
  /// encores, encoredByMe, mine}`.
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
    );
  }
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
