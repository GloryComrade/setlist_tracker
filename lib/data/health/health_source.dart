/// Reading runs from Apple Health.
///
/// The screens only see [HealthSource] and plain [HealthRun]s, so the app (and
/// its tests) never touch HealthKit directly. Read only: nothing is ever
/// written back to Health.
library;

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
}

/// Health refused the read, or access was turned off in Settings.
class HealthAccessDenied implements Exception {
  const HealthAccessDenied();
}

abstract class HealthSource {
  /// False on web and anywhere but iPhone. The import is hidden then.
  bool get available;

  /// Shows Apple's permission sheet the first time. Returns false if the
  /// request couldn't be made. iOS never says whether reading was allowed: a
  /// refusal just looks like no workouts.
  Future<bool> requestAccess();

  /// Running workouts that started between [from] and [to].
  /// Throws [HealthAccessDenied] when Health refuses the read.
  Future<List<HealthRun>> fetchRuns(DateTime from, DateTime to);
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
}

/// Apple Health on iPhone, otherwise [UnavailableHealthSource].
HealthSource createHealthSource() => platform.createHealthSource();
