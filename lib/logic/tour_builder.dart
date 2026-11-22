/// Builds The Tour from the setup quiz. Rules only, no AI, no Flutter imports,
/// so every rule here is covered by unit tests (test/tour_builder_test.dart).
library;

import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/tour.dart';
import '../models/track.dart';
import 'show_math.dart';

const double kMarathonMiles = kFullMarathonMiles;
const double k5kMiles = 3.10686;

/// Shortest marathon Tour the builder will make at all.
const int kMinTourWeeks = 6;

/// Under this, the builder warns that the marathon is too soon.
const int kShortTourWeeks = 12;

/// The usual range for a marathon plan.
const int kIdealMinTourWeeks = 16;
const int kMaxTourWeeks = 20;

/// The plan rules that change with the race distance.
class DistanceRules {
  const DistanceRules({
    required this.minWeeks,
    required this.shortWeeks,
    required this.idealMinWeeks,
    required this.maxWeeks,
    required this.suggestWeeks,
    required this.peakLongFinish,
    required this.peakLongStrong,
    required this.peakWeekMiles,
    required this.peakGap,
    required this.headlinerRaceFinish,
  });

  /// Shortest Tour the builder will make at all.
  final int minWeeks;

  /// Under this, warn that the race is too soon.
  final int shortWeeks;

  /// The usual range.
  final int idealMinWeeks;
  final int maxWeeks;

  /// "Help me pick" puts the race this many weeks out.
  final int suggestWeeks;

  /// Top Headliner for a finish goal or a light base, and for everyone else.
  final double peakLongFinish;
  final double peakLongStrong;

  /// Peak weekly miles for finish, target time and BQ goals.
  final (double, double, double) peakWeekMiles;

  /// Weeks between the top Headliner and race week.
  final int peakGap;

  /// Headline Leg Headliners finish with a few miles at race pace. Short
  /// races skip it: 5K and 10K pace belongs in the interval sessions.
  final bool headlinerRaceFinish;

  /// Soundcheck weeks, counting race week.
  int taperWeeks(int weeks) => peakGap >= 3 ? (weeks >= 18 ? 3 : 2) : peakGap;
}

DistanceRules rulesFor(RaceDistance d) => switch (d) {
  RaceDistance.fiveK => const DistanceRules(
    minWeeks: 4,
    shortWeeks: 6,
    idealMinWeeks: 8,
    maxWeeks: 12,
    suggestWeeks: 10,
    peakLongFinish: 6,
    peakLongStrong: 8,
    peakWeekMiles: (15, 22, 22),
    peakGap: 1,
    headlinerRaceFinish: false,
  ),
  RaceDistance.tenK => const DistanceRules(
    minWeeks: 5,
    shortWeeks: 8,
    idealMinWeeks: 10,
    maxWeeks: 14,
    suggestWeeks: 12,
    peakLongFinish: 8,
    peakLongStrong: 10,
    peakWeekMiles: (20, 28, 28),
    peakGap: 1,
    headlinerRaceFinish: false,
  ),
  RaceDistance.half => const DistanceRules(
    minWeeks: 6,
    shortWeeks: 10,
    idealMinWeeks: 12,
    maxWeeks: 16,
    suggestWeeks: 14,
    peakLongFinish: 10,
    peakLongStrong: 12,
    peakWeekMiles: (26, 33, 33),
    peakGap: 2,
    headlinerRaceFinish: true,
  ),
  RaceDistance.marathon => const DistanceRules(
    minWeeks: kMinTourWeeks,
    shortWeeks: kShortTourWeeks,
    idealMinWeeks: kIdealMinTourWeeks,
    maxWeeks: kMaxTourWeeks,
    suggestWeeks: 18,
    peakLongFinish: 18,
    peakLongStrong: 20,
    peakWeekMiles: (36, 42, 50),
    peakGap: 3,
    headlinerRaceFinish: true,
  ),
};

/// Treadmill incline that makes up for no wind resistance.
const double kStudioInclinePercent = 1.0;

// ---------------------------------------------------------------------------
// Paces
// ---------------------------------------------------------------------------

/// Riegel's formula: T2 = T1 × (D2 / D1)^1.06.
double riegelSeconds(double t1Seconds, double d1Miles, double d2Miles) =>
    t1Seconds * math.pow(d2Miles / d1Miles, 1.06);

/// Marathon finish time predicted from a race of any distance.
int predictMarathonSeconds(RaceResult race) => riegelSeconds(
  race.timeSeconds.toDouble(),
  race.distanceMiles,
  kMarathonMiles,
).round();

/// Training paces from a marathon time. [raceMiles] sets the Opening Night
/// pace for shorter races (Riegel from the marathon time).
///
/// - Easy runs and Headliners: 60 to 90 seconds per mile slower than
///   marathon pace.
/// - Tempo: the pace Riegel predicts for 10 miles, roughly threshold effort.
/// - Intervals: the pace Riegel predicts for 5K.
TourPaces pacesFromMarathon(
  int marathonSeconds,
  String source, {
  double raceMiles = kMarathonMiles,
  double? raceSeconds,
}) {
  final t = marathonSeconds.toDouble();
  final mp = t / kMarathonMiles;
  final rs = raceSeconds ?? riegelSeconds(t, kMarathonMiles, raceMiles);
  return TourPaces(
    predictedMarathonSeconds: marathonSeconds,
    marathon: mp,
    easySlow: mp + 90,
    easyFast: mp + 60,
    tempo: riegelSeconds(t, kMarathonMiles, 10) / 10,
    interval: riegelSeconds(t, kMarathonMiles, k5kMiles) / k5kMiles,
    source: source,
    race: raceMiles == kMarathonMiles ? mp : rs / raceMiles,
    raceMiles: raceMiles,
  );
}

/// Picks the best source for paces: a recent race first, then the goal time,
/// then the runner's usual easy pace. Null means an effort-only Tour.
TourPaces? pacesFor(TourSetup setup) {
  final miles = raceMilesFor(setup.raceDistance);
  final race = setup.recentRace;
  if (race != null) {
    return pacesFromMarathon(
      predictMarathonSeconds(race),
      'recentRace',
      raceMiles: miles,
      raceSeconds: riegelSeconds(
        race.timeSeconds.toDouble(),
        race.distanceMiles,
        miles,
      ),
    );
  }
  final goal = setup.goalTimeSeconds;
  if (setup.goal != TourGoal.finish && goal != null && goal > 0) {
    // The goal is for Opening Night's distance; training paces come from
    // the marathon time it's worth.
    return pacesFromMarathon(
      riegelSeconds(goal.toDouble(), miles, kMarathonMiles).round(),
      'goalTime',
      raceMiles: miles,
      raceSeconds: goal.toDouble(),
    );
  }
  final easy = setup.easyPaceSecondsPerMile;
  if (easy != null && easy > 0) {
    // Easy pace is about 75 s/mi slower than marathon pace.
    final mp = math.max(easy - 75, 240.0);
    return pacesFromMarathon(
      (mp * kMarathonMiles).round(),
      'easyPace',
      raceMiles: miles,
    );
  }
  return null;
}

/// Race miles as the plan uses them. A marathon stays 26.2 so older Tours
/// read the same.
double raceMilesFor(RaceDistance d) =>
    d == RaceDistance.marathon ? kMarathonMiles : d.miles;

/// Predicted Opening Night time from a recent race of any distance.
int predictRaceSeconds(RaceResult race, RaceDistance d) => riegelSeconds(
  race.timeSeconds.toDouble(),
  race.distanceMiles,
  raceMilesFor(d),
).round();

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole days from [a] to [b], safe across daylight-saving changes.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Full seven-day weeks that fit from [today] through Opening Night.
int weeksUntil(DateTime today, DateTime raceDate) {
  final days = daysBetween(today, raceDate);
  if (days < 0) return 0;
  return (days + 1) ~/ 7;
}

/// The "help me pick" date: the first Sunday at least 18 weeks out (fewer
/// for shorter races, see [DistanceRules.suggestWeeks]).
DateTime suggestedRaceDate(
  DateTime today, [
  RaceDistance distance = RaceDistance.marathon,
]) {
  final d = _addDays(_day(today), rulesFor(distance).suggestWeeks * 7);
  return _addDays(d, (DateTime.sunday - d.weekday) % 7);
}

/// "Spring 2027 Tour" from the race date; "Spring 2027 Half Tour" for
/// shorter races.
String tourNameFor(
  DateTime raceDate, [
  RaceDistance distance = RaceDistance.marathon,
]) {
  final m = raceDate.month;
  final season = switch (m) {
    3 || 4 || 5 => 'Spring',
    6 || 7 || 8 => 'Summer',
    9 || 10 || 11 => 'Fall',
    _ => 'Winter',
  };
  // A December race belongs to the winter that ends next year.
  final year = m == 12 ? raceDate.year + 1 : raceDate.year;
  final kind = distance == RaceDistance.marathon
      ? ''
      : '${distance.shortLabel} ';
  return '$season $year ${kind}Tour';
}

// ---------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------

/// Something the runner should know before booking.
class TourCheck {
  const TourCheck(this.title, this.message, {this.serious = false});
  final String title;
  final String message;

  /// Shown in amber with a suggestion to change the setup.
  final bool serious;

  /// Saved on the Tour as one line.
  String get asLine => '$title: $message';
}

/// What the builder hands back to the quiz preview.
class TourBuild {
  const TourBuild({required this.checks, this.tour, this.suggestedDate});

  /// Null when the race is too close to build anything.
  final Tour? tour;
  final List<TourCheck> checks;

  /// Offered when the race is too soon.
  final DateTime? suggestedDate;

  bool get canBook => tour != null;
}

// ---------------------------------------------------------------------------
// Workouts
// ---------------------------------------------------------------------------

enum _Effort { easy, jog, race, tempo, interval }

/// One stretch of a run at one effort.
class _Segment {
  const _Segment(this.miles, this.effort);
  final double miles;
  final _Effort effort;
}

double? _paceOf(_Effort e, TourPaces? p) {
  if (p == null) return null;
  return switch (e) {
    _Effort.easy => p.easy,
    _Effort.jog => p.easySlow,
    _Effort.race => p.race,
    _Effort.tempo => p.tempo,
    _Effort.interval => p.interval,
  };
}

/// Treadmills step in tenths of a mph.
double studioMphFor(double secondsPerMile) =>
    ((mphFromPace(secondsPerMile) ?? 0) * 10).round() / 10;

double _half(double miles) => (miles * 2).round() / 2;

String _mi(double miles) => formatMiles(miles);

class _Workout {
  _Workout(this.type, this.title, this.segments, this.detail);
  final WorkoutType type;
  final String title;
  final List<_Segment> segments;
  final String? detail;

  double get miles => segments.fold(0.0, (s, x) => s + x.miles);
  _Effort get mainEffort {
    var best = segments.first;
    for (final s in segments) {
      if (s.miles > best.miles) best = s;
    }
    return best.effort;
  }
}

_Workout _easy(double miles, {bool recovery = false, String? detail}) =>
    _Workout(
      recovery ? WorkoutType.recovery : WorkoutType.easy,
      recovery ? 'Recovery' : 'Easy',
      [_Segment(miles, _Effort.easy)],
      detail ??
          (recovery
              ? 'Very relaxed. Slower than easy is fine.'
              : 'Conversational effort.'),
    );

_Workout _headliner(double miles, double racePaceMiles) {
  if (racePaceMiles <= 0) {
    return _Workout(WorkoutType.long, 'Headliner', [
      _Segment(miles, _Effort.easy),
    ], 'Steady and easy the whole way. Practice your fueling.');
  }
  return _Workout(WorkoutType.long, 'Headliner', [
    _Segment(miles - racePaceMiles, _Effort.easy),
    _Segment(racePaceMiles, _Effort.race),
  ], 'Easy, then the last ${_mi(racePaceMiles)} at Opening Night pace.');
}

_Workout _tempo(double miles) {
  final warm = miles >= 7 ? 1.5 : 1.0;
  const cool = 1.0;
  final main = math.max(1.0, miles - warm - cool);
  return _Workout(WorkoutType.tempo, 'Tempo', [
    _Segment(warm, _Effort.easy),
    _Segment(main, _Effort.tempo),
    const _Segment(cool, _Effort.easy),
  ], '${_mi(warm)} easy, ${_mi(main)} at tempo, ${_mi(cool)} easy.');
}

_Workout _intervals(double miles) {
  const warm = 1.5;
  const cool = 1.0;
  // Each rep: 800 m hard (0.5 mi) + 400 m jog (0.25 mi).
  final reps = ((miles - warm - cool) / 0.75).floor().clamp(3, 8);
  return _Workout(
    WorkoutType.intervals,
    'Intervals',
    [
      const _Segment(warm, _Effort.easy),
      for (var i = 0; i < reps; i++) ...[
        const _Segment(0.5, _Effort.interval),
        const _Segment(0.25, _Effort.jog),
      ],
      const _Segment(cool, _Effort.easy),
    ],
    '${_mi(warm)} easy, $reps × 800 m at interval pace with 400 m jogs, '
        '${_mi(cool)} easy.',
  );
}

_Workout _race([RaceDistance distance = RaceDistance.marathon]) => _Workout(
  WorkoutType.race,
  'Opening Night',
  [_Segment(raceMilesFor(distance), _Effort.race)],
  switch (distance) {
    RaceDistance.fiveK =>
      'Warm up with a mile easy and a few strides. Settle in for the first '
          'mile, then go. Enjoy the show.',
    RaceDistance.tenK =>
      'Warm up with a mile easy. Hold back for the first 2 miles, then push '
          'the last 2. Enjoy the show.',
    _ =>
      'Start a touch slower than goal pace for the first 3 miles. Enjoy the '
          'show.',
  },
);

/// Treadmill program plus expected time for a workout.
({List<Track> tracks, int? seconds}) _program(
  _Workout w,
  TourPaces? paces,
  Venue venue,
) {
  if (paces == null) return (tracks: const [], seconds: null);
  final tracks = <Track>[];
  var clock = 0;
  for (final s in w.segments) {
    final pace = _paceOf(s.effort, paces)!;
    if (venue == Venue.studio) {
      final mph = studioMphFor(pace);
      // Rounded to 5 seconds so the numbers are easy to read on the machine.
      final secs = (s.miles / mph * 3600 / 5).round() * 5;
      // Back-to-back stretches at the same setting become one Track.
      if (tracks.isNotEmpty && tracks.last.speedMph == mph) {
        final last = tracks.removeLast();
        tracks.add(last.copyWith(endSeconds: last.endSeconds + secs));
      } else {
        tracks.add(
          Track(
            startSeconds: clock,
            endSeconds: clock + secs,
            speedMph: mph,
            inclinePercent: kStudioInclinePercent,
          ),
        );
      }
      clock += secs;
    } else {
      clock += (s.miles * pace).round();
    }
  }
  return (tracks: tracks, seconds: clock);
}

// ---------------------------------------------------------------------------
// The builder
// ---------------------------------------------------------------------------

/// Days after the Headliner that each run lands on, by runs per week.
const Map<int, List<int>> _dayOffsets = {
  1: [0],
  2: [0, 3],
  3: [0, 2, 4],
  4: [0, 2, 4, 5],
  5: [0, 2, 3, 4, 6],
  6: [0, 1, 2, 3, 4, 6],
};

/// Peak weekly miles each goal aims for.
double _goalPeakMiles(DistanceRules r, TourGoal g) => switch (g) {
  TourGoal.finish => r.peakWeekMiles.$1,
  TourGoal.targetTime => r.peakWeekMiles.$2,
  TourGoal.bq => r.peakWeekMiles.$3,
};

/// A week's targets before it's split into runs.
class _WeekTarget {
  _WeekTarget(this.phase, this.miles, this.longMiles, this.rest, this.quality);
  final TourPhase phase;
  final double miles;
  final double longMiles;
  final bool rest;

  /// tempo, intervals or null.
  final WorkoutType? quality;

  /// Miles at Opening Night pace at the end of the Headliner.
  double raceFinish = 0;
}

class TourBuilder {
  TourBuilder({String Function()? newId})
    : _newId = newId ?? (() => const Uuid().v4());

  final String Function() _newId;

  TourBuild build(TourSetup setup, {DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final race = _day(setup.raceDate);
    final checks = <TourCheck>[];
    final distance = setup.raceDistance;
    final rules = rulesFor(distance);
    final raceWord = distance == RaceDistance.marathon
        ? 'a marathon'
        : 'a ${distance.label}';
    final available = weeksUntil(now, race);
    final suggestion = suggestedRaceDate(now, distance);

    if (available < rules.minWeeks) {
      return TourBuild(
        checks: [
          TourCheck(
            'Opening Night is too close',
            'There are only $available full weeks to go, so there is no '
                'room to build up and taper. Pick a race '
                '${rules.idealMinWeeks} to ${rules.maxWeeks} weeks out.',
            serious: true,
          ),
        ],
        suggestedDate: suggestion,
      );
    }

    final weeks = math.min(available, rules.maxWeeks);
    final paces = pacesFor(setup);
    final base = setup.currentWeeklyMiles;

    // ---- Timing and fitness checks ----
    if (available > rules.maxWeeks) {
      final start = _addDays(race, -7 * weeks + 1);
      checks.add(
        TourCheck(
          'The Tour starts later',
          'Rehearsals begin ${_dateText(start)}, ${rules.maxWeeks} weeks before '
              'Opening Night. Keep your usual easy running until then.',
        ),
      );
    }
    if (weeks < rules.shortWeeks) {
      checks.add(
        TourCheck(
          'Race may be too soon',
          'Only $weeks weeks to go from ${formatMiles(base)} a week. Think '
              'about a later race (${_dateText(suggestion)} would give you '
              '${rules.suggestWeeks} weeks) or switch to a finish-only goal.',
          serious: true,
        ),
      );
    } else if (weeks < rules.idealMinWeeks) {
      checks.add(
        TourCheck(
          'Short Tour',
          '$weeks weeks is less than the usual ${rules.idealMinWeeks} to '
              '${rules.maxWeeks}, so mileage climbs on a tighter schedule.',
          serious: base < 20,
        ),
      );
    }
    final (lightBase, lightLong) = switch (distance) {
      RaceDistance.fiveK => (3.0, 1.0),
      RaceDistance.tenK => (6.0, 2.0),
      RaceDistance.half => (8.0, 3.0),
      RaceDistance.marathon => (10.0, 4.0),
    };
    if (base < lightBase || setup.longestRecentRunMiles < lightLong) {
      checks.add(
        TourCheck(
          'Light starting base',
          'Starting from under ${formatMiles(lightBase)} a week (or no run '
              'over ${formatMiles(lightLong)}) makes $raceWord a big jump. '
              'A finish-only goal fits best.',
          serious: weeks < rules.idealMinWeeks || setup.goal != TourGoal.finish,
        ),
      );
    }
    final race0 = setup.recentRace;
    final goalTime = setup.goalTimeSeconds;
    if (race0 != null && goalTime != null && setup.goal != TourGoal.finish) {
      final predicted = predictRaceSeconds(race0, distance);
      if (goalTime < predicted * 0.95) {
        checks.add(
          TourCheck(
            'Ambitious goal',
            'Your recent race predicts ${formatDuration(predicted)}, and your '
                'goal is ${formatDuration(goalTime)}. Paces are set from your '
                'race so training stays safe. Race again mid-Tour to update '
                'them.',
          ),
        );
      }
    }
    if (paces == null) {
      checks.add(
        const TourCheck(
          'Run by feel',
          'With no race or goal time, Shows are planned by distance and '
              'effort, without pace targets.',
        ),
      );
    }

    // ---- Week targets ----
    final targets = _targets(setup, weeks, checks);

    // ---- Weeks and runs ----
    final firstStart = _addDays(race, -7 * weeks + 1);
    final tourWeeks = <TourWeek>[];
    for (var i = 0; i < weeks; i++) {
      final start = _addDays(firstStart, 7 * i);
      final isRaceWeek = i == weeks - 1;
      final t = targets[i];
      final shows = isRaceWeek
          ? _raceWeek(setup, race, paces)
          : _weekShows(setup, start, t, paces);
      tourWeeks.add(
        TourWeek(
          number: i + 1,
          startDate: start,
          phase: t.phase,
          isRestStop: t.rest,
          shows: shows,
        ),
      );
    }

    final created = DateTime.now();
    final tour = Tour(
      id: _newId(),
      name: tourNameFor(race, distance),
      setup: setup,
      paces: paces,
      weeks: tourWeeks,
      warnings: [for (final c in checks) c.asLine],
      createdAt: created,
      updatedAt: created,
    );
    return TourBuild(
      tour: tour,
      checks: checks,
      suggestedDate: weeks < rules.idealMinWeeks ? suggestion : null,
    );
  }

  /// Phases, mileage, Headliners and Rest Stops for every week.
  List<_WeekTarget> _targets(
    TourSetup setup,
    int weeks,
    List<TourCheck> checks,
  ) {
    final rules = rulesFor(setup.raceDistance);
    // The Headliner peaks [peakGap] weeks before race week (3 for a
    // marathon).
    final peakIdx = weeks - 1 - rules.peakGap;
    final taperWeeks = rules.taperWeeks(weeks);
    final buildCount = peakIdx + 1;
    final rehearsalsEnd = math.max(1, (buildCount * 0.3).round());
    final onTheRoadEnd = math.max(
      rehearsalsEnd + 1,
      (buildCount * 0.65).round(),
    );

    final startMiles = math.max(setup.currentWeeklyMiles, 8.0);
    final strongBase = setup.raceDistance == RaceDistance.marathon
        ? 20.0
        : rules.peakLongStrong;
    final peakLongGoal =
        setup.goal == TourGoal.finish || setup.currentWeeklyMiles < strongBase
        ? rules.peakLongFinish
        : rules.peakLongStrong;
    final goalPeak = math.max(
      math.max(_goalPeakMiles(rules, setup.goal), peakLongGoal * 1.8),
      startMiles,
    );
    // Someone used to longer runs keeps the distance's top Headliner rather
    // than shrinking toward it.
    final startLong = setup.longestRecentRunMiles
        .clamp(3.0, math.max(3.0, startMiles * 0.5))
        .clamp(3.0, peakLongGoal)
        .toDouble();

    // Every 4th week is a Rest Stop, except the peak week itself.
    bool isRest(int i) => i > 0 && i < peakIdx && i % 4 == 3;
    final ramp = [
      for (var i = 0; i <= peakIdx; i++)
        if (!isRest(i)) i,
    ];
    final n = ramp.length;

    // Weekly miles grow by the same ratio each non-rest week, never over 10%.
    final ratio = n <= 1
        ? 1.0
        : math.min(1.10, math.pow(goalPeak / startMiles, 1 / (n - 1)));
    // Headliner grows by the same step each non-rest week, never over 2 miles.
    final step = n <= 1
        ? 0.0
        : math.min(2.0, (peakLongGoal - startLong) / (n - 1));

    final peakMiles = startMiles * math.pow(ratio, n - 1);
    final peakLong = startLong + step * (n - 1);
    if (peakLong < peakLongGoal - 0.5) {
      checks.add(
        TourCheck(
          'Shorter Headliners',
          'There is only time to build the Headliner to '
              '${formatMiles(_half(peakLong))} safely, not the usual '
              '${formatMiles(peakLongGoal)}.',
        ),
      );
    }
    if (peakMiles < goalPeak * 0.9) {
      checks.add(
        TourCheck(
          'Lower peak mileage',
          'Keeping increases to 10% a week, mileage tops out near '
              '${formatMiles(peakMiles.roundToDouble())} a week.',
        ),
      );
    }

    final out = <_WeekTarget>[];
    var lastMiles = startMiles;
    var lastLong = startLong;
    var k = 0;
    for (var i = 0; i < weeks; i++) {
      final fromEnd = weeks - 1 - i;
      if (i <= peakIdx) {
        final phase = i < rehearsalsEnd
            ? TourPhase.rehearsals
            : i < onTheRoadEnd
            ? TourPhase.onTheRoad
            : TourPhase.headlineLeg;
        if (isRest(i)) {
          out.add(
            _WeekTarget(
              phase,
              lastMiles * 0.75,
              _half(lastLong * 0.7),
              true,
              null,
            ),
          );
        } else {
          lastMiles = startMiles * math.pow(ratio, k);
          lastLong = startLong + step * k;
          k++;
          final quality = switch (phase) {
            TourPhase.rehearsals => null,
            TourPhase.onTheRoad => WorkoutType.tempo,
            _ => WorkoutType.intervals,
          };
          final t = _WeekTarget(
            phase,
            lastMiles,
            _half(lastLong),
            false,
            quality,
          );
          // Practice race pace at the end of Headline Leg Headliners.
          if (phase == TourPhase.headlineLeg) {
            if (rules.headlinerRaceFinish) {
              t.raceFinish = lastLong >= 16 ? 3 : 2;
            }
          }
          out.add(t);
        }
      } else if (fromEnd < taperWeeks) {
        // Soundcheck: 75%, then 55%, then race week. A 5K or 10K tapers
        // in race week only, at 60%.
        final share = fromEnd == 2
            ? 0.75
            : taperWeeks == 1
            ? 0.6
            : 0.55;
        final longShare = fromEnd == 2 ? 0.65 : 0.45;
        out.add(
          _WeekTarget(
            TourPhase.soundcheck,
            peakMiles * share,
            _half(peakLong * longShare),
            false,
            fromEnd == 0 ? null : WorkoutType.tempo,
          ),
        );
      } else {
        // The step-down week between the peak and a 2-week Soundcheck.
        out.add(
          _WeekTarget(
            TourPhase.headlineLeg,
            peakMiles * 0.85,
            _half(peakLong * 0.7),
            false,
            WorkoutType.intervals,
          ),
        );
      }
    }
    return out;
  }

  Venue _venueFor(TourSetup setup, WorkoutType type) {
    switch (setup.venuePreference) {
      case VenuePreference.live:
        return Venue.live;
      case VenuePreference.studio:
        return Venue.studio;
      case VenuePreference.mix:
        return type == WorkoutType.tempo || type == WorkoutType.intervals
            ? Venue.studio
            : Venue.live;
    }
  }

  PlannedShow _planned(
    TourSetup setup,
    DateTime date,
    _Workout w,
    TourPaces? paces, {
    Venue? venue,
  }) {
    final v = venue ?? _venueFor(setup, w.type);
    final program = _program(w, paces, v);
    return PlannedShow(
      id: _newId(),
      date: date,
      workoutType: w.type,
      distanceMiles: w.miles,
      venue: v,
      title: w.title,
      detail: w.detail,
      targetPaceSecondsPerMile: _paceOf(w.mainEffort, paces),
      plannedDurationSeconds: program.seconds,
      tracks: program.tracks,
    );
  }

  List<PlannedShow> _weekShows(
    TourSetup setup,
    DateTime start,
    _WeekTarget t,
    TourPaces? paces,
  ) {
    final long = math.max(3.0, t.longMiles);
    final wantsQuality = t.quality != null && setup.daysPerWeek >= 3;
    var qualityMiles = 0.0;
    if (wantsQuality) {
      final share = t.quality == WorkoutType.tempo ? 0.18 : 0.16;
      final cap = t.quality == WorkoutType.tempo ? 9.0 : 8.0;
      qualityMiles = _half((t.miles * share).clamp(4.0, cap).toDouble());
    }
    final quality = !wantsQuality
        ? null
        : t.quality == WorkoutType.tempo
        ? _tempo(qualityMiles)
        : _intervals(qualityMiles);

    // Easy runs share what's left, at least 3 miles each. Light weeks get
    // fewer runs rather than lots of tiny ones.
    final left = t.miles - long - (quality?.miles ?? 0);
    final maxEasy = setup.daysPerWeek - 1 - (quality == null ? 0 : 1);
    final easyCount = math.max(1, math.min(maxEasy, (left / 3).floor()));
    final runs = 1 + (quality == null ? 0 : 1) + easyCount;
    final offsets = _dayOffsets[runs]!;

    // With six runs, the day after the Headliner is a short recovery run.
    final hasRecovery = runs == 6 && left >= 3 * easyCount;
    final easyEach = hasRecovery
        ? math.max(3.0, _half((left - 3) / (easyCount - 1)))
        : math.max(3.0, _half(left / easyCount));

    final headlinerIdx = (setup.headlinerWeekday - start.weekday) % 7;
    DateTime dayAt(int offset) => _addDays(start, (headlinerIdx + offset) % 7);

    final workouts = <(int, _Workout)>[
      (0, _headliner(long, paces == null ? 0 : t.raceFinish)),
    ];
    final qualityOffset = runs == 2 ? 3 : 2;
    var easyLeft = easyCount;
    for (final off in offsets.skip(1)) {
      if (quality != null && off == qualityOffset) {
        workouts.add((off, quality));
      } else if (hasRecovery && off == 1) {
        workouts.add((off, _easy(3, recovery: true)));
        easyLeft--;
      } else if (easyLeft > 0) {
        workouts.add((off, _easy(easyEach)));
        easyLeft--;
      }
    }
    final shows = [
      for (final (off, w) in workouts) _planned(setup, dayAt(off), w, paces),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return shows;
  }

  List<PlannedShow> _raceWeek(
    TourSetup setup,
    DateTime race,
    TourPaces? paces,
  ) {
    final short =
        setup.raceDistance == RaceDistance.fiveK ||
        setup.raceDistance == RaceDistance.tenK;
    final shakeouts = setup.daysPerWeek >= 4
        ? [(6, short ? 3.0 : 4.0), (4, 3.0), (2, 2.0)]
        : [(4, 3.0), (2, 2.0)];
    return [
      for (final (before, miles) in shakeouts)
        _planned(
          setup,
          _addDays(race, -before),
          _easy(
            miles,
            detail: before == 2
                ? 'Short shakeout with 4 strides. Lay out your race kit.'
                : 'Easy, with a few minutes at Opening Night pace.',
          ),
          paces,
        ),
      _planned(
        setup,
        race,
        _race(setup.raceDistance),
        paces,
        venue: Venue.live,
      ),
    ];
  }
}

String _dateText(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ---------------------------------------------------------------------------
// Replanning (used by the Tour Manager)
// ---------------------------------------------------------------------------

/// Rebuilds [p] as a [type] run of [miles], with fresh detail, target pace,
/// expected time and Track list. Headliners come back as all-easy (no
/// Opening Night pace finish), which is what a Rest Stop week wants.
PlannedShow replanShow(
  PlannedShow p, {
  required WorkoutType type,
  required double miles,
  TourPaces? paces,
}) {
  final w = switch (type) {
    WorkoutType.long => _headliner(miles, 0),
    WorkoutType.tempo => _tempo(miles),
    WorkoutType.intervals => _intervals(miles),
    WorkoutType.recovery => _easy(miles, recovery: true),
    WorkoutType.race => _race(_distanceNear(p.distanceMiles)),
    WorkoutType.easy => _easy(miles),
  };
  final program = _program(w, paces, p.venue);
  return PlannedShow(
    id: p.id,
    date: p.date,
    workoutType: w.type,
    distanceMiles: w.miles,
    venue: p.venue,
    title: w.title,
    detail: w.detail,
    targetPaceSecondsPerMile: _paceOf(w.mainEffort, paces),
    plannedDurationSeconds: program.seconds,
    tracks: program.tracks,
    rescheduledFrom: p.rescheduledFrom,
    skipped: p.skipped,
  );
}

/// The race distance closest to [miles] (a planned Opening Night keeps its
/// race's miles).
RaceDistance _distanceNear(double miles) => RaceDistance.values.reduce(
  (a, b) => (a.miles - miles).abs() <= (b.miles - miles).abs() ? a : b,
);

/// Every pace [secondsFaster] seconds per mile quicker.
TourPaces fasterPaces(TourPaces p, double secondsFaster) => TourPaces(
  predictedMarathonSeconds:
      (p.predictedMarathonSeconds - secondsFaster * kMarathonMiles).round(),
  marathon: p.marathon - secondsFaster,
  easySlow: p.easySlow - secondsFaster,
  easyFast: p.easyFast - secondsFaster,
  tempo: p.tempo - secondsFaster,
  interval: p.interval - secondsFaster,
  source: p.source,
  race: p.race - secondsFaster,
  raceMiles: p.raceMiles,
);

/// [p] with every stretch [secondsFaster] sec/mi quicker. Distances stay the
/// same; treadmill speeds are re-rounded to the tenth of a mph and Track
/// times to 5 seconds, just like a freshly built plan.
PlannedShow speedUpShow(PlannedShow p, double secondsFaster) {
  final pace = p.targetPaceSecondsPerMile;
  if (pace == null) return p;
  if (p.tracks.isEmpty) {
    final secs = p.plannedDurationSeconds;
    return p.copyWith(
      targetPaceSecondsPerMile: pace - secondsFaster,
      plannedDurationSeconds: secs == null
          ? null
          : (secs - secondsFaster * p.distanceMiles).round(),
    );
  }
  final tracks = <Track>[];
  var clock = 0;
  for (final t in p.tracks) {
    final miles = t.distanceMiles;
    final oldPace = paceFromMph(t.speedMph);
    if (oldPace == null || miles <= 0) {
      final len = t.endSeconds - t.startSeconds;
      tracks.add(t.copyWith(startSeconds: clock, endSeconds: clock + len));
      clock += len;
      continue;
    }
    final mph = studioMphFor(oldPace - secondsFaster);
    final secs = (miles / mph * 3600 / 5).round() * 5;
    tracks.add(
      Track(
        startSeconds: clock,
        endSeconds: clock + secs,
        speedMph: mph,
        inclinePercent: t.inclinePercent,
      ),
    );
    clock += secs;
  }
  return p.copyWith(
    targetPaceSecondsPerMile: pace - secondsFaster,
    plannedDurationSeconds: clock,
    tracks: tracks,
  );
}
