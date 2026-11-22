/// Gold Records: personal records worked out from the logged Shows.
///
/// Nothing here is saved. Records are recomputed whenever the Setlist changes,
/// so editing or deleting a Show can never leave a stale record behind, and
/// the future sync backend has nothing extra to store.
library;

import '../models/enums.dart';
import '../models/show.dart';
import 'show_math.dart';

/// Which Shows the records are drawn from.
enum RecordScope {
  all('All Shows'),
  live('Live Shows'),
  studio('Studio Sessions');

  const RecordScope(this.label);
  final String label;

  bool includes(Show s) => switch (this) {
    RecordScope.all => true,
    RecordScope.live => s.venue == Venue.live,
    RecordScope.studio => s.venue == Venue.studio,
  };
}

/// How a record is grouped on the Gold Records screen.
enum RecordGroup {
  distance('Distance'),
  speed('Speed'),
  climbs('Climbs');

  const RecordGroup(this.label);
  final String label;
}

/// Race distances in miles.
const kMiles5k = 3.10686;
const kMiles10k = 6.21371;
const kMilesHalf = 13.1094;
const kMilesFull = 26.2188;

/// Shows logged a hair short of a race distance (3.1 for a 5K) still count.
const _distanceSlack = 0.02;

enum RecordKind {
  longestShow(RecordGroup.distance, 'Longest Show', 'Log any Show.'),
  longestHeadliner(
    RecordGroup.distance,
    'Longest Headliner',
    'Log a Show as a Headliner (long run).',
  ),
  biggestWeek(RecordGroup.distance, 'Biggest week', 'Log any Show.'),
  biggestMonth(RecordGroup.distance, 'Biggest month', 'Log any Show.'),
  fastestPace(
    RecordGroup.speed,
    'Fastest average pace',
    'Log a Show of 1 mile or more.',
  ),
  fastest5k(RecordGroup.speed, 'Fastest 5K', 'Log a Show of 3.1 mi or more.'),
  fastest10k(RecordGroup.speed, 'Fastest 10K', 'Log a Show of 6.2 mi or more.'),
  fastestHalf(
    RecordGroup.speed,
    'Fastest half marathon',
    'Log a Show of 13.1 mi or more.',
  ),
  fastestFull(
    RecordGroup.speed,
    'Fastest marathon',
    'Your Opening Night time lands here.',
  ),
  mostClimbing(
    RecordGroup.climbs,
    'Most climbing',
    'Add elevation gain to a Live Show.',
  ),
  steepestStudio(
    RecordGroup.climbs,
    'Steepest Studio Session',
    'Log a Studio Session with Tracks.',
  );

  const RecordKind(this.group, this.title, this.howToSet);
  final RecordGroup group;
  final String title;

  /// Shown on an empty slot: what it takes to set this record.
  final String howToSet;

  /// Records that can't exist for a scope are left off its screen.
  bool appliesTo(RecordScope scope) => switch (this) {
    RecordKind.mostClimbing => scope != RecordScope.studio,
    RecordKind.steepestStudio => scope != RecordScope.live,
    _ => true,
  };

  /// Race-distance records are worked out from a Show's average pace.
  double? get raceMiles => switch (this) {
    RecordKind.fastest5k => kMiles5k,
    RecordKind.fastest10k => kMiles10k,
    RecordKind.fastestHalf => kMilesHalf,
    RecordKind.fastestFull => kMilesFull,
    _ => null,
  };
}

/// One record that has been set.
class GoldRecord {
  const GoldRecord({
    required this.kind,
    required this.value,
    required this.date,
    this.show,
    this.detail,
    this.periodShowCount,
  });

  final RecordKind kind;

  /// The headline number, e.g. "22:41" or "42.5 mi".
  final String value;

  /// When it was set: the Show's date, or the first day of the week / month.
  final DateTime date;

  /// The Show that set it. Null for week and month records.
  final Show? show;

  /// A second line, e.g. "7:18 /mi on a 6.2 mi Show".
  final String? detail;

  /// For week and month records: how many Shows made up the total.
  final int? periodShowCount;
}

/// Works out every record for [scope]. Kinds with no qualifying Show are
/// missing from the map (they show as empty slots).
Map<RecordKind, GoldRecord> computeGoldRecords(
  List<Show> allShows, {
  RecordScope scope = RecordScope.all,
}) {
  final shows = allShows.where((s) => !s.isDeleted && scope.includes(s));
  final records = <RecordKind, GoldRecord>{};

  // Ties go to the earliest Show: the first one to reach a mark set it.
  final ordered = shows.toList()..sort((a, b) => a.date.compareTo(b.date));

  Show? best(Iterable<Show> pool, double Function(Show) score) {
    Show? top;
    double? topScore;
    for (final s in pool) {
      final v = score(s);
      if (topScore == null || v > topScore) {
        top = s;
        topScore = v;
      }
    }
    return top;
  }

  final withDistance = ordered.where((s) => s.distanceMiles > 0).toList();

  final longest = best(withDistance, (s) => s.distanceMiles);
  if (longest != null) {
    records[RecordKind.longestShow] = GoldRecord(
      kind: RecordKind.longestShow,
      value: formatMiles(longest.distanceMiles),
      date: longest.date,
      show: longest,
      detail: _paceAndTime(longest),
    );
  }

  final headliner = best(
    withDistance.where((s) => s.workoutType == WorkoutType.long),
    (s) => s.distanceMiles,
  );
  if (headliner != null) {
    records[RecordKind.longestHeadliner] = GoldRecord(
      kind: RecordKind.longestHeadliner,
      value: formatMiles(headliner.distanceMiles),
      date: headliner.date,
      show: headliner,
      detail: _paceAndTime(headliner),
    );
  }

  // Pace records. Faster pace = fewer seconds, so score by the negative.
  final timed = withDistance.where((s) => s.durationSeconds > 0).toList();
  final fastest = best(
    timed.where((s) => s.distanceMiles >= 1 - _distanceSlack),
    (s) => -s.paceSecondsPerMile!,
  );
  if (fastest != null) {
    records[RecordKind.fastestPace] = GoldRecord(
      kind: RecordKind.fastestPace,
      value: formatPace(fastest.paceSecondsPerMile),
      date: fastest.date,
      show: fastest,
      detail: 'over ${formatMiles(fastest.distanceMiles)}',
    );
  }

  for (final kind in RecordKind.values) {
    final miles = kind.raceMiles;
    if (miles == null) continue;
    final pick = best(
      timed.where((s) => s.distanceMiles >= miles - _distanceSlack),
      (s) => -s.paceSecondsPerMile!,
    );
    if (pick == null) continue;
    final pace = pick.paceSecondsPerMile!;
    records[kind] = GoldRecord(
      kind: kind,
      value: formatDuration((pace * miles).round()),
      date: pick.date,
      show: pick,
      detail:
          '${formatPace(pace)} average, '
          '${formatMiles(pick.distanceMiles)} Show',
    );
  }

  // Biggest week (Monday to Sunday) and month, by miles.
  GoldRecord? biggestPeriod(RecordKind kind, DateTime Function(Show) key) {
    final miles = <DateTime, double>{};
    final counts = <DateTime, int>{};
    for (final s in withDistance) {
      final k = key(s);
      miles[k] = (miles[k] ?? 0) + s.distanceMiles;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    DateTime? top;
    for (final k in miles.keys) {
      // Keys come in date order, so ">" keeps the earliest on a tie.
      if (top == null || miles[k]! > miles[top]! + 1e-9) top = k;
    }
    if (top == null) return null;
    final n = counts[top]!;
    return GoldRecord(
      kind: kind,
      value: formatMiles(miles[top]!),
      date: top,
      periodShowCount: n,
      detail: n == 1 ? '1 Show' : '$n Shows',
    );
  }

  final week = biggestPeriod(RecordKind.biggestWeek, (s) => weekStart(s.date));
  if (week != null) records[RecordKind.biggestWeek] = week;
  final month = biggestPeriod(
    RecordKind.biggestMonth,
    (s) => DateTime(s.date.year, s.date.month),
  );
  if (month != null) records[RecordKind.biggestMonth] = month;

  if (RecordKind.mostClimbing.appliesTo(scope)) {
    final climb = best(
      ordered.where((s) => (s.live?.elevationGainFt ?? 0) > 0),
      (s) => s.live!.elevationGainFt!,
    );
    if (climb != null) {
      records[RecordKind.mostClimbing] = GoldRecord(
        kind: RecordKind.mostClimbing,
        value: '${_thousands(climb.live!.elevationGainFt!.round())} ft',
        date: climb.date,
        show: climb,
        detail: [
          climb.live?.routeName,
          formatMiles(climb.distanceMiles),
        ].whereType<String>().where((t) => t.isNotEmpty).join(' · '),
      );
    }
  }

  if (RecordKind.steepestStudio.appliesTo(scope)) {
    final steep = best(
      ordered.where(
        (s) =>
            s.studio != null &&
            s.studio!.tracks.isNotEmpty &&
            s.studio!.totals.averageInclinePercent > 0,
      ),
      (s) => s.studio!.totals.averageInclinePercent,
    );
    if (steep != null) {
      final incline = steep.studio!.totals.averageInclinePercent;
      records[RecordKind.steepestStudio] = GoldRecord(
        kind: RecordKind.steepestStudio,
        value: '${incline.toStringAsFixed(1)}%',
        date: steep.date,
        show: steep,
        detail: 'average incline over ${formatMiles(steep.distanceMiles)}',
      );
    }
  }

  return records;
}

String? _paceAndTime(Show s) {
  if (s.durationSeconds <= 0) return null;
  return '${formatDuration(s.durationSeconds)} · '
      '${formatPace(s.paceSecondsPerMile)}';
}

String _thousands(int n) {
  final digits = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
