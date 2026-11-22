/// Builds The Tour from the setup quiz. Rules only, no AI, no Flutter imports,
/// so every rule here is covered by unit tests (test/tour_builder_test.dart).
library;

import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/tour.dart';
import '../models/track.dart';
import 'show_math.dart';

const double kMarathonMiles = 26.2;
const double k5kMiles = 3.10686;

/// Shortest Tour the builder will make at all.
const int kMinTourWeeks = 6;

/// Under this, the builder warns that the race is too soon.
const int kShortTourWeeks = 12;

/// The usual range for a marathon plan.
const int kIdealMinTourWeeks = 16;
const int kMaxTourWeeks = 20;

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

/// Training paces from a marathon time.
///
/// - Easy runs and Headliners: 60 to 90 seconds per mile slower than
///   marathon pace.
/// - Tempo: the pace Riegel predicts for 10 miles, roughly threshold effort.
/// - Intervals: the pace Riegel predicts for 5K.
TourPaces pacesFromMarathon(int marathonSeconds, String source) {
  final t = marathonSeconds.toDouble();
  final mp = t / kMarathonMiles;
  return TourPaces(
    predictedMarathonSeconds: marathonSeconds,
    marathon: mp,
    easySlow: mp + 90,
    easyFast: mp + 60,
    tempo: riegelSeconds(t, kMarathonMiles, 10) / 10,
    interval: riegelSeconds(t, kMarathonMiles, k5kMiles) / k5kMiles,
    source: source,
  );
}

/// Picks the best source for paces: a recent race first, then the goal time,
/// then the runner's usual easy pace. Null means an effort-only Tour.
TourPaces? pacesFor(TourSetup setup) {
  final race = setup.recentRace;
  if (race != null) {
    return pacesFromMarathon(predictMarathonSeconds(race), 'recentRace');
  }
  final goal = setup.goalTimeSeconds;
  if (setup.goal != TourGoal.finish && goal != null && goal > 0) {
    return pacesFromMarathon(goal, 'goalTime');
  }
  final easy = setup.easyPaceSecondsPerMile;
  if (easy != null && easy > 0) {
    // Easy pace is about 75 s/mi slower than marathon pace.
    final mp = math.max(easy - 75, 240.0);
    return pacesFromMarathon((mp * kMarathonMiles).round(), 'easyPace');
  }
  return null;
}

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

/// The "help me pick" date: the first Sunday at least 18 weeks out.
DateTime suggestedRaceDate(DateTime today) {
  final d = _addDays(_day(today), 18 * 7);
  return _addDays(d, (DateTime.sunday - d.weekday) % 7);
}

/// "Spring 2027 Tour" from the race date.
String tourNameFor(DateTime raceDate) {
  final m = raceDate.month;
  final season = switch (m) {
    3 || 4 || 5 => 'Spring',
    6 || 7 || 8 => 'Summer',
    9 || 10 || 11 => 'Fall',
    _ => 'Winter',
  };
  // A December race belongs to the winter that ends next year.
  final year = m == 12 ? raceDate.year + 1 : raceDate.year;
  return '$season $year Tour';
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

enum _Effort { easy, jog, marathon, tempo, interval }

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
    _Effort.marathon => p.marathon,
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

_Workout _headliner(double miles, double marathonPaceMiles) {
  if (marathonPaceMiles <= 0) {
    return _Workout(WorkoutType.long, 'Headliner', [
      _Segment(miles, _Effort.easy),
    ], 'Steady and easy the whole way. Practice your fueling.');
  }
  return _Workout(WorkoutType.long, 'Headliner', [
    _Segment(miles - marathonPaceMiles, _Effort.easy),
    _Segment(marathonPaceMiles, _Effort.marathon),
  ], 'Easy, then the last ${_mi(marathonPaceMiles)} at Opening Night pace.');
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

_Workout _race() => _Workout(
  WorkoutType.race,
  'Opening Night',
  const [_Segment(kMarathonMiles, _Effort.marathon)],
  'Start a touch slower than goal pace for the first 3 miles. Enjoy the show.',
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
double _goalPeakMiles(TourGoal g) => switch (g) {
  TourGoal.finish => 36,
  TourGoal.targetTime => 42,
  TourGoal.bq => 50,
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

  /// Miles at marathon pace at the end of the Headliner.
  double marathonFinish = 0;
}

class TourBuilder {
  TourBuilder({String Function()? newId})
    : _newId = newId ?? (() => const Uuid().v4());

  final String Function() _newId;

  TourBuild build(TourSetup setup, {DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final race = _day(setup.raceDate);
    final checks = <TourCheck>[];
    final available = weeksUntil(now, race);
    final suggestion = suggestedRaceDate(now);

    if (available < kMinTourWeeks) {
      return TourBuild(
        checks: [
          TourCheck(
            'Opening Night is too close',
            'There are only $available full weeks to go, so there is no '
                'room to build up and taper. Pick a race $kIdealMinTourWeeks '
                'to $kMaxTourWeeks weeks out.',
            serious: true,
          ),
        ],
        suggestedDate: suggestion,
      );
    }

    final weeks = math.min(available, kMaxTourWeeks);
    final paces = pacesFor(setup);
    final base = setup.currentWeeklyMiles;

    // ---- Timing and fitness checks ----
    if (available > kMaxTourWeeks) {
      final start = _addDays(race, -7 * weeks + 1);
      checks.add(
        TourCheck(
          'The Tour starts later',
          'Rehearsals begin ${_dateText(start)}, $kMaxTourWeeks weeks before '
              'Opening Night. Keep your usual easy running until then.',
        ),
      );
    }
    if (weeks < kShortTourWeeks) {
      checks.add(
        TourCheck(
          'Race may be too soon',
          'Only $weeks weeks to go from ${formatMiles(base)} a week. Think '
              'about a later race (${_dateText(suggestion)} would give you 18 '
              'weeks) or switch to a finish-only goal.',
          serious: true,
        ),
      );
    } else if (weeks < kIdealMinTourWeeks) {
      checks.add(
        TourCheck(
          'Short Tour',
          '$weeks weeks is less than the usual $kIdealMinTourWeeks to '
              '$kMaxTourWeeks, so mileage climbs on a tighter schedule.',
          serious: base < 20,
        ),
      );
    }
    if (base < 10 || setup.longestRecentRunMiles < 4) {
      checks.add(
        TourCheck(
          'Light starting base',
          'Starting from under 10 miles a week (or no run over 4 miles) '
              'makes a marathon a big jump. A finish-only goal fits best.',
          serious: weeks < kIdealMinTourWeeks || setup.goal != TourGoal.finish,
        ),
      );
    }
    final race0 = setup.recentRace;
    final goalTime = setup.goalTimeSeconds;
    if (race0 != null && goalTime != null && setup.goal != TourGoal.finish) {
      final predicted = predictMarathonSeconds(race0);
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
      name: tourNameFor(race),
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
      suggestedDate: weeks < kIdealMinTourWeeks ? suggestion : null,
    );
  }

  /// Phases, mileage, Headliners and Rest Stops for every week.
  List<_WeekTarget> _targets(
    TourSetup setup,
    int weeks,
    List<TourCheck> checks,
  ) {
    // The Headliner peaks 3 weeks before race week.
    final peakIdx = weeks - 4;
    final taperWeeks = weeks >= 18 ? 3 : 2;
    final buildCount = peakIdx + 1;
    final rehearsalsEnd = math.max(1, (buildCount * 0.3).round());
    final onTheRoadEnd = math.max(
      rehearsalsEnd + 1,
      (buildCount * 0.65).round(),
    );

    final startMiles = math.max(setup.currentWeeklyMiles, 8.0);
    final peakLongGoal =
        setup.goal == TourGoal.finish || setup.currentWeeklyMiles < 20
        ? 18.0
        : 20.0;
    final goalPeak = math.max(
      math.max(_goalPeakMiles(setup.goal), peakLongGoal * 1.8),
      startMiles,
    );
    final startLong = setup.longestRecentRunMiles
        .clamp(3.0, math.max(3.0, startMiles * 0.5))
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
            t.marathonFinish = lastLong >= 16 ? 3 : 2;
          }
          out.add(t);
        }
      } else if (fromEnd < taperWeeks) {
        // Soundcheck: 75%, then 55%, then race week.
        final share = fromEnd == 2 ? 0.75 : 0.55;
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
      (0, _headliner(long, paces == null ? 0 : t.marathonFinish)),
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
    final shakeouts = setup.daysPerWeek >= 4
        ? [(6, 4.0), (4, 3.0), (2, 2.0)]
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
      _planned(setup, race, _race(), paces, venue: Venue.live),
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
    WorkoutType.race => _race(),
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
