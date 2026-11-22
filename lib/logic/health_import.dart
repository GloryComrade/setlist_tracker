/// Turning Apple Health runs into Shows. Pure functions, no plugin calls.
library;

import 'package:uuid/uuid.dart';

import '../data/health/health_source.dart';
import '../models/enums.dart';
import '../models/show.dart';
import '../models/venue_details.dart';

/// How far back the first import looks.
const healthFirstImportDays = 30;

/// Where the next import starts looking.
///
/// The first time, [healthFirstImportDays] back. After that, a day before the
/// last import, so a run still syncing from the Watch at that moment isn't
/// missed. Runs already on the Setlist are filtered out by [newHealthRuns].
DateTime healthImportStart(DateTime? lastImport, DateTime now) =>
    lastImport == null
    ? now.subtract(const Duration(days: healthFirstImportDays))
    : lastImport.subtract(const Duration(days: 1));

/// A run worth offering: it has a distance and a time.
bool isImportable(HealthRun run) =>
    run.distanceMiles >= 0.01 && run.durationSeconds > 0;

/// True when [show] is probably the same run, logged by hand: same day and
/// a distance within 5% (or 0.05 mi, for short runs).
bool looksLikeSameRun(HealthRun run, Show show) {
  final a = run.start;
  final b = show.date;
  if (a.year != b.year || a.month != b.month || a.day != b.day) return false;
  final larger = run.distanceMiles > show.distanceMiles
      ? run.distanceMiles
      : show.distanceMiles;
  var tolerance = larger * 0.05;
  if (tolerance < 0.05) tolerance = 0.05;
  return (run.distanceMiles - show.distanceMiles).abs() <= tolerance;
}

/// The runs that aren't on the Setlist yet, newest first.
///
/// Skips runs already imported (their uuid is on a Show), runs that look like
/// a Show logged by hand, runs with no distance, and repeats in [runs].
List<HealthRun> newHealthRuns(List<HealthRun> runs, List<Show> shows) {
  final imported = {
    for (final s in shows)
      if (s.healthWorkoutId != null) s.healthWorkoutId!,
  };
  final handLogged = shows.where((s) => s.healthWorkoutId == null).toList();
  final seen = <String>{};
  final fresh = [
    for (final r in runs)
      if (isImportable(r) &&
          !imported.contains(r.uuid) &&
          seen.add(r.uuid) &&
          !handLogged.any((s) => looksLikeSameRun(r, s)))
        r,
  ];
  fresh.sort((a, b) => b.start.compareTo(a.start));
  return fresh;
}

/// Studio Session when Health says the run was indoors, else a Live Show.
Venue venueForHealthRun(HealthRun run) =>
    run.indoor == true ? Venue.studio : Venue.live;

/// A new Show for [run]. Workout type Easy, effort 5 and Feel "Fine" are
/// placeholders the runner can change; distance, time and (for Live Shows)
/// elevation and temperature come from Health.
Show showFromHealthRun(HealthRun run, {required DateTime now, String? id}) {
  final venue = venueForHealthRun(run);
  final temp = run.tempF;
  return Show(
    id: id ?? const Uuid().v4(),
    date: run.start,
    venue: venue,
    workoutType: WorkoutType.easy,
    distanceMiles: double.parse(run.distanceMiles.toStringAsFixed(2)),
    durationSeconds: run.durationSeconds,
    effort: 5,
    feel: Feel.fine,
    studio: venue == Venue.studio ? const StudioDetails() : null,
    live: venue == Venue.live
        ? LiveDetails(
            elevationGainFt: run.elevationGainFt?.roundToDouble(),
            weather: temp == null ? null : Weather(tempF: temp.roundToDouble()),
          )
        : null,
    healthWorkoutId: run.uuid,
    createdAt: now,
    updatedAt: now,
  );
}
