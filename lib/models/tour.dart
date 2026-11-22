import 'entity.dart';
import 'enums.dart';
import 'json_utils.dart';
import 'track.dart';

/// What the runner is aiming for on Opening Night.
enum TourGoal {
  finish('Finish strong', 'Cross the line feeling good'),
  targetTime('Target time', 'Chase a finish time'),
  bq('Boston qualifier', 'Run your BQ standard');

  const TourGoal(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static TourGoal fromName(String? name) => TourGoal.values.firstWhere(
    (v) => v.name == name,
    orElse: () => TourGoal.finish,
  );
}

/// Base / Build / Peak / Taper.
enum TourPhase {
  rehearsals('Rehearsals', 'Easy miles to build the base'),
  onTheRoad('On the Road', 'Mileage climbs, tempo runs start'),
  headlineLeg('Headline Leg', 'Peak weeks and the longest Headliners'),
  soundcheck('Soundcheck', 'Taper: less volume, fresh legs');

  const TourPhase(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static TourPhase fromName(String? name) => TourPhase.values.firstWhere(
    (v) => v.name == name,
    orElse: () => TourPhase.rehearsals,
  );
}

/// Where the runner would rather train.
enum VenuePreference {
  live('Mostly Live Shows', 'Outdoors whenever possible'),
  studio('Mostly Studio Sessions', 'Treadmill for most runs'),
  mix('A mix of both', 'Treadmill for workouts, outside for Headliners');

  const VenuePreference(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static VenuePreference fromName(String? name) => VenuePreference.values
      .firstWhere((v) => v.name == name, orElse: () => VenuePreference.live);
}

/// A recent race used to predict marathon time.
class RaceResult {
  const RaceResult({required this.distanceMiles, required this.timeSeconds});

  final double distanceMiles;
  final int timeSeconds;

  Map<String, Object?> toJson() => {
    'distanceMiles': distanceMiles,
    'timeSeconds': timeSeconds,
  };

  static RaceResult? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final d = asDouble(json['distanceMiles']);
    final t = asInt(json['timeSeconds']);
    if (d <= 0 || t <= 0) return null;
    return RaceResult(distanceMiles: d, timeSeconds: t);
  }
}

/// The answers from the "Book The Tour" quiz.
class TourSetup {
  const TourSetup({
    required this.raceDate,
    required this.goal,
    required this.currentWeeklyMiles,
    required this.longestRecentRunMiles,
    required this.daysPerWeek,
    required this.headlinerWeekday,
    required this.venuePreference,
    this.goalTimeSeconds,
    this.recentRace,
    this.easyPaceSecondsPerMile,
  });

  /// Opening Night, a local calendar date (no time).
  final DateTime raceDate;
  final TourGoal goal;

  /// Set for targetTime and bq goals.
  final int? goalTimeSeconds;
  final double currentWeeklyMiles;
  final double longestRecentRunMiles;
  final RaceResult? recentRace;

  /// Only asked when there's no race and no goal time to set paces from.
  final double? easyPaceSecondsPerMile;

  /// 3 to 6.
  final int daysPerWeek;

  /// DateTime.monday (1) to DateTime.sunday (7).
  final int headlinerWeekday;
  final VenuePreference venuePreference;

  Map<String, Object?> toJson() => {
    'raceDate': dateOnlyString(raceDate),
    'goal': goal.name,
    'goalTimeSeconds': goalTimeSeconds,
    'currentWeeklyMiles': currentWeeklyMiles,
    'longestRecentRunMiles': longestRecentRunMiles,
    'recentRace': recentRace?.toJson(),
    'easyPaceSecondsPerMile': easyPaceSecondsPerMile,
    'daysPerWeek': daysPerWeek,
    'headlinerWeekday': headlinerWeekday,
    'venuePreference': venuePreference.name,
  };

  factory TourSetup.fromJson(Map<String, Object?> json) => TourSetup(
    raceDate: parseDateOnly(json['raceDate']) ?? DateTime.now(),
    goal: TourGoal.fromName(asStringOrNull(json['goal'])),
    goalTimeSeconds: json['goalTimeSeconds'] == null
        ? null
        : asInt(json['goalTimeSeconds']),
    currentWeeklyMiles: asDouble(json['currentWeeklyMiles']),
    longestRecentRunMiles: asDouble(json['longestRecentRunMiles']),
    recentRace: RaceResult.fromJson(asMap(json['recentRace'])),
    easyPaceSecondsPerMile: asDoubleOrNull(json['easyPaceSecondsPerMile']),
    daysPerWeek: asInt(json['daysPerWeek'], 4).clamp(3, 6),
    headlinerWeekday: asInt(json['headlinerWeekday'], 7).clamp(1, 7),
    venuePreference: VenuePreference.fromName(
      asStringOrNull(json['venuePreference']),
    ),
  );
}

/// Training paces in seconds per mile. Null on effort-only Tours.
class TourPaces {
  const TourPaces({
    required this.predictedMarathonSeconds,
    required this.marathon,
    required this.easySlow,
    required this.easyFast,
    required this.tempo,
    required this.interval,
    required this.source,
  });

  final int predictedMarathonSeconds;
  final double marathon;

  /// Easy runs and Headliners fall between these two paces.
  final double easySlow;
  final double easyFast;
  final double tempo;
  final double interval;

  /// Where the paces came from: "recentRace", "goalTime" or "easyPace".
  final String source;

  /// Middle of the easy range, used for planning time and treadmill speed.
  double get easy => (easySlow + easyFast) / 2;

  Map<String, Object?> toJson() => {
    'predictedMarathonSeconds': predictedMarathonSeconds,
    'marathon': marathon,
    'easySlow': easySlow,
    'easyFast': easyFast,
    'tempo': tempo,
    'interval': interval,
    'source': source,
  };

  static TourPaces? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    return TourPaces(
      predictedMarathonSeconds: asInt(json['predictedMarathonSeconds']),
      marathon: asDouble(json['marathon']),
      easySlow: asDouble(json['easySlow']),
      easyFast: asDouble(json['easyFast']),
      tempo: asDouble(json['tempo']),
      interval: asDouble(json['interval']),
      source: asStringOrNull(json['source']) ?? 'goalTime',
    );
  }
}

/// One run on the Tour Schedule.
class PlannedShow {
  const PlannedShow({
    required this.id,
    required this.date,
    required this.workoutType,
    required this.distanceMiles,
    required this.venue,
    required this.title,
    this.detail,
    this.targetPaceSecondsPerMile,
    this.plannedDurationSeconds,
    this.tracks = const [],
  });

  final String id;

  /// Local calendar date.
  final DateTime date;
  final WorkoutType workoutType;
  final double distanceMiles;
  final Venue venue;

  /// Short name, e.g. "Tempo" or "Headliner".
  final String title;

  /// What to do, e.g. "1 mi easy, 3 mi at tempo, 1 mi easy".
  final String? detail;

  /// Main pace of the run. Null on effort-only Tours.
  final double? targetPaceSecondsPerMile;

  /// Expected time at the planned paces.
  final int? plannedDurationSeconds;

  /// Ready-made treadmill program for Studio Sessions.
  final List<Track> tracks;

  bool get isRace => workoutType == WorkoutType.race;

  Map<String, Object?> toJson() => {
    'id': id,
    'date': dateOnlyString(date),
    'workoutType': workoutType.name,
    'distanceMiles': distanceMiles,
    'venue': venue.name,
    'title': title,
    'detail': detail,
    'targetPaceSecondsPerMile': targetPaceSecondsPerMile,
    'plannedDurationSeconds': plannedDurationSeconds,
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory PlannedShow.fromJson(Map<String, Object?> json) => PlannedShow(
    id: '${json['id']}',
    date: parseDateOnly(json['date']) ?? DateTime.now(),
    workoutType: WorkoutType.fromName(asStringOrNull(json['workoutType'])),
    distanceMiles: asDouble(json['distanceMiles']),
    venue: Venue.fromName(asStringOrNull(json['venue'])),
    title: asStringOrNull(json['title']) ?? 'Show',
    detail: asStringOrNull(json['detail']),
    targetPaceSecondsPerMile: asDoubleOrNull(json['targetPaceSecondsPerMile']),
    plannedDurationSeconds: json['plannedDurationSeconds'] == null
        ? null
        : asInt(json['plannedDurationSeconds']),
    tracks: asMapList(json['tracks']).map(Track.fromJson).toList(),
  );
}

/// Seven days of the Tour. The last week ends on Opening Night.
class TourWeek {
  const TourWeek({
    required this.number,
    required this.startDate,
    required this.phase,
    required this.isRestStop,
    required this.shows,
  });

  /// 1-based.
  final int number;
  final DateTime startDate;
  final TourPhase phase;
  final bool isRestStop;
  final List<PlannedShow> shows;

  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + 6);

  double get plannedMiles => shows.fold(0.0, (sum, s) => sum + s.distanceMiles);

  PlannedShow? get headliner {
    for (final s in shows) {
      if (s.workoutType == WorkoutType.long) return s;
    }
    return null;
  }

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'startDate': dateOnlyString(startDate),
    'phase': phase.name,
    'isRestStop': isRestStop,
    'shows': shows.map((s) => s.toJson()).toList(),
  };

  factory TourWeek.fromJson(Map<String, Object?> json) => TourWeek(
    number: asInt(json['number'], 1),
    startDate: parseDateOnly(json['startDate']) ?? DateTime.now(),
    phase: TourPhase.fromName(asStringOrNull(json['phase'])),
    isRestStop: json['isRestStop'] == true,
    shows: asMapList(json['shows']).map(PlannedShow.fromJson).toList(),
  );
}

/// A training plan: every week from the first Rehearsal to Opening Night.
class Tour implements Entity {
  const Tour({
    required this.id,
    required this.name,
    required this.setup,
    required this.weeks,
    required this.createdAt,
    required this.updatedAt,
    this.paces,
    this.warnings = const [],
    this.deletedAt,
  });

  @override
  final String id;
  final String name;
  final TourSetup setup;
  final TourPaces? paces;
  final List<TourWeek> weeks;

  /// Notes from the builder, e.g. "Short Tour". Shown on the schedule.
  final List<String> warnings;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  DateTime get raceDate => setup.raceDate;
  DateTime get startDate => weeks.first.startDate;

  Iterable<PlannedShow> get allShows => weeks.expand((w) => w.shows);

  PlannedShow? showById(String id) {
    for (final s in allShows) {
      if (s.id == id) return s;
    }
    return null;
  }

  TourWeek? weekOf(String plannedShowId) {
    for (final w in weeks) {
      if (w.shows.any((s) => s.id == plannedShowId)) return w;
    }
    return null;
  }

  /// The week [day] falls in, or null before or after the Tour.
  TourWeek? weekContaining(DateTime day) {
    for (final w in weeks) {
      if (w.contains(day)) return w;
    }
    return null;
  }

  Tour copyWith({DateTime? updatedAt, DateTime? deletedAt}) => Tour(
    id: id,
    name: name,
    setup: setup,
    paces: paces,
    weeks: weeks,
    warnings: warnings,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': kSchemaVersion,
    'id': id,
    'name': name,
    'setup': setup.toJson(),
    'paces': paces?.toJson(),
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'warnings': warnings,
    'createdAt': utcString(createdAt),
    'updatedAt': utcString(updatedAt),
    'deletedAt': deletedAt == null ? null : utcString(deletedAt!),
  };

  factory Tour.fromJson(Map<String, Object?> json) {
    final created = parseDate(json['createdAt']) ?? DateTime.now().toUtc();
    final rawWarnings = json['warnings'];
    return Tour(
      id: '${json['id']}',
      name: asStringOrNull(json['name']) ?? 'The Tour',
      setup: TourSetup.fromJson(asMap(json['setup']) ?? const {}),
      paces: TourPaces.fromJson(asMap(json['paces'])),
      weeks: asMapList(json['weeks']).map(TourWeek.fromJson).toList(),
      warnings: rawWarnings is List
          ? rawWarnings.map((w) => '$w').toList()
          : const [],
      createdAt: created,
      updatedAt: parseDate(json['updatedAt']) ?? created,
      deletedAt: parseDate(json['deletedAt']),
    );
  }
}
