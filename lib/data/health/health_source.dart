/// Apple Health: reading runs and heart rate, and saving Shows as workouts.
///
/// The screens only see [HealthSource] and plain values, so the app (and its
/// tests) never touch HealthKit directly. Heart rate is read when a Show is
/// opened and never stored or synced.
library;

import '../../models/gps_track.dart';

import 'health_source_stub.dart'
    if (dart.library.io) 'health_source_apple.dart'
    as platform;

/// One running workout from Apple Health, in the app's units.
class HealthRun {
  const HealthRun({
    required this.uuid,
    required this.start,
    required this.end,
    required this.distanceMiles,
    required this.durationSeconds,
    this.indoor,
    this.elevationGainFt,
    this.tempF,
    this.sourceName,
    this.route = const [],
  });

  /// HealthKit's id for the workout. Saved on the Show to stop repeats.
  final String uuid;

  /// Local time.
  final DateTime start;
  final DateTime end;
  final double distanceMiles;

  /// Time moving, without pauses when Health knows them.
  final int durationSeconds;

  /// HealthKit's indoor flag (treadmill). Null when the workout doesn't say.
  final bool? indoor;
  final double? elevationGainFt;
  final double? tempF;

  /// The app or device that recorded it, e.g. "Apple Watch".
  final String? sourceName;

  /// The GPS route Health keeps with an outdoor run, oldest fix first.
  /// Empty for treadmill runs and workouts recorded without GPS.
  final List<GpsPoint> route;

  HealthRun withRoute(List<GpsPoint> fixes) => HealthRun(
    uuid: uuid,
    start: start,
    end: end,
    distanceMiles: distanceMiles,
    durationSeconds: durationSeconds,
    indoor: indoor,
    elevationGainFt: elevationGainFt,
    tempF: tempF,
    sourceName: sourceName,
    route: fixes,
  );
}

/// The route that belongs to a run from [start] to [end]: the one whose time
/// overlaps the run most, if it covers at least half of the shorter of the
/// two. Null when none does.
List<GpsPoint>? matchRoute(
  DateTime start,
  DateTime end,
  Iterable<({DateTime start, DateTime end, List<GpsPoint> fixes})> routes,
) {
  List<GpsPoint>? best;
  var bestOverlap = Duration.zero;
  for (final r in routes) {
    final from = r.start.isAfter(start) ? r.start : start;
    final to = r.end.isBefore(end) ? r.end : end;
    final overlap = to.difference(from);
    if (overlap <= Duration.zero) continue;
    final runLen = end.difference(start);
    final routeLen = r.end.difference(r.start);
    final shorter = runLen < routeLen ? runLen : routeLen;
    if (overlap * 2 < shorter) continue;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = r.fixes;
    }
  }
  return best;
}

/// A Show to save to Health as a running workout.
class HealthRunToSave {
  const HealthRunToSave({
    required this.start,
    required this.end,
    required this.distanceMiles,
    required this.indoor,
    this.route = const [],
  });

  final DateTime start;
  final DateTime end;
  final double distanceMiles;

  /// Studio Sessions are saved as indoor (treadmill) runs.
  final bool indoor;

  /// The GPS route of a recorded Live Show, oldest fix first.
  final List<GpsPoint> route;
}

/// Heart rate during a Show, in beats per minute.
class HeartRateSummary {
  const HeartRateSummary({
    required this.average,
    required this.max,
    required this.samples,
  });
  final int average;
  final int max;
  final int samples;
}

/// Health refused the read, or access was turned off in Settings.
class HealthAccessDenied implements Exception {
  const HealthAccessDenied();
}

abstract class HealthSource {
  /// False on web and anywhere but iPhone. The import is hidden then.
  bool get available;

  /// Shows Apple's permission sheet the first time (workouts and heart rate
  /// to read, workouts and routes to save). Returns false if the request
  /// couldn't be made. iOS never says whether reading was allowed: a refusal
  /// just looks like no workouts.
  Future<bool> requestAccess();

  /// Running workouts that started between [from] and [to], each with its
  /// GPS route when Health has one.
  /// Throws [HealthAccessDenied] when Health refuses the read.
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to);

  /// Saves [run] as a running workout (with its route, if any). Returns
  /// Health's id for it, or null if it wasn't saved.
  Future<String?> saveRun(HealthRunToSave run);

  /// Average and max heart rate between [from] and [to], or null when
  /// Health has none (no Apple Watch on, or access refused).
  Future<HeartRateSummary?> heartRate(DateTime from, DateTime to);
}

/// Average and max of [bpm] readings, or null when there are none.
HeartRateSummary? summarizeHeartRate(Iterable<num> bpm) {
  final values = [
    for (final v in bpm)
      if (v > 20 && v < 250) v,
  ];
  if (values.isEmpty) return null;
  final sum = values.fold<num>(0, (a, b) => a + b);
  final max = values.reduce((a, b) => a > b ? a : b);
  return HeartRateSummary(
    average: (sum / values.length).round(),
    max: max.round(),
    samples: values.length,
  );
}

/// Web, tests and any device without Apple Health.
class UnavailableHealthSource implements HealthSource {
  const UnavailableHealthSource();

  @override
  bool get available => false;

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to) async =>
      const [];

  @override
  Future<String?> saveRun(HealthRunToSave run) async => null;

  @override
  Future<HeartRateSummary?> heartRate(DateTime from, DateTime to) async => null;
}

/// Apple Health on iPhone, otherwise [UnavailableHealthSource].
HealthSource createHealthSource() => platform.createHealthSource();
